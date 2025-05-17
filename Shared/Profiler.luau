local Profiler = {}

local Shared = script.Parent
local ConVar = require(Shared.ConVar)

local debug_profiler = ConVar.Declare("debug_profiler", false, ConVar.CHEAT, "Enables microprofiler labels.")
local active = false

debug_profiler:Connect(function()
    active = debug_profiler:GetBool()
end)

function Profiler.SetMemoryCategory(category: string)
    if active then
        debug.setmemorycategory(category)
    end
end

function Profiler.Begin(label: string)
    if active then
        debug.profilebegin(label)
    end
end

function Profiler.End()
    if active then
        debug.profileend()
    end
end

return table.freeze(Profiler)