local Packages = game.ReplicatedStorage.Packages

local module = require(Packages.Future)
export type Class<T...> = module.Future<T...>

return module