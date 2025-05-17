local Settings = {}
local Shared = script.Parent

local Trove = require(Shared.Trove)
local Signal = require(Shared.Signal)
local Promise = require(Shared.Promise)
local Network = require(Shared.Network)
local RunContext = require(Shared.RunContext)
local PlayerData = require(Shared.PlayerData)

local Frontend = require(script.Frontend)
local Backend = require(script.Backend)
local Types = require(script.Types)

--------------------------------------------------------------------------------
-- TYPES
--------------------------------------------------------------------------------

type PlayerData = PlayerData.Class
type Signal<T...> = Signal.Typed<T...>
type Promise = Promise.Class
type Trove = Trove.Class

export type BoolName = Types.BoolName
export type ColorName = Types.ColorName
export type NumberName = Types.NumberName
export type StringName = Types.StringName
export type SettingName = Types.SettingName

export type Device =
    | "Keyboard"
    | "Gamepad"
    | "Mobile"

type ISetting<TypeName, Type, Metadata = nil> = {
    Name: string,
    Type: TypeName,
    Device: Device?,
    Category: string,
    Description: string?,
    Metadata: Metadata?,
    Title: string?,
    Order: number?,
    Default: Type,
}

export type BoolSetting = ISetting<"Bool", boolean>
export type ColorSetting = ISetting<"Color", Color3>

export type NumberSetting = ISetting<"Number", number, {
    Range: NumberRange?,
    Inc: number?,
}>

export type StringSetting = ISetting<"String", string, {
    DisplayNames: {
        [string]: string,
    }?,

    Options: { string }?,
    Format: string?,
}>

export type Setting = 
    | BoolSetting
    | ColorSetting
    | NumberSetting
    | StringSetting

type Category = {
    Order: number,
    Settings: { Setting }
}

export type Value = boolean | Color3 | number | string

local settingsMap = {} :: {
    [string]: Setting
}

local categoryMap = {} :: {
    [string]: Category
}

local signalCache = {} :: {
    [string]: {
        Signal: Signal<any>,
        Current: any,
        Promise: Promise,
        Watcher: Signal.Connection,
    }
}

local immediateLocalCache = {} :: {
    [string]: {
        Value: any,
        Expiration: number,
    }
}

Settings.Enums = Types.Enums

--------------------------------------------------------------------------------
-- NETWORKING & SERIALIZATION
--------------------------------------------------------------------------------

local SET_VALUE = Network.Event("ChangeSetting", function (key, value): (string, any)
    assert(type(key) == "string", "Invalid key")

    local setting = settingsMap[key]
    assert(setting, "Invalid key")

    if setting.Type == "Bool" then
        assert(type(value) == "boolean", "Invalid value")
    elseif setting.Type == "Color" then
        if typeof(value) == "string" then
            value = Color3.fromHex(value)
        end

        assert(typeof(value) == "Color3", "Invalid value")
    elseif setting.Type == "Number" then
        assert(type(value) == "number", "Invalid value")
    elseif setting.Type == "String" then
        assert(type(value) == "string", "Invalid value")
    end

    return key, value
end)

local function deserialize(setting: Setting, value: any): Value?
    if setting.Type == "Bool" then
        if type(value) == "boolean" then
            return value
        end
    elseif setting.Type == "Color" then
        if type(value) == "string" then
            if string.match(value, "^#?%x%x%x%x%x%x$") then
                return Color3.fromHex(value)
            end
        elseif typeof(value) == "Color3" then
            return value
        end
    elseif setting.Type == "Number" then
        if type(value) == "number" then
            local meta = setting.Metadata
            local range = meta and meta.Range
            local inc = meta and meta.Inc

            if range then
                value = math.clamp(value, range.Min, range.Max)
            end

            if inc then
                value //= inc
                value *= inc
            end

            return value
        end
    elseif setting.Type == "String" then
        if type(value) == "string" then
            local meta = setting.Metadata
            local format = meta and meta.Format
            local options = meta and meta.Options

            if options then
                local index = table.find(options, value)

                if index then
                    return value
                end
            elseif format then
                if value:match(format) then
                    return value
                end
            else
                return value
            end
        end
    end

    return nil
end

local function serialize(setting: Setting, value: any): Value?
    if setting.Type == "Bool" then
        if type(value) == "boolean" then
            return value
        end
    elseif setting.Type == "Color" then
        if type(value) == "string" then
            if string.match(value, "^#?%x%x%x%x%x%x$") then
                return value
            end
        elseif typeof(value) == "Color3" then
            return value:ToHex()
        end
    elseif setting.Type == "Number" then
        if type(value) == "number" then
            local meta = setting.Metadata
            local range = meta and meta.Range
            local inc = meta and meta.Inc

            if range then
                value = math.clamp(value, range.Min, range.Max)
            end

            if inc then
                value //= inc
                value *= inc
            end

            return value
        end
    elseif setting.Type == "String" then
        if type(value) == "string" then
            local meta = setting.Metadata
            local format = meta and meta.Format
            local options = meta and meta.Options

            if options then
                local index = table.find(options, value)

                if index then
                    return value
                end
            elseif format then
                if value:match(format) then
                    return value
                end
            else
                return value
            end
        end
    end

    return nil
end

local function getValue(self: Setting, userId: number?): any
    if RunContext.IsClient then
        local now = os.clock()
        local cache = immediateLocalCache[self.Name]

        if cache and now < cache.Expiration then
            return cache.Value
        end
    end

    local data = PlayerData.Read(userId)

    if data then
        local serialized = data.Settings[self.Name]
        local value = deserialize(self, serialized)

        if value ~= nil then
            return value
        end
    end

    return self.Default
end

local function getChangedSignal(self: Setting, userId: number?): Signal<any>
    local cacheKey = `{self.Type}_{self.Name}_{userId}`
    local cached = signalCache[cacheKey]

    if cached then
        return cached.Signal
    end

    local cache = {}
    cache.Signal = Signal.new()
    cache.Current = getValue(self, userId)

    cache.Promise = PlayerData.Load(userId):andThen(function (data: PlayerData)
        local function update(value: any)
            local deserialized = deserialize(self, value)

            if deserialized ~= nil then
                cache.Signal:Fire(deserialized)
                cache.Current = deserialized

                immediateLocalCache[self.Name] = {
                    Value = deserialized,
                    Expiration = os.clock() + 2,
                }
            end
        end

        local init = rawget(data.CurrentData.Settings, self.Name)
        cache.Watcher = data:Connect(`Settings/{self.Name}`, update)
        update(init)
    end)

    signalCache[cacheKey] = cache
    return cache.Signal
end

local function setValueImpl(userId: number, key: string, value: any)
    local data = PlayerData.Get(userId)
    local setting = settingsMap[key]

    if not (setting and data.IsLoaded) then
        return
    end

    data:Patch(function (patch)
        local value = serialize(setting, value)

        if value ~= nil then
            patch.Settings[key] = value

            immediateLocalCache[key] = {
                Value = value,
                Expiration = os.clock() + 2,
            }
        end
    end)
end

local function setValue(self: Setting, value: any, userId: number?)
    local key = self.Name

    if RunContext.IsServer then
        if userId then
            setValueImpl(userId, key, value)
        end
    elseif RunContext.IsEdit then
        local StudioService = game:GetService("StudioService")
        local userId = StudioService:GetUserId()
        setValueImpl(userId, key, value)
    elseif RunContext.IsClient then
        local oldValue = getValue(self, userId)
        
        if oldValue == value then
            return
        end

        local changed = getChangedSignal(self, userId)
        changed:Fire(value)

        local client = SET_VALUE:Client()
        client:Fire(key, value)

        immediateLocalCache[key] = {
            Value = value,
            Expiration = os.clock() + 2,
        }
    end
end

function Settings.FindSetting(name: string): Setting?
    return settingsMap[name]
end

--------------------------------------------------------------------------------
-- Generic
--------------------------------------------------------------------------------

function Settings.GetValue(name: SettingName, userId: number?): Value
    local info = settingsMap[name]
    assert(info, "bad argument #1 to 'Get' (Setting expected)")
    return getValue(info, userId)
end

function Settings.SetValue(name: SettingName, value: Value, userId: number?)
    local info = settingsMap[name]
    assert(info, "bad argument #1 to 'SetValue' (Setting expected)")
    setValue(info, value, userId)
end

function Settings.GetValueChangedSignal(name: SettingName, userId: number?): Signal<Value>
    local info = settingsMap[name]
    assert(info, "bad argument #1 to 'GetValueChangedSignal' (Setting expected)")
    return getChangedSignal(info, userId)
end

--------------------------------------------------------------------------------
-- Bool
--------------------------------------------------------------------------------

function Settings.GetBool(name: BoolName, userId: number?): boolean
    local info = settingsMap[name]
    assert(info and info.Type == "Bool", "bad argument #1 to 'GetBool' (BoolSetting expected)")
    return getValue(info, userId)
end

function Settings.SetBool(name: BoolName, value: boolean, userId: number?)
    local info = settingsMap[name]
    assert(info and info.Type == "Bool", "bad argument #1 to 'SetBool' (BoolSetting expected)")
    setValue(info, value, userId)
end

function Settings.GetBoolChangedSignal(name: BoolName, userId: number?): Signal<boolean>
    local info = settingsMap[name]
    assert(info and info.Type == "Bool", "bad argument #1 to 'GetBoolChangedSignal' (BoolSetting expected)")
    return getChangedSignal(info, userId)
end

--------------------------------------------------------------------------------
-- Color
--------------------------------------------------------------------------------

function Settings.GetColor(name: ColorName, userId: number?): Color3
    local info = settingsMap[name]
    assert(info and info.Type == "Color", "bad argument #1 to 'GetColor' (ColorSetting expected)")
    return getValue(info, userId)
end


function Settings.SetColor(name: ColorName, value: Color3, userId: number?)
    local info = settingsMap[name]
    assert(info and info.Type == "Color", "bad argument #1 to 'SetColor' (ColorSetting expected)")
    setValue(info, value, userId)
end

function Settings.GetColorChangedSignal(name: ColorName, userId: number?): Signal<Color3>
    local info = settingsMap[name]
    assert(info and info.Type == "Color", "bad argument #1 to 'GetColorChangedSignal' (ColorSetting expected)")
    return getChangedSignal(info, userId)
end

--------------------------------------------------------------------------------
-- Number
--------------------------------------------------------------------------------

function Settings.GetNumber(name: NumberName, userId: number?): number
    local info = settingsMap[name]
    assert(info and info.Type == "Number", "bad argument #1 to 'GetNumber' (NumberSetting expected)")
    return getValue(info, userId)
end


function Settings.SetNumber(name: NumberName, value: number, userId: number?)
    local info = settingsMap[name]
    assert(info and info.Type == "Number", "bad argument #1 to 'SetNumber' (NumberSetting expected)")
    setValue(info, value, userId)
end

function Settings.GetNumberChangedSignal(name: NumberName, userId: number?): Signal<number>
    local info = settingsMap[name]
    assert(info and info.Type == "Number", "bad argument #1 to 'GetNumberChangedSignal' (NumberSetting expected)")
    return getChangedSignal(info, userId)
end

--------------------------------------------------------------------------------
-- String

function Settings.GetString(name: StringName, userId: number?): string
    local info = settingsMap[name]
    assert(info and info.Type == "String", "bad argument #1 to 'GetString' (StringSetting expected)")
    return getValue(info, userId)
end

function Settings.GetStringChangedSignal(name: StringName, userId: number?): Signal<string>
    local info = settingsMap[name]
    assert(info and info.Type == "String", "bad argument #1 to 'GetStringChangedSignal' (StringSetting expected)")
    return getChangedSignal(info, userId)
end

function Settings.SetString(name: StringName, value: string, userId: number?)
    local info = settingsMap[name]
    assert(info and info.Type == "String", "bad argument #1 to 'SetString' (StringSetting expected)")
    setValue(info, value, userId)
end

--------------------------------------------------------------------------------
-- Enum

Settings.SetEnum =
    Settings.SetString :: Types.SetEnum

Settings.GetEnum =
    (Settings.GetString :: any) :: Types.GetEnum

Settings.GetEnumChangedSignal =
    (Settings.GetStringChangedSignal :: any) :: Types.GetEnumChangedSignal

export type GetEnumSetting<T> = Types.GetEnumSetting<T>

--------------------------------------------------------------------------------

if RunContext.IsServer then
    local server = SET_VALUE:Server()

    server:On(function (player, key, value)
        local userId = player.UserId
        setValueImpl(userId, key, value)
    end)
end

--------------------------------------------------------------------------------
-- FRONTEND SETTINGS
--------------------------------------------------------------------------------

for categoryName: string, categoryInfo: any in Frontend :: any do
    if type(categoryInfo) ~= "table" then
        continue
    end

    local categoryOrder = if type(categoryInfo["$CategoryOrder"]) == "number"
        then categoryInfo["$CategoryOrder"]
        else 0

    local category = {
        Name = categoryName,
        Order = categoryOrder,
        Settings = {},
    }

    for settingName: string, settingRef: any in pairs(categoryInfo) do
        if type(settingRef) ~= "table" then
            continue
        end

        local default = settingRef.Default

        if default == nil then
            warn("Setting", categoryName, settingName, "is missing a default value")
            continue
        end

        local desc = settingRef.Description
        local device = settingRef.Device
        local title = settingRef.Title
        local order = settingRef.Order

        if desc ~= nil then
            desc = tostring(desc)
        end

        if title ~= nil then
            title = tostring(title)
        end

        if order ~= nil then
            order = tonumber(order)
        end

        if device ~= nil then
            device = tostring(device)
        end

        if type(default) == "boolean" then
            local bool: BoolSetting = {
                Type = "Bool",
                Category = categoryName,
                Name = settingName,
                Title = title,
                Order = order,
                Device = device,
                Default = default,
                Description = desc,
            }

            settingsMap[settingName] = table.freeze(bool)
        elseif type(default) == "number" then
            local min = tonumber(settingRef.Min)
            local max = tonumber(settingRef.Max)
            local inc = tonumber(settingRef.Inc)

            if min and max and min > max then
                max, min = min, max
            end

            if inc then
                inc = math.abs(inc)
            end

            local num: NumberSetting = {
                Type = "Number",
                Category = categoryName,
                Name = settingName,
                Title = title,
                Order = order,
                Device = device,
                Default = default,
                Description = desc,

                Metadata = table.freeze({
                    Range = if min and max
                        then NumberRange.new(min, max)
                        else nil,
                    
                    Inc = inc,
                }),
            }

            settingsMap[settingName] = table.freeze(num)
        elseif type(default) == "string" then
            if default:match("^#?%x%x%x%x%x%x$") then
                local color: ColorSetting = {
                    Type = "Color",
                    Category = categoryName,
                    Name = settingName,
                    Title = title,
                    Order = order,
                    Device = device,
                    Description = desc,
                    Default = Color3.fromHex(default),
                }

                settingsMap[settingName] = table.freeze(color)
            else
                local options = settingRef.Options
                local displayNames = settingRef.DisplayNames
                local format = settingRef.Format and tostring(settingRef.Format)

                if options ~= nil then
                    if type(options) ~= "table" then
                        warn("Setting", categoryName, settingName, "has invalid options")
                        continue
                    end

                    if #options == 0 then
                        warn("Setting", categoryName, settingName, "has no options defined")
                        continue
                    end

                    local index = table.find(options, default)

                    if index == nil then
                        warn("Setting", categoryName, settingName, "does not contain default value", default, "in options:", options)
                        continue
                    end

                    for i, option in ipairs(options) do
                        if type(option) ~= "string" then
                            warn("Setting", categoryName, settingName, "has invalid option at index", i)
                            continue
                        end
                    end

                    options = table.freeze(options)
                end

                if displayNames ~= nil then
                    if type(displayNames) ~= "table" then
                        warn("Setting", categoryName, settingName, "has invalid display names")
                        continue
                    end

                    if not options then
                        warn("Setting", categoryName, settingName, "has display names but no options")
                        continue
                    end

                    for option, displayName in pairs(displayNames) do
                        if type(option) ~= "string" or type(displayName) ~= "string" then
                            warn("Setting", categoryName, settingName, "has invalid display name for option", option)
                            continue
                        end

                        if not table.find(options, option) then
                            warn("Setting", categoryName, settingName, "has display name for non-existent option", option)
                            continue
                        end
                    end

                    displayNames = table.freeze(displayNames)
                end

                local str: StringSetting = {
                    Type = "String",
                    Category = categoryName,
                    Name = settingName,
                    Title = title,
                    Order = order,
                    Device = device,
                    Default = default,
                    Description = desc,

                    Metadata = table.freeze({
                        DisplayNames = displayNames,
                        Options = options,
                        Format = format,
                    }),
                }

                settingsMap[settingName] = table.freeze(str)
            end
        else
            warn("Setting", categoryName, settingName, "has an unsupported default value:", default)
            continue
        end

        table.insert(category.Settings, settingsMap[settingName])
    end

    categoryMap[categoryName] = table.freeze(category)
end

table.freeze(settingsMap)
table.freeze(categoryMap)

function Settings.GetData(): typeof(categoryMap)
    return categoryMap
end

--------------------------------------------------------------------------------

for key, value in Backend do
    rawset(Settings :: any, key, value)
end

return table.freeze(Settings) ::
    & typeof(Settings)
    & typeof(Backend)

--------------------------------------------------------------------------------