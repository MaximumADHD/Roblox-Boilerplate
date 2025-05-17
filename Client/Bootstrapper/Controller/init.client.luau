local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Bootstrapper = ReplicatedFirst:WaitForChild("Bootstrapper")

local controller: Instance = script.Parent
assert(controller and controller:IsA("ModuleScript"))

local success, module = xpcall(require, function(err)
    error(`!! FATAL ERROR REQUIRING CONTROLLER {controller:GetFullName()}\n{err}\n{debug.traceback()}`)
end, controller)

task.defer(function ()
    script.Parent = Bootstrapper :: any
end)

if success and module then
    local init = module.Init
    local didInit = true

    if type(init) == "function" then
        didInit = xpcall(init, function (err)
            error(`!! FATAL ERROR INITIALIZING CONTROLLER {controller:GetFullName()}\n{err}\n{debug.traceback()}`)
        end, module)
    end

    script.Name = controller.Name

    if didInit then
        local start = module.Start
        
        local starter = ReplicatedFirst:WaitForChild("StartEvent")
        assert(starter and starter:IsA("BindableEvent"))

        if not starter:HasTag("Started") then
            starter.Event:Wait()
        end

        if type(start) == "function" then
            task.spawn(start, module)
        end
    end
end