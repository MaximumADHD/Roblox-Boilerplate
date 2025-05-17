-- ConVar
-- MaximumADHD
-- February 28th, 2024

--!strict
local module = {
    DEV = 1,
    CHEAT = 2,
    LOCAL = 4,
    HIDDEN = 8,
    OPERATOR = 16,
    SERVER_OWNER = 32,

    CVAR_INT = 0,
    CVAR_BOOL = 1,
    CVAR_FLOAT = 2,
    CVAR_STRING = 3,
    CVAR_COLOR3 = 4,
    CVAR_COMMAND = 5,
}

local ConVar = {}
ConVar.__index = ConVar

local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Shared = script.Parent

local Tags = require(Shared.Tags)
local Signal = require(Shared.Signal)
local Promise = require(Shared.Promise)
local RunContext = require(Shared.RunContext)

local Settings = Shared.Settings
local Backend = require(Settings.Backend)
local Network = require(Shared.Network)

local PREFIX = RunContext.IsServer and "sv_" or "cl_"
local COLOR_HEX = "#?%x%x%x%x%x%x"

type Signal<T...> = Signal.Typed<T...>
type Connection = Signal.Connection
type Promise = Promise.Class

export type Class = typeof(setmetatable({} :: {
    Name: string,
    Type: number,
    Flags: number,

    Min: number?,
    Max: number?,
    Inc: number?,

    Description: string?,
    Dispatched: Signal<string, Player?>,

    Alias: string?,
    TextChatCommand: TextChatCommand?,

    _value: string,
    _cmdHook: (value: string, dispatcher: Player?) -> (boolean?, string?)?,
}, ConVar))

type SetConVarResponse = {
    Success: boolean?,
    Message: string?,
}

local Registry = {} :: {
    [string]: Class,
}

local Listeners = {} :: {
    [string]: Signal<Class, string, Player?>,
}

export type CommandState = {
    NotifySuccess: (message: string, player: Player?) -> (),
    NotifyError: (message: string, player: Player?) -> (),

    Players: { Player },
    UserIds: { number },

    Dispatcher: Player?,
    Args: { string },

    GetInt: (value: string?) -> number,
    GetBool: (value: string?) -> boolean,
    GetFloat: (value: string?) -> number,
    GetColor3: (value: string?) -> Color3,
}

type SetConVar = {
    Name: string,
    Value: string,
    UserRequested: boolean?,
}

type ConVarResult = {
    Name: string,
    Success: boolean?,
    Message: string?,
}

type DeclareConVar = {
    Name: string,
    Value: any,
    Flags: number,
    
    Min: number?,
    Max: number?,
    Description: string?,
}

local TargetResolvers = {
    ["@p"] = function (caller: number): { number }
        return { caller }
    end,

    ["@f"] = function (caller: number): { number }
        local results = {}

        for i, player in Players:GetPlayers() do
            if player:IsFriendsWith(caller) then
                table.insert(results, player.UserId)
            end
        end

        return results
    end,

    ["@r"] = function (caller: number): { number }
        local players = Players:GetPlayers()
        local player = players[math.random(1, #players)]
        return { player.UserId }
    end,
} :: {
    [string]: (caller: number) -> { number },
}

local SET_CONVAR = Network.Event("SetConVar", function (params: any): SetConVar
    assert(type(params) == "table", "Invalid parameters!")

    assert(type(params.Name) == "string", "Invalid Name!")
    assert(type(params.Value) == "string", "Invalid Value!")
    assert(type(params.UserRequested) == "boolean" or type(params.UserRequested) == "nil", "Invalid UserRequested!")

    return params
end)

local CONVAR_RESULT = Network.Event("ConVarResult", function (response: any): ConVarResult
    assert(type(response) == "table", "Invalid response!")

    assert(type(response.Success) == "boolean", "Invalid Success!")
    assert(type(response.Message) == "string", "Invalid Message!")

    return response
end)

module.Flags = ConVar
module.ErrorFeed = Signal.new() :: Signal<string, string>
module.SuccessFeed = Signal.new() :: Signal<string, string>

local function getPrivateServerOwnerId(): number
    if RunContext.IsServer and not RunContext.IsEdit then
        local id = game.PrivateServerOwnerId
        workspace:SetAttribute("PrivateServerOwnerId", id)

        return id
    else
        local id = workspace:GetAttribute("PrivateServerOwnerId")
        return tonumber(id) or 0
    end
end

local function resolveName(name: string): string
    return name:lower():gsub("%$", PREFIX)
end

local function setImpl(convar: Class, value: any?, dispatcher: Player?): (boolean?, string?)
    local str = if value ~= nil then tostring(value) else nil

    if str == nil then
        if convar.Type ~= module.CVAR_COMMAND then
            return false, "No value passed in!"
        end
    end

    str = str or ""
    assert(str)

    if str == "" then
        if convar.Type ~= module.CVAR_STRING then
            if convar.Type ~= module.CVAR_COMMAND then
                return true, `{convar.Name} is: {convar:GetString()}`
            end
        end
    end

    if convar.Type == module.CVAR_COMMAND then
        local hook = convar._cmdHook
        convar.Dispatched:Fire(str, dispatcher)

        if hook then
            return hook(str, dispatcher)
        else
            -- just assume the dispatch is connected to?
            return true
        end
    else
        if convar._value:lower() ~= str:lower() then
            convar._value = str
            convar.Dispatched:Fire(str, dispatcher)
        else
            return true, `{convar.Name} is already set to this!`
        end
    end

    return true, `Set {convar.Name} to {str}!`
end

local function canUseConVar(player: Player, cvar: string | Class): boolean
    local cvar = if type(cvar) == "string"
        then module.FindConVar(cvar)
        else cvar

    if cvar then
        local isDev = player:HasTag("Developer")
        local cheatsEnabled = not not (isDev or module.GetBool("sv_cheats"))
        local isServerOwner = isDev or getPrivateServerOwnerId() == player.UserId
        local isOperator = player:HasTag("Operator") or isServerOwner

        if cvar:HasFlag(module.DEV) and not isDev then
            return false
        end

        if cvar:HasFlag(module.CHEAT) and not cheatsEnabled then
            return false
        end

        if cvar:HasFlag(module.SERVER_OWNER) and not isServerOwner then
            return false
        end

        if cvar:HasFlag(module.OPERATOR) and not isOperator then
            return false
        end

        return true
    end
    
    return false
end

function ConVar.HasFlag(self: Class, flag: number): boolean
    return bit32.btest(self.Flags, flag)
end

--- Sets a convar value on behalf of a player, taking the permissions of the command and
--- the privileges of the player into account.
local function setFromPlayer(player: Player, convar: Class, value: any): (boolean?, string?)
    if not canUseConVar(player, convar) then
        local context = 
            if convar:HasFlag(module.DEV) then
                " developer"
            elseif convar:HasFlag(module.SERVER_OWNER) then
                " server owner"
            elseif convar:HasFlag(module.OPERATOR) then
                " operator"
            else
                ""

        if convar.Type == module.CVAR_COMMAND then
            if convar:HasFlag(module.CHEAT) then
                return false, `Cannot use /{convar.Name} unless sv_cheats is set to 1.`
            end

            return false, `You do not have permission to use{context} command /{convar.Name}!`
        else
            if convar:HasFlag(module.CHEAT) then
                return false, `Cannot change {convar.Name} unless sv_cheats is set to 1.`
            end

            return false, `You do not have permission to change{context} convar {convar.Name}!`
        end
    end

    return setImpl(convar, value, player)
end

local function getBool(value: string?): boolean
    if value then
        if value:lower() == "true" then
            return true
        end

        local num = tonumber(value)

        if num and num ~= 0 then
            return true
        end
    end

    return false
end

local function getFloat(value: string?): number
    local num = tonumber(value)

    if num then
        return num
    end
    
    if value == nil or value:lower() == "false" then
        return 0
    elseif value:lower() == "true" then
        return 1
    else
        return 0
    end
end

local function getInt(value: string?): number
    return (getFloat(value) + .5) // 1
end

local function getColor3(value: string?): Color3
    if value == nil then
        return Color3.new()
    elseif string.match(value:lower(), COLOR_HEX) then
        return Color3.fromHex(value)
    end

    local num = getFloat(value)
    return Color3.fromRGB(num, num, num)
end

function ConVar.GetString(self: Class): string
    return self._value
end

function ConVar.GetFloat(self: Class): number
    local value = getFloat(self._value)
    local min, max = self.Min, self.Max

    if min and max then
        value = math.clamp(value, min, max)
    elseif min then
        value = math.max(value, min)
    elseif max then
        value = math.min(value, max)
    end

    return value
end

function ConVar.GetBool(self: Class): boolean
    return getBool(self._value)
end

function ConVar.GetInt(self: Class): number
    return getFloat(self._value)
end

function ConVar.GetColor3(self: Class): Color3
    local value = self:GetString()

    if string.match(value:lower(), COLOR_HEX) then
        return Color3.fromHex(value)
    end

    local num = self:GetFloat()
    return Color3.fromRGB(num, num, num)
end

function ConVar.GetValue(self: Class): (number | boolean | string | Color3)
    local cvarType = self.Type

    if cvarType == module.CVAR_INT then
        return self:GetInt()
    elseif cvarType == module.CVAR_BOOL then
        return self:GetBool()
    elseif cvarType == module.CVAR_FLOAT then
        return self:GetFloat()
    elseif cvarType == module.CVAR_COLOR3 then
        return self:GetColor3()
    else
        return self:GetString()
    end
end

--- Tries to set the value of this convar.
--- * If being set from the client, it will have to go through server validation.
--- * If being set from the server, it will be set immediately.
--- @param value The value to set the convar to.
function ConVar.SetValue(self: Class, value: any, userRequested: boolean?): ()
    if RunContext.IsClient then
        if self:HasFlag(module.LOCAL) then
            local player = assert(Players.LocalPlayer)
            setFromPlayer(player, self, value)
        else
            local setConVar = SET_CONVAR:Client()

            if self.Type ~= module.CVAR_COMMAND then
                if self:GetString():lower() == tostring(value):lower() then
                    if userRequested then
                        module.SuccessFeed:Fire(self.Name, "ConVar is already set to this!")
                    end
                    
                    return
                end
            end

            setConVar:Fire({
                Name = self.Name,
                Value = tostring(value),
                UserRequested = userRequested,
            })
        end
    else
        setImpl(self, value)
    end
end

function ConVar.SetTextChatCommand(self: Class, command: TextChatCommand): ()
    self.TextChatCommand = command

    if self.Alias then
        command.SecondaryAlias = self.Alias
    end
end

function ConVar.Connect(self: Class, callback: (value: string, dispatcher: Player?) -> ()): Signal.Connection
    task.spawn(callback, self._value)
    return self.Dispatched:Connect(callback)
end

function ConVar.HookCommand(self: Class, callback: (state: CommandState) -> (boolean?, string?), alias: string?): ()
    if RunContext.IsClient then
        return
    end
    
    local result = CONVAR_RESULT:Server()

    local state = {
        Players = {},
        UserIds = {},

        Args = {},
        Dispatcher = nil :: Player?,

        GetInt = getInt,
        GetBool = getBool,
        GetFloat = getFloat,
        GetColor3 = getColor3,
    }
    
    state.NotifySuccess = function (message: string, player: Player?)
        local player = player or state.Dispatcher
        
        if player then
            result:Fire(player, {
                Name = self.Name,
                Success = true,
                Message = message,
            })
        end
    end

    state.NotifyError = function (message: string, player: Player?)
        local player = player or state.Dispatcher

        if player then
            result:Fire(player, {
                Name = self.Name,
                Success = false,
                Message = message,
            })
        end
    end

    self._cmdHook = function (value, dispatcher)
        local targets, args = module.ReadCommand(value, dispatcher)
        local players = {}

        state.Players = players
        state.UserIds = targets

        state.Dispatcher = dispatcher
        state.Args = args

        for i, userId in ipairs(targets) do
            local player = Players:GetPlayerByUserId(userId)

            if player then
                table.insert(players, player)
            end
        end

        return callback(state)
    end

    if alias then
        self.Alias = alias

        if self.TextChatCommand then
            self.TextChatCommand.SecondaryAlias = alias
        end
    end
end

function module.FindConVar(name: string): Class?
    local index = resolveName(name)
    return Registry[index]
end

function module.GetString(name: string): string?
    local convar = module.FindConVar(name)

    if convar then
        return convar:GetString()
    end

    return nil
end

function module.GetBool(name: string): boolean?
    local convar = module.FindConVar(name)

    if convar then
        return convar:GetBool()
    end

    return nil
end

function module.GetInt(name: string): number?
    local convar = module.FindConVar(name)

    if convar then
        return convar:GetInt()
    end

    return nil
end

function module.GetFloat(name: string): number?
    local convar = module.FindConVar(name)

    if convar then
        return convar:GetFloat()
    end

    return nil
end

function module.GetColor3(name: string): Color3?
    local convar = module.FindConVar(name)

    if convar then
        return convar:GetColor3()
    end

    return nil
end

function module.Declare(name: string, value: (number | string | boolean)?, flags: number, desc: string?, min: number?, max: number?, inc: number?): Class
    local isCmd = false
    name = name:lower()

    if name:sub(1, 1) == "/" then
        name = name:sub(2)
        isCmd = true
        value = ""
    end

    if Registry[name] then
        local convar = Registry[name]

        if convar.Type ~= module.CVAR_COMMAND then
            setImpl(convar, value)
        end

        return convar
    end

    local cvarType
    local val = tostring(value)

    if isCmd then
        cvarType = module.CVAR_COMMAND
    elseif type(value) == "boolean" then
        cvarType = module.CVAR_BOOL
    elseif type(value) == "number" then
        if val:find("%.") or (inc and inc < 1) then
            cvarType = module.CVAR_FLOAT
        else
            cvarType = module.CVAR_INT
        end
    else
        local num = tonumber(val)

        if num then
            if val:find("%.") or (inc and inc < 1) then
                cvarType = module.CVAR_FLOAT
            else
                cvarType = module.CVAR_INT
            end
        elseif string.match(val, COLOR_HEX) then
            cvarType = module.CVAR_COLOR3
        else
            cvarType = module.CVAR_STRING
        end
    end

    if name:sub(1, 3) == "cl_" then
        flags = bit32.bor(flags, module.LOCAL)
    end

    local convar: Class = setmetatable({
        Name = name,
        Type = cvarType,

        Min = min,
        Max = max,
        Inc = inc,

        Flags = flags,
        Description = desc,
        Dispatched = Signal.new(),

        _value = val,
    }, ConVar)

    local function update(value, dispatcher)
        local listener = Listeners[name]

        if listener then
            listener:Fire(convar, value, dispatcher)
        end
    end

    convar.Dispatched:Connect(update)
    Registry[name] = convar
    update(val)

    local makeCmd = not RunContext.IsEdit and if RunContext.IsServer
        then not convar:HasFlag(module.LOCAL)
        else convar:HasFlag(module.LOCAL)

    if makeCmd then
        local command = Instance.new("TextChatCommand")
        command.PrimaryAlias = `/{name}`
        command.Name = name
        command.Enabled = true
        command.AutocompleteVisible = RunContext.IsStudio
        command.Parent = TextChatService

        command.Triggered:Connect(function (source, message)
            local player = Players:GetPlayerByUserId(source.UserId)

            if player then
                local args = message:gsub(command.PrimaryAlias .. " ?", "")

                if command.SecondaryAlias ~= "" then
                    args = args:gsub(command.SecondaryAlias .. " ?", "")
                end
                
                local success, response = setFromPlayer(player, convar, args)
                
                if response then
                    if RunContext.IsServer then
                        local result = CONVAR_RESULT:Server()

                        result:Fire(player, {
                            Name = convar.Name,
                            Success = success,
                            Message = response,
                        })
                    elseif success then
                        module.SuccessFeed:Fire(convar.Name, response)
                    else
                        module.ErrorFeed:Fire(convar.Name, response)
                    end
                end
            end
        end)

        command:SetAttribute("Description", desc)
        command:SetAttribute("Type", cvarType)
        command:SetAttribute("Flags", flags)
        command:SetAttribute("Value", val)

        command:SetAttribute("Min", min)
        command:SetAttribute("Max", max)
        command:SetAttribute("Inc", inc)

        convar:Connect(function ()
            local newValue = convar:GetValue()
            command:SetAttribute("Value", newValue)
        end)

        command:AddTag("ConVar")
        convar.TextChatCommand = command
    end

    return convar
end

function module.GetConVars()
    return table.clone(Registry)
end

function module.Execute(cmd: string, userRequested: boolean?)
    local convar

    local args = cmd:gsub("^[A-z_]+", function (name)
        convar = module.FindConVar(name)
        return ""
    end)

    if convar then
        convar:SetValue(args:sub(2), userRequested)
    end
end

function module.Listen(nameId: string, callback: (convar: Class, value: string, dispatcher: Player?) -> ()): Connection
    local name = resolveName(nameId)
    local listener = Listeners[name]
    local convar = module.FindConVar(name)

    if not listener then
        listener = Signal.new()
        Listeners[name] = listener
    end

    if convar and convar.Type ~= module.CVAR_COMMAND then
        local value = convar:GetString()
        task.defer(callback, convar, value)
    end

    return listener:Connect(callback)
end

function module.AddTargetSelector(selector: string, callback: (caller: number) -> { number })
    TargetResolvers[selector] = callback
end

function module.ResolveTarget(selector: string, caller: number): { number }
    local resolver = TargetResolvers[selector]

    if resolver then
        return resolver(caller)
    end

    return {}
end

function module.ReadCommand(value: string, dispatcher: Player?): ({ number }, { string })
    local caller = dispatcher and dispatcher.UserId or 0
    local results = {}

    local args = value:split(" ")
    local selector = table.remove(args, 1)

    for i = #args, 1, -1 do
        if args[i] == "" then
            table.remove(args, i)
        end
    end
    
    local lowerSel = selector and selector:lower()
    local resolver = lowerSel and TargetResolvers[lowerSel]

    if resolver then
        results = resolver(caller)
        return results, args
    end

    if lowerSel and #lowerSel > 0 then
        for i, player in Players:GetPlayers() do
            local lowerName = player.Name:lower()
            local lowerDisp = player.DisplayName:lower()

            local canInsert = lowerName:sub(1, #lowerSel) == lowerSel
                or lowerDisp:sub(1, #lowerSel) == lowerSel
                or lowerName == lowerSel
                or lowerDisp == lowerSel

            if canInsert then 
                table.insert(results, player.UserId)
            end
        end
    end

    if #results == 0 then
        -- assume we're targeting ourselves?
        if selector and selector ~= "" then
            table.insert(args, 1, selector)
        end

        table.insert(results, caller)
    end

    return results, args
end

if RunContext.IsServer then
    --local declare = DECLARE_CONVAR:Server()
    local setConVar = SET_CONVAR:Server()
    local convarResult = CONVAR_RESULT:Server()

    local function onPlayerAdded(player: Player)
        local userId = player.UserId
        local userStr = tostring(userId)

        if Backend.Admins[userStr] then
            player:AddTag("Developer")
        end

        if getPrivateServerOwnerId() == userId then
            player:AddTag("Operator")
        end
    end

    setConVar:On(function (player, params)
        local name = params.Name
        local value = params.Value
        local convar = Registry[name]

        local result: ConVarResult = {
            Name = name,
            Success = false,
            Message = "Unknown error!"
        }

        if convar then
            local success, response = setFromPlayer(player, convar, value)
            result.Success = success
            result.Message = response or (success and "Set convar!" or "Failed to set convar!")
        else
            result.Message = "ConVar not found!"
        end
        
        if params.UserRequested then
            convarResult:Fire(player, result)
        end
    end)

    Players.PlayerAdded:Connect(onPlayerAdded)

    for i, player in Players:GetPlayers() do
        task.spawn(onPlayerAdded, player)
    end
elseif not RunContext.IsEdit then
    local result = CONVAR_RESULT:Client()

    result:On(function (response)
        local convar = Registry[response.Name]

        if convar and response.Message then
            if response.Success then
                module.SuccessFeed:Fire(convar.Name, response.Message)
            else
                module.ErrorFeed:Fire(convar.Name, response.Message)
            end
        end
    end)

    Tags.Bind("ConVar", function (cvar: Instance)
        if not cvar:IsA("TextChatCommand") then
            return
        end

        local name = cvar.Name
        local value = cvar:GetAttribute("Value")
        local flags = tonumber(cvar:GetAttribute("Flags")) or 0
        local desc = tostring(cvar:GetAttribute("Description"))
        
        local cvarType = cvar:GetAttribute("Type")
        local isCmd = cvarType == module.CVAR_COMMAND

        if isCmd then
            name = "/" .. name
        end

        local min = tonumber(cvar:GetAttribute("Min"))
        local max = tonumber(cvar:GetAttribute("Max"))
        local inc = tonumber(cvar:GetAttribute("Inc"))

        if typeof(value) == "Color3" then
            value = "#" .. value:ToHex()
        end

        if type(value) == "number" or type(value) == "string" or type(value) == "boolean" then
            local listener = cvar:GetAttributeChangedSignal("Value")
            local convar = module.Declare(name, value, flags, desc, min, max, inc)

            listener:Connect(function ()
                local newValue = cvar:GetAttribute("Value")
                setImpl(convar, newValue)
            end)
            
            convar:SetTextChatCommand(cvar)
        end
    end)
end

setmetatable(module, {
    __call = module.Declare
})

-- Declare some default convars.
local op = module.Declare("/op", "{name}", module.SERVER_OWNER, "Gives a player operator permissions.")
local ban = module.Declare("/ban", "{name}", module.OPERATOR, "Bans a player from the session.")
local kick = module.Declare("/kick", "{name}", module.OPERATOR, "Kicks a player from the game.")

local exec = module.Declare("/exec", "{name}", module.DEV, "Executes a test script.")
local sv_cheats = module.Declare("sv_cheats", false, module.OPERATOR, "Controls whether normal users can use commands flagged as cheats.")
local cheated_session = module.Declare("_cheated_session", false, module.DEV + module.HIDDEN, "Has this session ever had cheats enabled?")

module.CanUseConVar = canUseConVar

function module.IsCheatedSession()
    return cheated_session:GetBool()
end

sv_cheats:Connect(function ()
    local value = sv_cheats:GetBool()

    if value then
        cheated_session:SetValue(true)
    end
end)

if sv_cheats:GetBool() then
    cheated_session:SetValue(true)
end

if RunContext.IsServer then
    local banList = {}

    local function onPlayerAdded(player: Player)
        local userId = player.UserId
        local userStr = tostring(userId)

        if banList[userStr] then
            player:Kick("You are banned from this session!")
        end
    end

    op:HookCommand(function (state)
        local arg = state.Args[1]

        for i, player in ipairs(state.Players) do
            local new = not player:HasTag("Operator")

            if arg then
                new = state.GetBool(arg)
            end

            if new then
                player:AddTag("Operator")
                state.NotifySuccess(`Gave operator permissions to {player.DisplayName}!`)
            else
                player:RemoveTag("Operator")
                state.NotifySuccess(`Removed operator permissions from {player.DisplayName}!`)
            end
        end

        if #state.Players == 0 then
            return false, "No players found!"
        end

        return true
    end)

    kick:HookCommand(function (state)
        for i, player in ipairs(state.Players) do
            if player.UserId == getPrivateServerOwnerId() then
                return false, "Cannot kick the server owner!"
            end

            if player:HasTag("Operator") then
                return false, "Cannot kick an operator!"
            end
            
            state.NotifySuccess(`Kicked {player.Name}!`)
            player:Kick("You've been kicked from this session!")
        end

        return true
    end)

    ban:HookCommand(function (state)
        for i, player in ipairs(state.Players) do
            if player.UserId == getPrivateServerOwnerId() then
                return false, "Cannot ban the server owner!"
            end

            if player:HasTag("Operator") then
                return false, "Cannot ban an operator!"
            end

            banList[tostring(player.UserId)] = true
            player:Kick("You've been banned from this session.")

            state.NotifySuccess(`Banned {player.Name} from this session!`)
        end

        return true
    end)

    exec:HookCommand(function (state)
        local config = game.ReplicatedStorage.Config
        local scriptName = state.Args[1]

        if not scriptName then
            return false, "No script name provided!"
        end

        for i, cfg in config.Scripts:GetChildren() do
            if not cfg:IsA("StringValue") then
                continue
            end

            if cfg.Name:lower() == scriptName:lower() then
                task.spawn(function ()
                    local inBlockComment = false

                    for line in cfg.Value:gmatch("[^\r\n]+") do
                        -- Check for block comment starts and ends.
                        while #line > 0 do
                            if inBlockComment then
                                local endBlock = line:find("*/")

                                if endBlock then
                                    line = line:sub(endBlock + 2)
                                    inBlockComment = false
                                else
                                    break
                                end
                            else
                                local startBlock = line:find("/*")

                                if startBlock then
                                    line = line:sub(1, startBlock - 1)
                                    inBlockComment = true
                                else
                                    break
                                end
                            end
                        end

                        local split = line:split(" ")
                        local start = split[1]

                        if start and start:sub(1, 2) == "//" then
                            continue
                        end

                        for i, cmd in line:split(";") do
                            local words = cmd:split(" ")
                            local cmd = words[1]

                            if cmd:lower() == "wait" then
                                local time = tonumber(words[2])

                                if time then
                                    task.wait(time)
                                else
                                    RunService.Heartbeat:Wait()
                                end
                            else
                                module.Execute(line)
                            end
                        end
                    end
                end)

                return true, "Executing script: " .. cfg.Name
            end
        end

        return false, "Script not found!"
    end)

    Players.PlayerAdded:Connect(onPlayerAdded)
end

-- For developer console?
_G.Run = module.Execute

-- Auto Exec
task.spawn(function ()
    if not (RunContext.IsTestRun and RunContext.IsClient) then
        return
    end

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Config = ReplicatedStorage.Config

    local AutoExec = require(Config.AutoExec) :: { 
        [string]: string | { string }
    }

    if AutoExec then
        local player = Players.LocalPlayer
        local config = player and AutoExec[player.Name]

        if config then
            while true do
                local char = player.Character

                if char and char.Parent then
                    break
                end

                player.CharacterAdded:Wait()
            end

            if type(config) == "table" then
                for i, scriptName in config do
                    if type(scriptName) == "string" then
                        module.Execute(`exec {scriptName}`)
                    end
                end
            else
                module.Execute(`exec {config}`)
            end
        end
    end
end)

return table.freeze(module)