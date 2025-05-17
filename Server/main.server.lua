--!strict

local ServerStorage = game:GetService("ServerStorage")
local Shared = game.ReplicatedStorage.Shared
local RunContext = require(Shared.RunContext)

type Service = {
    Init: (Service) -> ()?,
    Start: (Service) -> ()?,
}

local Services = {} :: {
    [string]: Service
}

for _, desc in ServerStorage:GetDescendants() do
    if desc:IsA("ModuleScript") then
        local name = desc.Name

        if not name:match("Service$") then
            continue
        end

        local success, service = xpcall(require, function(err)
            error(`!! FATAL ERROR REQUIRING SERVICE {desc:GetFullName()}\n{err}\n{debug.traceback()}`)
        end, desc)

        if success then
            local init = service.Init
            local didInit = true

            if type(init) == "function" then
                didInit = xpcall(init, function (err)
                    error(`!! FATAL ERROR INITIALIZING SERVICE {desc:GetFullName()}\n{err}\n{debug.traceback()}`)
                end, service)
            end

            if didInit then
                Services[name] = service
            end
        end
    end
end

for name, service in pairs(Services) do
    local start = service.Start

    if type(start) == "function" then
        task.spawn(start, service)
    end
end

if RunContext.IsStudio then
    print("Server started!")
end

for i, child in Shared:GetChildren() do
    if child:IsA("ModuleScript") then
        task.spawn(xpcall, require, function(err)
            error(`!! FATAL ERROR LOADING SHARED MODULE {child:GetFullName()}\n{err}\n{debug.traceback()}`)
        end, child)
    end
end