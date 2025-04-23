local UI = script:FindFirstAncestor("UI")
local React = require(UI.Common.React)

local Shared = game.ReplicatedStorage.Shared
local PolicyInfo = require(Shared.PolicyInfo)
local Promise = require(Shared.Promise)

-- Preload the policy info so it's available ASAP.
task.spawn(PolicyInfo.Promise)

local function usePolicyInfo(): PolicyInfo.Result
    local policyInfo, setPolicyInfo = React.useState(function ()
        local info = PolicyInfo.Promise()
        local status = info:getStatus()

        if status == Promise.Status.Resolved then
            return info:expect()
        end
        
        return {
            AreAdsAllowed = false,

            AllowedExternalLinkReferences = {
                X = false,
                GitHub = false,
                Twitch = false,
                Discord = false,
                Guilded = false,
                YouTube = false,
                Facebook = false,
            },

            ArePaidRandomItemsRestricted = true,
            IsEligibleToPurchaseSubscription = false,
            IsPaidItemTradingAllowed = false,
            IsSubjectToChinaPolicies = true,
            IsContentSharingAllowed = false,
        }
    end)

    React.useEffect(function ()
        local promise = PolicyInfo.Promise()
        promise:andThen(setPolicyInfo)
    end, {})

    return policyInfo
end

return usePolicyInfo