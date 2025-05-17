local UI = script:FindFirstAncestor("UI")
local React = require(UI.Common.React)

local Shared = game.ReplicatedStorage.Shared
local Settings = require(Shared.Settings)

local Hooks = script.Parent
local useSignal = require(Hooks.useSignal)
local usePlayerData = require(Hooks.usePlayerData)

type SettingName = Settings.SettingName
type NumberName = Settings.NumberName
type StringName = Settings.StringName
type ColorName = Settings.ColorName
type BoolName = Settings.BoolName
type Value = Settings.Value

type useSetting<Name, T> = 
    (Name) -> (
        T,
        (T) -> (), 
        (T) -> ()
    )

local useSetting = (function (name: SettingName)
    local _, loaded = usePlayerData("Settings")
    local init = React.useRef(false)

    local value, setValue = React.useState(function ()
        return Settings.GetValue(name)
    end)

    local signal = Settings.GetValueChangedSignal(name)
    useSignal(signal, setValue, { name })

    React.useEffect(function ()
        if not init.current then
            init.current = true
            return
        end
        
        signal:Fire(value)
    end, { value })

    -- Dumb hack to force the value to update when the player data is loaded
    React.useEffect(function ()
        setValue(Settings.GetValue(name))
    end, {loaded})

    return value, setValue, function (commitValue)
        Settings.SetValue(name, commitValue)
    end
end :: any) :: (
    & useSetting<BoolName, boolean>
    & useSetting<NumberName, number>
    & useSetting<StringName, string>
    & useSetting<string, any>
)

return useSetting