--!strict

local UIController = {}
type Self = typeof(UIController)

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local player = assert(Players.LocalPlayer)
local playerGui = player:WaitForChild("PlayerGui")

local UI = ReplicatedFirst.UI
local Common = UI.Common

local React = require(Common.React)
local RootState = require(Common.RootState)
local ReactRoblox = require(Common.ReactRoblox)

local Shared = game.ReplicatedStorage.Shared
local RunContext = require(Shared.RunContext)

local function renderUI(name: string, fc: React.FC<any>)
    local dummy = Instance.new("Folder")
    local root = ReactRoblox.createRoot(dummy)
    local rootRef = React.createRef()
    
    local gui: React.Node = React.createElement("ScreenGui", {
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ref = rootRef,
    }, {
        _root = React.createElement(RootState.Driver, {
            Root = rootRef,
        }, {
            Widget = React.createElement(fc)
        })
    })

    local portal = ReactRoblox.createPortal({
        [name] = gui
    }, playerGui)

    root:render(portal)
end

function UIController.Init()
    while not game:IsLoaded() do
        task.wait(.1)
    end

    for i, mod in UI.Widgets:GetChildren() do
        if mod:IsA("ModuleScript") then
            local success, module

            if RunContext.IsStudio then
                success, module = xpcall(require, function (err)
                    warn("Error loading UI:", mod.Name, err, debug.traceback())
                end, mod)
            else
                -- Require directly in production so speed is not affected
                module = (require :: any)(mod)
                success = true
            end

            if success then
                if type(module) == "function" then
                    renderUI(mod.Name, module)
                elseif type(module) == "table" then
                    local render = module.Render
                    local mount = module.Mount

                    if type(render) == "function" then
                        renderUI(mod.Name, render)
                    elseif type(mount) == "function" then
                        local ui: LayerCollector = Instance.new("ScreenGui");
                        ui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                        ui.ResetOnSpawn = false
                        ui.Name = mod.Name

                        if ui:IsA("ScreenGui") then
                            ui.IgnoreGuiInset = true
                        end

                        local result = mount(ui)

                        if typeof(result) == "Instance" and result:IsA("LayerCollector") then
                            ui = result
                        end

                        ui.Parent = playerGui
                    else
                        local ui = mod:FindFirstChildWhichIsA("LayerCollector")

                        if ui then
                            ui.Name = mod.Name
                            ui.ResetOnSpawn = false
                            ui.Parent = playerGui
                        end
                    end
                end
            end
        end
    end
end

return UIController