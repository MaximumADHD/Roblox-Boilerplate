local HttpService = game:GetService("HttpService")

local function create()
    return HttpService:GenerateGUID(false)
end

local function compress(buf: buffer, offset: number, value: string)
    local stream = value:gsub("-", "")

    local a = tonumber(stream:sub(1, 8), 16)
    buffer.writeu32(buf, offset, a or 0)

    local b = tonumber(stream:sub(9, 12), 16)
    buffer.writeu16(buf, offset + 4, b or 0)
    
    local c = tonumber(stream:sub(13, 16), 16)
    buffer.writeu16(buf, offset + 6, c or 0)

    local d = tonumber(stream:sub(17, 20), 16)
    buffer.writeu16(buf, offset + 8, d or 0)

    local e = tonumber(stream:sub(21, 24), 16)
    buffer.writeu16(buf, offset + 10, e or 0)

    local f = tonumber(stream:sub(25, 32), 16)
    buffer.writeu32(buf, offset + 12, f or 0)

    return offset + 16
end

local function decompress(buf: buffer, offset: number): string
    local a = buffer.readu32(buf, offset)

    local b = buffer.readu16(buf, offset + 4)
    local c = buffer.readu16(buf, offset + 6)
    local d = buffer.readu16(buf, offset + 8)

    local e = buffer.readu16(buf, offset + 10)
    local f = buffer.readu32(buf, offset + 12)

    return string.format("%08x-%04x-%04x-%04x-%04x%08x", a, b, c, d, e, f), offset + 16
end

return table.freeze({
    Create = create,
    Compress = compress,
    Decompress = decompress,
})