local Root = script:FindFirstAncestor("UI")

local Common = Root.Common
local React = require(Common.React)

local Shared = game.ReplicatedStorage.Shared
local Marketplace = require(Shared.Marketplace)

local Promise = require(Shared.Promise)
type Promise = Promise.Class

local promises = {} :: {
    [string]: Promise
}

export type ProductInfo = Marketplace.ProductInfo

local function getProductInfo(maybeId: any?, infoType: Enum.InfoType): Promise
    local id = tonumber(maybeId) or 0

    if id > 0 then
        return Marketplace.GetProductInfo(id, infoType)
    end

    return Promise.reject(`Invalid Id: {id} {infoType}`)
end

local function useProductInfo(maybeId: number?, maybeInfoType: Enum.InfoType?): ProductInfo?
    local id = maybeId or 0
    local infoType = maybeInfoType or Enum.InfoType.Asset
    local key = `{infoType.Name}_{id}`

    local info, setInfo = React.useState(function (): ProductInfo?
        local promise = promises[key]

        if not promise then
            promise = getProductInfo(id, infoType):catch(function ()
                promises[key] = nil
            end)
            
            promises[key] = promise
        end

        local status = promise:getStatus()

        if status == "Completed" then
            return promise:expect()
        end

        return nil
    end)

    React.useEffect(function ()
        local promise = promises[key]

        if not promise then
            promise = getProductInfo(id, infoType)
            promises[key] = promise
        end

        local chain = promise:andThen(function (newInfo: ProductInfo)
            if newInfo and info ~= newInfo then
                setInfo(newInfo)
            else
                setInfo(nil)
            end
        end):catch(function ()
            setInfo(nil)
        end)

        return function ()
            chain:cancel()
        end
    end, { 
        id, 
        infoType 
    } :: { any })

    return info
end

return useProductInfo