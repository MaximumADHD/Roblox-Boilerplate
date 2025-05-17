--!native
--!strict

local System = {}

local Shared = script.Parent
local ConVar = require(Shared.ConVar)
local Network = require(Shared.Network)
local RunContext = require(Shared.RunContext)
local TextChatService = game:GetService("TextChatService")

local TextChannels = if not RunContext.IsEdit
    then TextChatService:WaitForChild("TextChannels")
    else nil

local RBXSystem = TextChannels and TextChannels:WaitForChild("RBXSystem")
local cmd_chat = ConVar.Declare("/chat", "{message}", ConVar.CHEAT, "Sends a chat message from the system.")

local chat = Network.Event("SystemChat", function (message: unknown)
    assert(type(message) == "string")
    return message :: string
end)

function System.Chat(message: string, recipient: Player?)
    if RunContext.IsServer then
        local server = chat:Server()

        if recipient then
            server:Fire(recipient, message)
        else
            server:FireAll(message)
        end

        return
    end

    if RBXSystem and RBXSystem:IsA("TextChannel") then
        RBXSystem:DisplaySystemMessage(message)
    end
end

ConVar.SuccessFeed:Connect(function (name, message)
    System.Chat(`<font color="#3fff3f">{message}</font>`)
end)

ConVar.ErrorFeed:Connect(function (name, message)
    System.Chat(`<font color="#ff3f3f">{message}</font>`)
end)

if RunContext.IsClient then
    local chatClient = chat:Client()
    chatClient:On(System.Chat)
else
    cmd_chat:Connect(function (message: string, player: Player?)
        System.Chat(message)
    end)
end

return System