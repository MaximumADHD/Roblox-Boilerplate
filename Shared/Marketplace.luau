local Shared = script.Parent
local Promise = require(Shared.Promise)

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
type Promise = Promise.Class

local ownership = {} :: {
    [Player]: {
        [string]: Promise
    }
}

local productInfo = {} :: {
    [string]: Promise
}

export type ProductInfo = {
    AssetId: number,
    AssetTypeId: number,

    Creator: {
        Id: number,
        Name: string,
    },

    Description: string,
    IconImageAssetId: number,
    IsForSale: boolean,
    IsPublicDomain: boolean,
    Name: string,
    PriceInRobux: number,
    ProductId: number,
    ProductType: Enum.AssetType,
    Created: string,
    Updated: string,
}

local playerOwnsItem = Promise.promisify(function (player: Player, itemId: any, infoType: Enum.InfoType?)
    if infoType == Enum.InfoType.Subscription then
        local status = MarketplaceService:GetUserSubscriptionStatusAsync(player, itemId)
        return status.IsSubscribed
    elseif infoType == Enum.InfoType.GamePass then
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, itemId)
    elseif infoType == Enum.InfoType.Bundle then
        return MarketplaceService:PlayerOwnsBundle(player, itemId)
    elseif infoType == Enum.InfoType.Product then
        return false -- Products cannot be owned.
    else
        return MarketplaceService:PlayerOwnsAsset(player, itemId)
    end
end)

local getProductInfo = Promise.promisify(function (id: number, infoType: Enum.InfoType?)
    return MarketplaceService:GetProductInfo(id, infoType)
end)

local function promiseOwnership(player: Player, id: number, infoType: Enum.InfoType?): Promise
    local infoType = infoType or Enum.InfoType.Asset
    local playerOwnership = ownership[player]

    if not playerOwnership then
        playerOwnership = {}
        ownership[player] = playerOwnership
    end

    local key = `{infoType.Name}:{id}`
    local promise = playerOwnership[key]

    if not promise then
        local new = Promise.retry(playerOwnsItem, 5, player, id, infoType)
        playerOwnership[key] = new

        new:catch(function ()
            if playerOwnership[key] == new then
                playerOwnership[key] = nil
            end
        end)

        promise = new
    end

    return promise
end

local function promiseProductInfo(id: number, infoType: Enum.InfoType?): Promise
    local infoType = infoType or Enum.InfoType.Asset
    local key = `{infoType.Name}:{id}`
    local promise = productInfo[key]

    if not promise then
        local new = Promise.retry(getProductInfo, 5, id, infoType)
        productInfo[key] = new

        new:catch(function ()
            if productInfo[key] == new then
                productInfo[key] = nil
            end
        end)

        promise = new
    end

    return promise
end

Players.PlayerRemoving:Connect(function (player)
    ownership[player] = nil
end)

return table.freeze({
    GetOwnership = promiseOwnership,
    GetProductInfo = promiseProductInfo
})