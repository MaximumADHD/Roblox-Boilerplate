--[[
    Creates a memoized Motion object set to the given initial value.

    Returns a binding that updates with the Motion, along with the Motion
    object.
]]

local UI = script:FindFirstAncestor("UI")
local Common = UI.Common

local React = require(Common.React)
local Ripple = require(Common.Ripple)

local Hooks = script.Parent
local useTimer = require(Hooks.useTimer)

type Binding<T> = React.Binding<T>
type Motion<T> = Ripple.Motion<T>

local function useMotion<T>(initialValue: T): (Binding<T>, Motion<T>)
    local motion = React.useMemo(function()
        return Ripple.createMotion(initialValue)
    end, {})

    local binding, setValue = React.useBinding(initialValue)

    useTimer(60, function (dt)
        local value = motion:step(dt)

        if value ~= binding:getValue() then
            setValue(value)
        end
    end, {})

    return binding, motion
end

return useMotion