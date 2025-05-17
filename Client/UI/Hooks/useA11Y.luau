local Hooks = script.Parent
local useProperty = require(Hooks.useProperty)
local GuiService = game:GetService("GuiService")

--- shorthand for useAccessibility
local function useA11Y()
    return {
        ReducedMotion = useProperty(GuiService, function (rbx)
            return rbx.ReducedMotionEnabled
        end),

        Transparency = useProperty(GuiService, function (rbx)
            return rbx.PreferredTransparency
        end),

        TextSize = useProperty(GuiService, function (rbx)
            return rbx.PreferredTextSize
        end),
    }
end

return useA11Y