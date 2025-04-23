local UI = script.Parent
local Common = UI.Common
local Widgets = UI.Widgets

local React = require(Common.React)
local ReactRoblox = require(Common.ReactRoblox)

local mounts = Instance.new("Folder")
mounts.Name = "Mounts"
mounts.Parent = UI

for i, module in Widgets:GetChildren() do
    if module:IsA("ModuleScript") then
        local success, widget = pcall(require, module)

        if success and type(widget) == "function" then
            local container = Instance.new("Folder")
            container.Name = module.Name
            container.Parent = mounts

            local mount = ReactRoblox.createRoot(container)
            mount:render(React.createElement(widget))
        end
    end
end