local Packages = game.ReplicatedStorage.Packages
local Shared = script.Parent

local RunContext = require(Shared.RunContext)
local Network: typeof(require(Packages.Red))

if RunContext.IsEdit then
    Network = require(script.mockNetwork) :: any
else
    Network = require(Packages.Red)
end

return Network
