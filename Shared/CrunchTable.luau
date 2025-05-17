-- CrunchTable lets you define compression schemes for simple tables to be sent by roblox
-- If a field in a table is not defined in the layout, it will be ignored and stay in the table
-- If a field in a table is not present, but is defined in the layout, it'll default to 0 (or equiv)

--!native
--!strict

local module = {}

local Shared = script.Parent
local Guid = require(Shared.Guid)
local BitUtils = require(Shared.BitUtils)

export type LazyTable = {
    [string]: any 
}

export type BinaryTable = {
    _b: buffer,
    [string]: any,
}

module.Enum = table.freeze({
    IGNORE = 0,

    BOOL = 1,
    BOOLEAN = 1,

    UINT8 = 2,
    BYTE = 2,
    
    INT8 = 3,
    SBYTE = 3,

    UINT16 = 4,
    USHORT = 4,
    
    INT16 = 5,
    SHORT = 5,

    UINT32 = 6,
    UINT = 6,

    INT32 = 7,
    INT = 7,

    FLOAT16 = 8,
    HALF = 8,

    FLOAT32 = 9,
    SINGLE = 9,
    FLOAT = 9,

    FLOAT64 = 10,
    DOUBLE = 10,

    INT53 = 11,
    UINT53 = 12,

    Vector2 = 13,
    Vector3 = 14,
    NumberRange = 15,
    
    STRING8 = 16,
    STRING16 = 17,
    STRING24 = 18,
    STRING32 = 19,
    STRING64 = 20,
    GUID = 21,
})

local building = {} :: {
    [Layout]: boolean
}

local meta = {} :: {
    [number]: {
        Size: number,
        Default: any,
        Reader: (buffer, number) -> any,
        Writer: (buffer, number, any) -> (),
    }
}

local function stringIO(size: number)
    return {
        Size = size,
        Default = "",

        Reader = function(buf: buffer, offset: number): string
            local str = buffer.readstring(buf, offset, size)
            return str:gsub("\0", "")
        end,

        Writer = function(buf: buffer, offset: number, value: string)
            local buf = buffer.create(size)

            for i = 1, math.min(#value, size) do
                local char = value:sub(i, i)
                buffer.writeu8(buf, i - 1, char:byte())
            end
        end,
    }
end

meta[module.Enum.IGNORE] = table.freeze({
    Size = 0,
    Default = nil,
    Reader = function() end,
    Writer = function() end,
})

meta[module.Enum.BOOL] = table.freeze({
    Size = 1,
    Default = false,

    Reader = function(buf: buffer, offset: number): boolean
        return buffer.readu8(buf, offset) > 0
    end,

    Writer = function(buf: buffer, offset: number, value: boolean)
        buffer.writeu8(buf, offset, value and 1 or 0)
    end,
})

meta[module.Enum.UINT8] = table.freeze({
    Size = 1,
    Default = 0,
    Reader = buffer.readu8,
    Writer = buffer.writeu8,
})

meta[module.Enum.INT8] = table.freeze({
    Size = 1,
    Default = 0,
    Reader = buffer.readi8,
    Writer = buffer.writei8,
})

meta[module.Enum.UINT16] = table.freeze({
    Size = 2,
    Default = 0,
    Reader = buffer.readu16,
    Writer = buffer.writeu16,
})

meta[module.Enum.INT16] = table.freeze({
    Size = 2,
    Default = 0,
    Reader = buffer.readi16,
    Writer = buffer.writei16,
})

meta[module.Enum.UINT32] = table.freeze({
    Size = 4,
    Default = 0,
    Reader = buffer.readu32,
    Writer = buffer.writeu32,
})

meta[module.Enum.INT32] = {
    Size = 4,
    Default = 0,
    Reader = buffer.readi32,
    Writer = buffer.writei32,
}

meta[module.Enum.FLOAT16] = table.freeze({
    Size = 2,
    Default = 0,
    
    Reader = BitUtils.ReadFloat16,
    Writer = BitUtils.WriteFloat16,
})

meta[module.Enum.FLOAT32] = table.freeze({
    Size = 4,
    Default = 0,
    Reader = buffer.readf32,
    Writer = buffer.writef32,
})

meta[module.Enum.FLOAT64] = table.freeze({
    Size = 8,
    Default = 0,
    Reader = buffer.readf64,
    Writer = buffer.writef64,
})

meta[module.Enum.INT53] = table.freeze({
    Size = 8,
    Default = 0,

    Reader = function (buf: buffer, offset: number): number
        local lo = buffer.readu32(buf, offset)
        local hi = buffer.readi32(buf, offset + 4)
        return (hi * 2147483647) + lo
    end,

    Writer = function (buf: buffer, offset: number, value: number)
        local lo = value % 2147483647
        local hi = value // 2147483647

        buffer.writeu32(buf, offset, lo)
        buffer.writei32(buf, offset + 4, hi)
    end,
})

meta[module.Enum.UINT53] = table.freeze({
    Size = 8,
    Default = 0,

    Reader = function (buf: buffer, offset: number): number
        local lo = buffer.readu32(buf, offset)
        local hi = buffer.readu32(buf, offset + 4)
        return (hi * 4294967296) + lo
    end,

    Writer = function (buf: buffer, offset: number, value: number)
        local lo = value % 4294967296
        local hi = value // 4294967296

        buffer.writeu32(buf, offset, lo)
        buffer.writeu32(buf, offset + 4, hi)
    end,
})

meta[module.Enum.Vector2] = {
    Size = 8,
    Default = Vector2.zero,

    Reader = function(buf: buffer, offset: number): Vector2
        local x = buffer.readf32(buf, offset)
        local y = buffer.readf32(buf, offset + 4)
        return Vector2.new(x, y)
    end,

    Writer = function(buf: buffer, offset: number, value: Vector2)
        buffer.writef32(buf, offset, value.X)
        buffer.writef32(buf, offset + 4, value.Y)
    end,
}

meta[module.Enum.Vector3] = {
    Size = 12,
    Default = Vector3.zero,

    Reader = function(buf: buffer, offset: number): Vector3
        local x = buffer.readf32(buf, offset)
        local y = buffer.readf32(buf, offset + 4)
        local z = buffer.readf32(buf, offset + 8)

        return Vector3.new(x, y, z)
    end,

    Writer = function(buf: buffer, offset: number, value: Vector3)
        buffer.writef32(buf, offset, value.X)
        buffer.writef32(buf, offset + 4, value.Y)
        buffer.writef32(buf, offset + 8, value.Z)
    end,
}

meta[module.Enum.NumberRange] = {
    Size = 8,
    Default = NumberRange.new(0),

    Reader = function(buf: buffer, offset: number): NumberRange
        local min = buffer.readf32(buf, offset)
        local max = buffer.readf32(buf, offset + 4)
        return NumberRange.new(min, max)
    end,

    Writer = function(buf: buffer, offset: number, value: NumberRange)
        buffer.writef32(buf, offset, value.Min)
        buffer.writef32(buf, offset + 4, value.Max)
    end,
}

meta[module.Enum.GUID] = {
    Size = 16,
    Default = "00000000-0000-0000-0000-000000000000",

    Reader = Guid.Decompress,
    Writer = Guid.Compress,
}

meta[module.Enum.STRING8] = stringIO(8)
meta[module.Enum.STRING16] = stringIO(16)
meta[module.Enum.STRING24] = stringIO(24)
meta[module.Enum.STRING32] = stringIO(32)
meta[module.Enum.STRING64] = stringIO(64)

local Layout = {}
Layout.__index = Layout

type FieldInfo = {
    Required: boolean,
    Default: any,
    Name: string,
    Enum: number,
    Size: number,

    Read: (buffer, number) -> any,
    Write: (buffer, number, any) -> (),
}

-- stylua: ignore
export type Layout = typeof(setmetatable({} :: {
    _building: boolean?,

    FieldsByName: {
        [string]: FieldInfo,
    },

    Fields: {FieldInfo},
    FieldBytes: number,
    TotalBytes: number,

    ContentBytes: number,
    ContentReader: (buffer, number) -> number,
    ContentWriter: (buffer, number, number) -> (),
}, Layout))

local function calcSize(self: Layout)
    if building[self] then
        return
    end

    local fields = self.Fields
    local numFields = #fields

    local contentBytes
    local contentReader
    local contentWriter

    if numFields <= 8 then
        contentBytes = 1
        contentReader = buffer.readu8
        contentWriter = buffer.writeu8
    elseif numFields <= 16 then
        contentBytes = 2
        contentReader = buffer.readu16
        contentWriter = buffer.writeu16
    elseif numFields <= 32 then
        contentBytes = 4
        contentReader = buffer.readu32
        contentWriter = buffer.writeu32
    else
        error("!! FATAL: Exceeded limit of 32 fields in CrunchTable layout!")
    end

    local fieldBytes = 0
    self.ContentBytes = contentBytes
    self.ContentReader = contentReader
    self.ContentWriter = contentWriter
    
    for index, rec in self.Fields do
        fieldBytes += rec.Size
    end

    self.FieldBytes = fieldBytes
    self.TotalBytes = contentBytes + fieldBytes
end

--[=[
    Call this to optimize redundant calculations when adding fields to the layout.
    
    **IMPORTANT:** Make sure to call End() after you're done adding fields

    @param fieldsAreRequiredByDefault If `true`, all fields added will be marked as **required** unless marked otherwise. If `false`, all fields added will be marked as **optional** unless marked otherwise. Default: `true`.
    @return The `Layout` object.
]=]
function Layout.Begin(self: Layout, fieldsAreRequiredByDefault: boolean?): Layout
    if fieldsAreRequiredByDefault == nil then
        building[self] = true
    else
        building[self] = fieldsAreRequiredByDefault
    end

    return self
end

--[=[
    Finishes the layout and calculates its size.
]=]
function Layout.End(self: Layout)
    if building[self] ~= nil then
        building[self] = nil
        calcSize(self)
    end
end

function Layout.Add(self: Layout, field: string, enum: number, required: boolean?): Layout
    local fieldMeta = meta[enum]

    local isRequired = if required == nil
        then building[self]
        else required

    local fieldInfo = table.freeze({
        Required = isRequired,
        Default = fieldMeta.Default,
        Write = fieldMeta.Writer,
        Read = fieldMeta.Reader,
        Size = fieldMeta.Size,
        Name = field,
        Enum = enum,
    })

    self.FieldsByName[field] = fieldInfo
    table.insert(self.Fields, fieldInfo)

    calcSize(self)
    return self
end

function Layout.GetFieldInfo(self: Layout, field: string): FieldInfo?
    return self.FieldsByName[field]
end

function Layout.WriteToBuffer(self: Layout, srcData: LazyTable, buf: buffer, start: number?, onWrite: (key: string) -> ()?): number
    local write = self.ContentWriter
    local offset = (start or 0) + self.ContentBytes

    local contents = 0
    local bit = 1
    
    for index, rec in self.Fields do
        local key = rec.Name
        local srcValue = srcData[key]
        
        if srcValue ~= nil then
            rec.Write(buf, offset, srcValue)
            offset += rec.Size
            contents += bit

            if onWrite then
                onWrite(key)
            end
        end
        
        bit += bit
    end
    
    write(buf, start or 0, contents)
    return offset
end

function Layout.Compress(self: Layout, srcData: LazyTable): BinaryTable
    local packet = table.clone(srcData)

    -- Create buffer with max possible size.
    local work = buffer.create(self.TotalBytes)

    local size = self:WriteToBuffer(srcData, work, 0, function(key: string)
        packet[key] = nil
    end)

    -- Copy the buffer to a new one with the exact size.
    local b = buffer.create(size)
    buffer.copy(b, 0, work, 0, size)
    packet._b = b

    return packet
end

function Layout.ReadFromBuffer(self: Layout, buf: buffer, start: number, callback: (key: string, value: any) -> ()): number
    local reader = self.ContentReader
    local offset = start or 0

    local contentBits
    local bit = 1

    contentBits = reader(buf, offset)
    offset += self.ContentBytes

    for index, rec in self.Fields do
        if bit32.btest(contentBits, bit) then
            local value = rec.Read(buf, offset)
            callback(rec.Name, value)
            offset += rec.Size
        elseif rec.Required then
            callback(rec.Name, rec.Default)
        end

        bit += bit
    end

    return offset
end

function Layout.Decompress(self: Layout, packet: BinaryTable): LazyTable
    local buf = packet._b

    local data: LazyTable = table.clone(packet)
    data._b = nil

    self:ReadFromBuffer(buf, 0, function(key: string, value: any)
        data[key] = value
    end)

    return data
end

function Layout.Clone(self: Layout): Layout
    local newLayout = setmetatable({
        FieldsByName = table.clone(self.FieldsByName),
        Fields = table.clone(self.Fields),

        TotalBytes = self.TotalBytes,
        FieldBytes = self.FieldBytes,
        ContentBytes = self.ContentBytes,

        ContentReader = self.ContentReader,
        ContentWriter = self.ContentWriter,
    }, Layout)

    return newLayout
end

function module.new(lazyFields: { [string]: number }?): Layout
    local layout = setmetatable({
        FieldsByName = {},
        Fields = {},

        TotalBytes = 0,
        FieldBytes = 0,
        ContentBytes = 0,

        ContentReader = buffer.readu8,
        ContentWriter = buffer.writeu8,
    }, Layout)

    if lazyFields then
        -- Order needs to be deterministic so its constant across all clients.
        -- If the order shouldn't be alphabetical, use the Begin/End API directly.
        local keys = {}

        for key in lazyFields do
            table.insert(keys, key)
        end

        layout:Begin(false)
        table.sort(keys)

        for i, key in keys do
            local enum = lazyFields[key]
            layout:Add(key, enum)
        end

        layout:End()
    end

    return layout
end

return module
