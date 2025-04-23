--!strict

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local VRService = game:GetService("VRService")

local isEdit = false
local isServer = RunService:IsServer()
local isClient = RunService:IsClient()
local isStudio = RunService:IsStudio()

local isOnline = game.JobId ~= ""
local isRCC = isOnline and isServer

pcall(function ()
    isEdit = RunService:IsEdit()
end)

return table.freeze({
    IsRCC = isRCC,
    IsEdit = isEdit,

    IsTestRun = isStudio
        and not isEdit,

    IsServer = isServer,
    IsClient = isClient,
    IsStudio = isStudio,
    IsOnline = isOnline,

    IsTenFoot = GuiService:IsTenFootInterface(),
    IsTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
    IsVR = VRService.VREnabled,
})