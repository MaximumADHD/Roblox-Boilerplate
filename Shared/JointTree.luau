-- JointTree
-- ContextLost
-- April 25th, 2020

--!strict

local JointTree = {}
JointTree.__index = JointTree

type Edge = {
    Part: BasePart,
    Joint: JointInstance,
}

type Edges = {
    [number]: Edge,
}

type Joints = {
    [BasePart]: Edges
}

type CFrames = {
    [BasePart]: CFrame,
}

--------------------------------------------------------------------------------------------------------------------------------------------------------
-- Tree Generation
--------------------------------------------------------------------------------------------------------------------------------------------------------

local function addJointEdge(joints: Joints, joint: JointInstance)
    local part0 = joint.Part0
    local part1 = joint.Part1

    if part0 and part1 then
        if not joints[part0] then
            joints[part0] = {}
        end

        if not joints[part1] then
            joints[part1] = {}
        end

        table.insert(joints[part0], {
            Joint = joint,
            Part = part1,
        })

        table.insert(joints[part1], {
            Joint = joint,
            Part = part0,
        })
    end
end

local function expandTree(joints: Joints, part0: BasePart, maybeEdges: Edges?): Edges
    local adjacent = joints[part0]
    local edges: Edges = maybeEdges or {}

    if adjacent then
        -- We only want to iterate over part's edges once, remove edges to mark as visited
        joints[part0] = nil

        for i, edge in adjacent do
            local part1 = edge.Part

            -- Checks if we've already included this part. This will at least be a list with edge back
            -- to parent unless we've already visited this part through another joint and removed it.
            -- Breaks cycles and prioritizes shortest path to root.

            if joints[part1] then
                -- Add the parent-child joint edge to the tree list
                table.insert(edges, edge)

                -- Recursively add child's edges, DFS order. BFS would
                -- have been fine too, but either works just as well.
                expandTree(joints, part1, edges)
            end
        end
    end

    return edges
end

--[[
     Returns a list of assembly edges in some tree-sorted order that can be used by `applyTree` to
     position other parts in `model` relative to `rootPart` if they would be in the same Assembly
     under a `WorldRoot`. This roughly imitates what the internal spanning tree that `WorldRoot` uses
     to build an internal transform hierarchy of parts in an assembly, with some limitations:
    
     - Only supports Motor6D, and Weld. Didn't bother with legacy Motor, Snap, ManualWeld.
     - Doesn't support Motor/Motor6D.CurrentAngle and co.
     - Doesn't support WeldConstraints. Can't. Transform isn't exposed to Lua.
     - Doesn't prioritize by joint type. Weld should take priority over Motor.
     - Doesn't prioritize by joint/part GUID. Can't. Not exposed to Lua.
    
     For a reasonable model, like an R15 character, that doesn't have duplicate or unsupported joints
     it should produce the same results as the Roblox spanning tree when applied.
    
     { { joint, childPart }, ... }
]]--

function JointTree.Build(model: Model, rootPart: BasePart?)
    local joints = {}

    -- Gather the part-joint graph.
    for i, desc in model:GetDescendants() do
        if desc:IsA("JointInstance") then
            local p0 = desc.Part0
            local p1 = desc.Part1

            if p0 and p1 then
                -- Add edge to both parts. Assembly joints are bidirectional.
                addJointEdge(joints, desc)
            end
        end
    end

    -- Build the tree, in order, by recursively following edges out from the root part
    -- Joint edge list map: { [part] = { { joint, otherPart }, ...}, ... }

    if not rootPart then
        rootPart = model.PrimaryPart
    end

    if not rootPart then
        local bestMass = 0
        local bestPart: BasePart?

        for part in joints do
            local mass = part.Mass

            if mass > bestMass then
                bestMass = mass
                bestPart = part
            end
        end

        rootPart = bestPart
    end

    -- Return the generated edges.
    assert(rootPart, "Model does not have any assembly root!")
    return expandTree(joints, rootPart)
end

--------------------------------------------------------------------------------------------------------------------------------------------------------
-- CFrame Index
--------------------------------------------------------------------------------------------------------------------------------------------------------

local CFrameMeta = {
    __index = function (_self, part: BasePart)
        return part.CFrame
    end,

    __newindex = function (_self, part: BasePart, cf: CFrame)
        part.CFrame = cf
    end,
}

local CFrameIndex = {} :: {
    [BasePart]: CFrame,
}

setmetatable(CFrameIndex :: any, CFrameMeta)

--------------------------------------------------------------------------------------------------------------------------------------------------------
-- Tree Solvers
--------------------------------------------------------------------------------------------------------------------------------------------------------

function JointTree.Solve(tree: { Edge }, index: CFrames?, ignoreTransform: boolean?)
    local cframes = index or CFrameIndex

    for i, edge in tree do
        local joint = edge.Joint
        local childPart = edge.Part

        local p0 = joint.Part0
        local p1 = joint.Part1

        if p0 and p1 then
            local c0 = joint.C0
            local c1 = joint.C1

            if joint:IsA("Motor6D") and not ignoreTransform then
                -- Motor6D, including Motor6D.Transform. Motor6D is now consistently P0->Transform->P1 after recent change.
                local transform = joint.Transform

                if p1 == childPart then
                    cframes[p1] = cframes[p0] * c0 * transform * c1:Inverse()
                else
                    cframes[p0] = cframes[p1] * c1 * transform:Inverse() * c0:Inverse()
                end
            else
                -- Weld
                if p1 == childPart then
                    cframes[p1] = cframes[p0] * c0 * c1:Inverse()
                else
                    cframes[p0] = cframes[p1] * c1 * c0:Inverse()
                end
            end
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------------------------------------

return JointTree