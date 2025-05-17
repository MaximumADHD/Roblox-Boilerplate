local Shared = script.Parent.Parent

local Signal = require(Shared.Signal)
type Signal<T...> = Signal.Typed<T...>

export type GetEnumImpl<Setting, Options> = (
    setting: Setting,
    userId: number?
) -> Options

export type SetEnumImpl<Setting, Options> = (
    setting: Setting,
    value: Options,
    userId: number?
) -> ()

export type GetEnumSettingImpl<T, Setting, Options> = (
    self: T,
    setting: Setting,
    fallback: Options
) -> Options

export type GetEnumChangedSignalImpl<Setting, Options> = (
    setting: Setting,
    userId: number?
) -> Signal<Options>

export type useEnumSettingImpl<Setting, Options> = (
    setting: Setting
) -> Options

return {}