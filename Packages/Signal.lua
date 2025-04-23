local REQUIRED_MODULE = require(script.Parent._Index["sleitnick_signal@2.0.3"]["signal"])
export type Connection = REQUIRED_MODULE.Connection 
export type Signal<T...> = REQUIRED_MODULE.Signal<T...>
return REQUIRED_MODULE
