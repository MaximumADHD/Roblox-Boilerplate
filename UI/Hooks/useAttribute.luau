local UI = script:FindFirstAncestor("UI")
local React = require(UI.Common.React)

local Shared = game.ReplicatedStorage.Shared
local Guid = require(Shared.Guid)

type AttributeMemo = {
    [string]: (any) -> (),
}

type InstanceMemo = {
    [string]: AttributeMemo
}

local memos = {} :: {
    [Instance]: InstanceMemo
}

local function getInstanceMemo(inst: Instance)
    if not memos[inst] then
        memos[inst] = {}
        --print("alloc inst-attr memo", inst)

        inst.Destroying:Once(function ()
            memos[inst] = nil
            --print("free inst-attr memo", inst)
        end)
    end

    return memos[inst]
end

local function getAttributeMemo(inst: Instance, attrName: string): AttributeMemo
    local instMemo = getInstanceMemo(inst)

    if instMemo[attrName] then
        return instMemo[attrName]
    end

    local listener = inst:GetAttributeChangedSignal(attrName)
    local attrMemo = {}

    local conn = listener:Connect(function ()
        local new = inst:GetAttribute(attrName)

        for guid, set in pairs(attrMemo) do
            set(new)
        end
    end)

    inst.Destroying:Once(function ()
        conn:Disconnect()
        table.clear(attrMemo)
        instMemo[attrName] = nil
    end)

    instMemo[attrName] = attrMemo
    return attrMemo
end

local function useAttribute<T>(inst: Instance?, name: string, reducer: (unknown) -> T): T
    local guid = React.useState(Guid.Create)

    local attr, setAttr = React.useState(function ()
        return inst and inst:GetAttribute(name)
    end)

    React.useEffect(function (): (() -> ())?
        local memo = inst and getAttributeMemo(inst, name)

        if inst and memo then
            memo[guid] = setAttr
            setAttr(inst:GetAttribute(name))

            return function ()
                memo[guid] = nil
            end
        end

        return nil
    end, {
        inst,
        name,
    } :: { any })

    return reducer(attr)
end

return useAttribute