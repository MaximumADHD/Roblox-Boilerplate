local UI = script:FindFirstAncestor("UI")
local React = require(UI.Common.React)

local Shared = game.ReplicatedStorage.Shared
local Guid = require(Shared.Guid)

type AttributeMemo = {
    -- Guid
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

local function useAttributeBinding<T>(inst: Instance?, name: string, reducer: (unknown) -> T)
    local guidRef = React.useRef(Guid.Create())
    local guid = guidRef.current
    
    local initialValue = inst and inst:GetAttribute(name)
    local value, setValue = React.useBinding(reducer(initialValue))

    React.useEffect(function (): (() -> ())?
        local memo = inst and getAttributeMemo(inst, name)

        if inst and memo then
            memo[guid] = setValue
            setValue(reducer(inst:GetAttribute(name)))

            return function ()
                memo[guid] = nil
            end
        end

        return nil
    end, {
        inst,
        name,
    } :: { any })

    return value:map(reducer)
end

return useAttributeBinding