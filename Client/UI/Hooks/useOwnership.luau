local Shared = game.ReplicatedStorage.Shared
local Marketplace = require(Shared.Marketplace)

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local Promise = require(Shared.Promise)
type Promise = Promise.Class

local UI = script:FindFirstAncestor("UI")
local React = require(UI.Common.React)

local function useOwnership(itemId: number?, infoType: Enum.InfoType?): boolean
    local owned, setOwned = React.useState(function ()
        local result = false

        if itemId then
            local promise = Marketplace.GetOwnership(player, itemId, infoType)
            
            promise:now():andThen(function (owned)
                result = owned
            end):catch(function ()
                result = false
            end)
        end

        return result
    end)

    React.useEffect(function ()
        if itemId then
            local promise = Marketplace.GetOwnership(player, itemId, infoType)
            promise:andThen(setOwned)
        end
    end, {
        itemId,
        infoType,
    } :: { any })

    return owned
end

return useOwnership