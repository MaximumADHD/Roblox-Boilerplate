--!strict

local UI = script:FindFirstAncestor("UI")
local React = require(UI.Common.React)

local Hooks = script.Parent
local useSignal = require(Hooks.useSignal)

local function useChild(inst: Instance?, name: string, recursive: boolean?): Instance?
    local child: Instance?, setChild = React.useState(nil :: Instance?)
    local parent: Instance?, setParent = React.useState(inst)

    if parent ~= inst then
        setChild(inst and inst:FindFirstChild(name, recursive))
        setParent(inst)
    end

    local addEvent: RBXScriptSignal? = parent and if recursive 
        then parent.DescendantAdded 
        else parent.ChildAdded

    React.useEffect(function ()
        local newChild = parent and parent:FindFirstChild(name, recursive)

        if newChild and child ~= newChild then
            setChild(newChild)
        end
    end, {
        parent,
        name
    } :: { any })

    useSignal(addEvent, function (added: Instance)
        if added.Name == name then
            setChild(added)
        end
    end, {
        parent,
        name
    } :: { any })

    return child
end

return useChild