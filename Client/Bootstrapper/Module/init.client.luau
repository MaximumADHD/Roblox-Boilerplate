local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Bootstrapper = ReplicatedFirst:WaitForChild("Bootstrapper")

local module = script.Parent
assert(module and module:IsA("ModuleScript"))

script.Name = `SHARED_{module.Name}`

task.defer(function ()
    script.Parent = Bootstrapper
end)

task.spawn(xpcall, require, function(err)
    error(`!! FATAL ERROR LOADING SHARED MODULE {module:GetFullName()}\n{err}\n{debug.traceback()}`)
end, module)