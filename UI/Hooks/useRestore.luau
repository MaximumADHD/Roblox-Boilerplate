local UI = script:FindFirstAncestor("UI")
local React = require(UI.Common.React)
local mem = shared.__useRestoreTable

if mem == nil then
    mem = {}
    shared.__useRestoreTable = mem
end

type BasicStateAction<S> = ((S) -> S) | S
type Dispatch<A> = (A) -> ()

--- Functions the same as useState, but remembers its value across reloads of hoarcekat in edit mode.
--- @param restoreKey The key to use for restoring the value.
--- @param initialState The initial state of the value.
--- @param canRestore An optional function to validate if we should restore this value.
--- @return The value and a function to set the value.

local function useRestore<S>(restoreKey: string, initialState: (() -> S) | S, canRestore: ((S) -> boolean)?): (S, Dispatch<BasicStateAction<S>>)
    local name = debug.info(2, "s")
    restoreKey = `{name}_{restoreKey}`

    local value: S, setValue = React.useState(function (): S
        local restoredValue = mem[restoreKey]
        
        if restoredValue ~= nil then
            if canRestore and not canRestore(restoredValue) then
                restoredValue = nil
            end
        end

        if restoredValue ~= nil then
            return restoredValue
        end

        if type(initialState) == "function" then
            return initialState()
        end
        
        return initialState
    end)

    React.useEffect(function ()
        mem[restoreKey] = value
    end, { value })

    return value, setValue
end

return useRestore
