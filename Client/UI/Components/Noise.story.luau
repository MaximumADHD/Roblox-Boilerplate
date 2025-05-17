local UI = script:FindFirstAncestor("UI")
local StoryBuilder = require(UI.Common.StoryBuilder)

return StoryBuilder.Create(script.Parent.Noise, {
    Size = UDim2.fromScale(1, 1),
    AnchorPoint = Vector2.one / 2,
    Position = UDim2.fromScale(0.5, 0.5),
    ImageColor3 = Color3.fromRGB(255, 255, 255),
    ImageTransparency = 0.5,
})