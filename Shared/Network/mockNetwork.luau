-- Edit-mode version of the Network module.
-- This dummies out the network calls so more modules can be used "safely" in edit mode.

local mockNetwork = {}
local DEBUG = false

local Shared = script.Parent.Parent
local Players = game:GetService("Players")

local StudioService = game:GetService("StudioService")
local localPlayer = Players.LocalPlayer

local Future = require(Shared.Future)
local Signal = require(Shared.Signal)

local function debugWarn(...)
    if DEBUG then
        warn(...)
    end
end

local MockEvent = {}
MockEvent.__index = MockEvent

function mockNetwork.Event<T...>(id, validator)
    local toServer = Signal.new()
    local toClient = Signal.new()

    local onClient
    local onServer

    return {
        Client = function (self)
            return {
                On = function (self, callback)
                    if onClient then
                        onClient:Disconnect()
                    end

                    onClient = toClient:Connect(callback)
                end,
                
                Fire = function (self, ...)
                    toServer:Fire(...)
                end,
            }
        end,

        Server = function (self)
            return {
                On = function (self, callback)
                    if onServer then
                        onServer:Disconnect()
                    end

                    onServer = toServer:Connect(callback)
                end,

                Fire = function (self, player, ...)
                    toClient:Fire(...)
                end,
                
                FireAll = function (self, ...)
                    toClient:Fire(...)
                end,

                FireAllExcept = function (self, player, ...)
                    debugWarn("mockNetwork Server FireAllExcept:", id, player, ...)
                end,
            }
        end,
    }
end

function mockNetwork.Function<T...>(id, inValidator, outValidator)
    local callback
    debugWarn("mockNetwork mounted function w/ identifier:", id)

    return {
        Id = id,

        SetCallback = function (self, new)
            callback = new
        end,

        Call = function (self, ...)
            return Future.Try(function (...)
                return callback(localPlayer or {
                    UserId = StudioService:GetUserId()
                }, ...)
            end, ...)
        end,
    }
end

return mockNetwork