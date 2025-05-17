local UI = script:FindFirstAncestor("UI")
local React = require(UI.Common.React)

local Shared = game.ReplicatedStorage.Shared
local PlayerData = require(Shared.PlayerData)

local Hooks = script.Parent
local useSignal = require(Hooks.useSignal)

type SaveData = PlayerData.SaveData

--- A hook that provides the local player's save data.
--- @param ...? Optional prefix filters (case-sensitive, separated by `/`) for updating the state. Otherwise **ALL DATA CHANGES**  will update the state.
local function usePlayerData(...: string): (SaveData, boolean)
    local prefixes = { ... }
    local newPath = table.concat(prefixes, " | ")

    local playerData = PlayerData.Get()
    local path, setPath = React.useState(newPath)

    if newPath and path ~= newPath then
        setPath(newPath)
    end

    local data, setData = React.useState(playerData.CurrentData)
    local loaded, setLoaded = React.useState(playerData.IsLoaded)
    local lastUpdate = React.useRef(0)
    local pendingUpdate = React.useRef(nil :: thread?)

    useSignal(playerData.Loaded, function (isLoaded)
        if loaded ~= isLoaded then
            setLoaded(isLoaded)
            setData(playerData.CurrentData)
        end
    end, {})

    useSignal(playerData.Updated, function (patch)
        local matching = true

        if #prefixes > 0 then
            matching = false

            for i, prefix in ipairs(prefixes) do
                if patch.Path:sub(1, #prefix) == prefix then
                    matching = true
                    break
                end
            end
        end
        
        if matching then
            local now = tick()
            local timeSinceLastUpdate = now - lastUpdate.current

            -- If we have a pending update and it's been less than 0.1s, merge the updates
            if pendingUpdate.current and timeSinceLastUpdate < 0.1 then
                return
            end

            -- Clear any existing pending update
            if pendingUpdate.current then
                task.cancel(pendingUpdate.current)
            end

            -- Schedule a new update
            pendingUpdate.current = task.delay(0.05, function()
                local update = table.clone(playerData.CurrentData)
                lastUpdate.current = tick()
                pendingUpdate.current = nil
                setData(update)
            end)
        end
    end, { path })

    return data, loaded
end

return usePlayerData