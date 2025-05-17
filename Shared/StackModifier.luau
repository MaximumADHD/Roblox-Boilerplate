-- StackModifier
-- MaximumADHD
-- March 21st, 2023

--!strict

--- A module for handling complex property stacking and modification.
--- It allows for multiple sources to modify the same property on an instance, with the ability to prioritize and weight each source.
--- Modifiers with higher priorities will override lower priority modifiers, and modifiers with the same priority will attempt to merge together based on their weight values.
local StackModifier = {}

local Shared = game.ReplicatedStorage.Shared
local RunContext = require(Shared.RunContext)
local AVLTree = require(Shared.AVLTree)
local Trove = require(Shared.Trove)
local Tags = require(Shared.Tags)

type AVLTree<T> = AVLTree.Class<T>

type PatchConfig = {
    Weight: number?,
    Priority: number?,
    Additive: boolean?,
}

type MixDef<T> = {
    Zero: T,
    Add: ((self: T, other: T) -> T)?,
    Scale: ((self: T, scale: number) -> T)?,
}

type Scalar = {
    Priority: number,

    Modifiers: {
        [string]: any
    }
}

type PropData = {
    Target: Instance,
    Prop: string,

    Default: any,
    MixDef: MixDef<any>?,

    Additives:{
        [string]: any
    },

    Scalars: AVLTree<Scalar>,
}

local dispatches = {} :: {
    [Instance]: thread,
}

local modifiers = {} :: {
    [Instance]: Trove.Class,
}

local mixable = {} :: {
    [string]: MixDef<any>,
}

local configs = {} :: {
    [string]: PatchConfig
}

local props = {} :: {
    [Instance]: PropData
}

local function lazyMixDef<T>(name: string, zero: T)
    mixable[name] = {
        Zero = zero,
    }
end

local function explicitMixDef<T>(name: string, def: MixDef<T>)
    mixable[name] = def
end

local function mix<T>(mixer: MixDef<T>, value: T, output: T, weight: number?): T
    if weight and weight ~= 1 then
        if mixer.Scale then
            value = mixer.Scale(value, weight)
        else
            value = (value :: any) * weight
        end
    end

    if mixer.Add then
        output = mixer.Add(output, value)
    else
        output = (output :: any) + value
    end

    return output
end

local function sortScalar(a: Scalar, b: Scalar): number
    return a.Priority - b.Priority
end

local function getPropData(propNode: Instance): PropData?
    local propData = props[propNode]

    if propData then
        return propData
    end

    local target = propNode.Parent

    if not target then
        return nil
    end

    local propName = propNode.Name:sub(#"⧉" + 1)
    local default = propNode:GetAttribute("Default")

    if default == nil then
        return nil
    end

    local valueType = typeof(default)
    local mixer = mixable[valueType]

    props[propNode] = {
        Target = target,
        Prop = propName,

        Default = default,
        MixDef = mixer,

        Additives = {},
        Scalars = AVLTree.new(sortScalar),
    }

    propNode.Destroying:Once(function ()
        props[propNode] = nil
    end)

    return props[propNode]
end

local function recompute(propNode: Instance)
    if dispatches[propNode] then
        return
    end

    local propData = getPropData(propNode)

    if not propData then
        return
    end

    dispatches[propNode] = task.defer(function ()
        local mixDef = propData.MixDef
        local target = propData.Target
        local default = propData.Default

        local scalars = propData.Scalars
        local scalarSet = scalars:Last()

        local additive = mixDef and mixDef.Zero
        local finalValue = mixDef and mixDef.Zero or default

        if mixDef then
            for key, value in propData.Additives do
                additive = mix(mixDef, value, additive)
            end
        end

        if scalarSet then
            for key, value in scalarSet.Modifiers do
                if mixDef then
                    finalValue = mix(mixDef, value, finalValue)
                else
                    finalValue = value
                end
            end
        else
            finalValue = default
        end

        if mixDef and additive ~= mixDef.Zero then
            finalValue = mix(mixDef, additive, finalValue)
        end

        local prop = propData.Prop;
        (target :: any)[prop] = finalValue

        if #propNode:GetChildren() == 0 then
            propNode:Destroy()
        end

        dispatches[propNode] = nil
    end)
end

local function onModifierAdded(node: Instance)
    local trove = Trove.new()
    local prop = node.Parent

    local key = node.Name
    local scalar

    local function update()
        if prop then
            local config = configs[key]

            if not config then
                return
            end

            local priority = config.Priority or 0
            local propData = getPropData(prop)

            if not propData then
                return
            end

            if modifiers[node] then
                local value = node:GetAttribute("Value")
                local scalars = propData.Scalars

                if config.Additive then
                    propData.Additives[key] = value
                else
                    local newScalar = scalar or {
                        Priority = priority,
                        Modifiers = {},
                    }
                    
                    local mixDef = propData.MixDef
                    local oldScalar = scalar or scalars:Find(newScalar)

                    -- Prescale the value if it's scalable.
                    if mixDef then
                        local weight = config.Weight
                        value = mix(mixDef, value, mixDef.Zero, weight)
                    end

                    if oldScalar then
                        oldScalar.Modifiers[key] = value
                    else
                        newScalar.Modifiers[key] = value
                        scalars:Insert(newScalar)
                        scalar = newScalar
                    end
                end
            elseif propData then
                if config.Additive then
                    propData.Additives[key] = nil
                elseif scalar then
                    scalar.Modifiers[key] = nil

                    if next(scalar.Modifiers) == nil then
                        propData.Scalars:Remove(scalar)
                    end
                end
            end

            recompute(prop)
        end
    end

    trove:Add(function ()
        modifiers[node] = nil
        update()
    end)

    trove:Connect(node.AncestryChanged, function ()
        if node.Parent then
            prop = node.Parent
            update()
        end
    end)

    local listener = node:GetAttributeChangedSignal("Value")
    trove:Connect(listener, update)

    modifiers[node] = trove
    update()
end

local function onModifierRemoved(node: Instance)
    local trove = modifiers[node]

    if trove then
        trove:Destroy()
    end
end

lazyMixDef("number", 0)
lazyMixDef("UDim", UDim.new())
lazyMixDef("UDim2", UDim2.new())
lazyMixDef("Vector2", Vector2.zero)
lazyMixDef("Vector3", Vector3.zero)

explicitMixDef("Color3", {
    Zero = Color3.new(),

    Add = function(self: Color3, other: Color3)
        return Color3.new(self.R + other.R, self.G + other.G, self.B + other.B)
    end,

    Scale = function(color: Color3, scale: number)
        return Color3.new(color.R * scale, color.G * scale, color.B * scale)
    end,
})

if RunContext.IsClient then
    Tags.Bind("StackModifier", onModifierAdded, onModifierRemoved)
end

----------------------------------------------------------------------------------------------------------------------------
-- API
----------------------------------------------------------------------------------------------------------------------------

local function getNode(name: string, parent: Instance, init: (node: Configuration) -> boolean): Configuration?
    local node = parent:FindFirstChild(name)

    if node and node:IsA("Configuration") then
        return node
    end

    local newNode = Instance.new("Configuration")
    newNode.Archivable = false
    newNode.Name = name

    if init(newNode) then
        newNode.Parent = parent
        return newNode
    end

    return nil
end

local function getPropNode(target: Instance, prop: string): Configuration?
    return getNode("⧉" .. prop, target, function(node)
        return xpcall(function()
            local value = (target :: any)[prop]
            node:SetAttribute("Default", value)
        end, function(err)
            warn("!! Invalid StackModifier:", target:GetFullName(), "->", prop, "caused by:\n", err)
            print(debug.traceback()) -- Ugliest print ever spams my studio
        end)
    end)
end

local function getModifierNode(object: Instance, prop: string, key: string): Configuration?
    local propNode = getPropNode(object, prop)

    if propNode then
        return getNode(key, propNode, function(keyNode)
            local default = propNode:GetAttribute("Default")

            if default ~= nil then
                keyNode:SetAttribute("Value", default)
                keyNode:AddTag("StackModifier")

                return true
            end

            return false
        end)
    end

    return nil
end

--- Registers a configuration for a stack modifier key. This is used to define the priority and weight of each property
--- that uses the stack modifier key, as well as whether the properties should be merged additively.
--- * `PatchConfig` is a table with the following fields:
---   * `Priority` (`number?` = `1`): The priority of each property using the modifier key.
---   * `Weight` (`number?` = `1`): Weight of each modifier when merging values of the same priority, if mergeable.
---   * `Additive` (`boolean?` = `false`): Whether each property should be merged additively to the overall stack.
--- @param key The unique id of the stack modifier key.
--- @param config The configuration for the stack modifier key.
--- @return `string` The unique id of the stack modifier key.
function StackModifier.Register(key: string, config: PatchConfig)
    configs[key] = config
    return key
end

--- Adds a stack modifier to the target instance with the provided string `modKey` indicating the configuration to use.
--- @param target `Instance` The target instance to add the stack modifier to.
--- @param key `string` The unique id of the stack modifier to add.
--- @param props `{ [string]: any }` The properties to add to the stack modifier.
function StackModifier.Patch(target: Instance, modKey: string, props: { [string]: any })
    local config = configs[modKey]
    assert(config, "Unknown StackModifier key: " .. modKey)

    for prop, value in props do
        local modifier = getModifierNode(target, prop, modKey)

        if modifier then
            local current = modifier:GetAttribute("Value")

            if typeof(current) == typeof(value) then
                modifier:SetAttribute("Value", value)
            end
        end
    end
end

--- Removes all stack modifiers with the provided string `modKey` from the target instance.
--- @param target The target instance to remove the stack modifiers from.
--- @param modKey The unique id of the stack modifier to remove.
function StackModifier.Clear(target: Instance, modKey: string)
    for _, desc in target:GetDescendants() do
        if desc.Name ~= modKey then
            continue
        end

        if desc:HasTag("StackModifier") then
            desc:Destroy()
        end
    end
end

return StackModifier
