local UI = script:FindFirstAncestor("UI")
local StoryBuilder = require(UI.Common.StoryBuilder)

local CompileSettings = require(script.Parent.CompileSettings)
return StoryBuilder.Custom(CompileSettings)