--!strict

local Shared = game.ReplicatedStorage.Shared
local UI = script:FindFirstAncestor("UI")

local React = require(UI.Common.React)
local Signal = require(Shared.Signal)

type Signal<T...> = Signal.Typed<T...> | RBXScriptSignal<T...>

local function useSignal<T...>(signal: Signal<T...>?, callback: (T...) -> ()?, deps: {any}?)
    if deps and not table.find(deps, signal) then
        table.insert(deps, signal)
    end

    React.useEffect(function ()
        local signal: Signal.Typed<T...>? = signal :: any
        local conn = (signal and callback) and signal:Connect(callback)

        return function ()
            if conn then
                conn:Disconnect()
            end
        end
    end, deps)
end

return useSignal