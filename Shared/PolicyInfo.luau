local PolicyInfo = {}

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")

local Shared = script.Parent
local Promise = require(Shared.Promise)

export type Result = {
    AreAdsAllowed: boolean,
    ArePaidRandomItemsRestricted: boolean,

    AllowedExternalLinkReferences: {
        X: boolean,
        GitHub: boolean,
        Twitch: boolean,
        Discord: boolean,
        Guilded: boolean,
        YouTube: boolean,
        Facebook: boolean,
        [string]: boolean,
    },

    IsEligibleToPurchaseSubscription: boolean,
    IsPaidItemTradingAllowed: boolean,
    IsSubjectToChinaPolicies: boolean,
    IsContentSharingAllowed: boolean,
}

local promises = {} :: {
    [number]: Promise.Class
}

local function getPolicyInfo(player: Player?)
    return Promise.new(function (resolve, reject)
        if player then
            local policyInfo: any = PolicyService:GetPolicyInfoForPlayerAsync(player)
            local allowedLinks = {}

            for i, link in ipairs(policyInfo.AllowedExternalLinkReferences) do
                allowedLinks[link] = true
            end

            policyInfo.AllowedExternalLinkReferences = allowedLinks
            resolve(policyInfo)
        end
        
        resolve({
            AreAdsAllowed = false,
            ArePaidRandomItemsRestricted = false,
            AllowedExternalLinkReferences = {},
            IsEligibleToPurchaseSubscription = false,
            IsPaidItemTradingAllowed = false,
            IsSubjectToChinaPolicies = false,
        })
    end)
end

function PolicyInfo.Promise(userId: number?): Promise.Class
    local player = if userId
        then Players:GetPlayerByUserId(userId)
        else Players.LocalPlayer

    userId = player and player.UserId

    if userId and promises[userId] then
        return promises[userId]
    end

    if player and userId then
        local promise = Promise.retry(getPolicyInfo, 5, player)
        promises[userId] = promise

        promise:catch(function ()
            promises[userId] = nil
        end)

        return promise
    end

    return Promise.reject("Player not found!")
end

function PolicyInfo.GetAsync(userId: number?): Result
    return PolicyInfo.Promise(userId):expect()
end

return PolicyInfo