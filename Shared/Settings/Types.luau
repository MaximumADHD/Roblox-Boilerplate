-- AUTO GENERATED FILE!! DO NOT MANUALLY EDIT!!
-- Use the `Developer/CompileSettings` story to update this.

local EnumTypes = require(script.Parent.EnumTypes)
type GetEnumImpl<Setting, Options> = EnumTypes.GetEnumImpl<Setting, Options>
type SetEnumImpl<Setting, Options> = EnumTypes.SetEnumImpl<Setting, Options>
type GetEnumSettingImpl<T, Setting, Options> = EnumTypes.GetEnumSettingImpl<T, Setting, Options>
type GetEnumChangedSignalImpl<Setting, Options> = EnumTypes.GetEnumChangedSignalImpl<Setting, Options>

export type BoolName =
    -- Example
    | "ExampleBoolean"

export type ColorName =
    | "__UNIMPLEMENTED (DO NOT USE YET)__"

export type NumberName =
    -- Example
    | "ExampleNumber"

export type StringName =
    -- Example
    | "ExampleString"
    | "ExampleEnum"

-- Enums
export type EnumExampleEnum =
    | "Option1"
    | "Option2"
    | "Option3"

-- GetEnum
export type GetEnum =
    -- Example
    & GetEnumImpl<"ExampleEnum", EnumExampleEnum>

-- SetEnum
export type SetEnum =
    -- Example
    & SetEnumImpl<"ExampleEnum", EnumExampleEnum>

-- GetEnumSetting<T>
export type GetEnumSetting<T> =
    -- Example
    & GetEnumSettingImpl<T, "ExampleEnum", EnumExampleEnum>

-- GetEnumChangedSignal
export type GetEnumChangedSignal =
    -- Example
    & GetEnumChangedSignalImpl<"ExampleEnum", EnumExampleEnum>

export type SettingName =
    | BoolName
    | ColorName
    | NumberName
    | StringName

return table.freeze({
    Enums = table.freeze({
        ExampleEnum = newproxy() :: EnumExampleEnum,
    })
})