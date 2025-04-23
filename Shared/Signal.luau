-- Signal
-- MaximumADHD
-- November 29th, 2022

--!native
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages

local module = require(Packages.Signal)
export type Connection = module.Connection 
export type Typed<T...> = module.Signal<T...>
export type Generic = Typed<...any>

return module :: {
    new: <Args...>() -> Typed<Args...>,
    Is: (object: any) -> boolean,
    Wrap: <Args...>(signal: RBXScriptSignal<Args...>) -> Typed<Args...>,

    Typed: <T...>(T...) -> Typed<T...>,
    Generic: Typed<...any>,
    Empty: Typed<>,
}
