------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Tags
-- MaximumADHD
-- December 22nd, 2020
------------------------------------------------------------------------------------------------------------------------------------------------------------------
--!native
--!strict

local Tags = {}
local Shared = script.Parent
local CollectionService = game:GetService("CollectionService")

local Trove = require(Shared.Trove)
type Trove = Trove.Class

local Signal = require(Shared.Signal)
type Signal<T...> = Signal.Typed<T...>

function Tags.GetTagged(tag: string): { Instance }
    return CollectionService:GetTagged(tag)
end

function Tags.GetInstanceAddedSignal(tag: string): RBXScriptSignal
    return CollectionService:GetInstanceAddedSignal(tag)
end

function Tags.GetInstanceRemovedSignal(tag: string): RBXScriptSignal
    return CollectionService:GetInstanceRemovedSignal(tag)
end

function Tags.FindFirstTagged(tag: string): Instance?
    local tagged = CollectionService:GetTagged(tag)

    if #tagged > 0 then
        return tagged[1]
    end

    return nil
end

function Tags.Bind(tag: string, onAdded: (Instance) -> (), onRemoved: (Instance) -> ()?): Trove.Class
    local maid = Trove.new()
    maid:Connect(Tags.GetInstanceAddedSignal(tag), onAdded)

    if onRemoved then
        maid:Connect(Tags.GetInstanceRemovedSignal(tag), onRemoved)
    end

    for i, tagged in CollectionService:GetTagged(tag) do
        task.spawn(onAdded, tagged)
    end

    return maid
end

function Tags.BindWithMaid(tag: string, onAdded: (Instance, Trove) -> (), onRemoved: (Instance) -> ()?): Trove.Class
    local baseMaid = Trove.new()
    local tagMaids = {}

    local bindMaid = Tags.Bind(tag, function(inst)
        local maid = baseMaid:Extend()
        tagMaids[inst] = maid

        maid:Add(function()
            tagMaids[inst] = nil

            if onRemoved then
                onRemoved(inst)
            end
        end)

        onAdded(inst, maid)
    end, function(inst)
        local maid = tagMaids[inst]

        if maid then
            maid:Clean()
        end
    end)

    bindMaid:Add(baseMaid)
    return bindMaid
end

return Tags
