--!strict

while not game:IsLoaded() do
    game.Loaded:Wait()
end

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local HttpService = game:GetService("HttpService")

local Shared = game.ReplicatedStorage.Shared
local RunContext = require(Shared.RunContext)

local DEV_HOOK = false
local DEBUG_DEV = false

if RunContext.IsStudio or DEBUG_DEV then
    if DEV_HOOK then
        local devHook = {}
        devHook.isDisabled = false
        devHook.supportsFiber = true

        local lastCommits = {}
        local LIVE_LOG = false

        devHook.inject = function (myInternals: any)
            print(myInternals)
            return 0xDEADBEEF
        end

        devHook.onCommitFiberRoot = function (id, root, priorityLevel, didError)
            table.insert(lastCommits, 1, {
                Time = os.clock(),
                Data = root.current.updateQueue
            })
            
            while #lastCommits > 10 do
                table.remove(lastCommits)
            end

            if LIVE_LOG then
                print("commit", HttpService:JSONEncode(root.current.updateQueue))
            end
        end

        _G.__REACT_DEVTOOLS_GLOBAL_HOOK__ = devHook

        task.delay(2, function ()
            local ConVar = require(Shared.ConVar)
            local react_log = ConVar.Declare("/react_log", "", ConVar.CHEAT + ConVar.LOCAL, "Dumps recent react commits to the console.")
            local react_live_log = ConVar.Declare("react_live_log", false, ConVar.CHEAT + ConVar.LOCAL, "Dumps recent react commits to the console in real-time.")

            react_live_log:Connect(function ()
                LIVE_LOG = react_live_log:GetBool()
            end)

            react_log:HookCommand(function ()
                local HttpService = game:GetService("HttpService")
                print("now", os.clock())

                for i, commit in lastCommits do
                    print(i, HttpService:JSONEncode(commit))
                end

                return true
            end)
        end)
    end
    
    _G.__DEV__ = true
    _G.__EXPERIMENTAL__ = false
    _G.__PROFILE__ = false

    -- Level 1: Roots + Commit time
    -- Level 10: Individual Fiber "units of work"
    _G.__REACT_MICROPROFILER_LEVEL = 1
end

local controller = script.Controller
local module = script.Module

local startEvent = Instance.new("BindableEvent")
startEvent.Parent = ReplicatedFirst
startEvent.Name = "StartEvent"

for _, desc in ReplicatedFirst:GetDescendants() do
    if desc:IsA("ModuleScript") then
        local name = desc.Name

        if not name:match("Controller$") then
            continue
        end

        local boot: Script = controller:Clone()
        boot.Disabled = false
        boot.Parent = desc

        --[[
        local success, controller = xpcall(require, function(err)
            error(`!! FATAL ERROR REQUIRING CONTROLLER {desc:GetFullName()}\n{err}\n{debug.traceback()}`)
        end, desc)

        if success then
            local init = controller.Init
            local didInit = true

            if type(init) == "function" then
                didInit = xpcall(init, function (err)
                    error(`!! FATAL ERROR INITIALIZING CONTROLLER {desc:GetFullName()}\n{err}\n{debug.traceback()}`)
                end, controller)
            end

            if didInit then
                Controllers[name] = controller
            end
        end
        ]]--
    end
end

task.delay(0.1, function ()
    startEvent:Fire()
    startEvent:AddTag("Started")

    if RunContext.IsStudio then
        print("Client started!")
    end
    
    for i, child in Shared:GetChildren() do
        if child:IsA("ModuleScript") then
            local boot = module:Clone()
            boot.Parent = child :: any
            boot.Disabled = false
        end
    end
end)

controller:Destroy()
module:Destroy()
