--!strict

local Flags = {}
Flags.__index = Flags

export type Class = typeof(setmetatable({} :: {
    _value: number?,
    _inst: Instance?,
    _attr: string?
}, Flags))

function Flags.new(value: number?): Class
    return setmetatable({
        _value = value or 0
    }, Flags)
end

function Flags.GetString(value: number, flags: { [string]: number }): string
    local result = {}

    for name, flag in pairs(flags) do
        if bit32.btest(value, flag) then
            table.insert(result, name)
        end
    end

    return "[" .. table.concat(result, " | ") .. "]"
end

function Flags.fromAttribute(inst: Instance, name: string): Class
    local value = tonumber(inst:GetAttribute(name)) or 0

    return setmetatable({
        _value = value // 1,
        _inst = inst,
        _attr = name,
    }, Flags)
end

function Flags.Get(self: Class): number
    local inst, attr = self._inst, self._attr
    local value

    if inst and attr then
        value = tonumber(inst:GetAttribute(attr)) or 0
    else
        value = self._value or 0
    end

    return math.abs(value // 1)
end

function Flags.Set(self: Class, value: number)
    local inst, attr = self._inst, self._attr
    value = math.abs(value // 1)

    if inst and attr then
        inst:SetAttribute(attr, value // 1)
    else
        self._value = value // 1
    end
end

function Flags.Has(self: Class, flag: number): boolean
    local value = self:Get()
    return bit32.btest(value, flag)
end

function Flags.Add(self: Class, flag: number)
    local value = self:Get()
    self:Set(bit32.bor(value, flag))
end

function Flags.Remove(self: Class, flag: number)
    local value = self:Get()
    self:Set(bit32.band(value, bit32.bnot(flag)))
end

function Flags.Toggle(self: Class, flag: number)
    local value = self:Get()
    self:Set(bit32.bxor(value, flag))
end

return Flags