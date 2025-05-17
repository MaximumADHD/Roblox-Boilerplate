local function readf16(buf: buffer, offset: number): number
    local b0 = buffer.readu8(buf, offset)
    local b1 = buffer.readu8(buf, offset + 1)

    local sign = bit32.btest(b0, 128) and -1 or 1
    local exponent = bit32.rshift(bit32.band(b0, 127), 2)
    local mantissa = bit32.lshift(bit32.band(b0, 3), 8) + b1

    if exponent == 31 then --2^5-1
        if mantissa ~= 0 then
            return (0 / 0)
        else
            return math.huge * sign
        end
    elseif exponent == 0 then
        if mantissa == 0 then
            return 0
        else
            return math.ldexp(mantissa / 1024, -14) * sign
        end
    end

    return math.ldexp((mantissa / 1024) + 1, exponent - 15) * sign
end

local function writef16(buf: buffer, offset: number, value: number)
    local mantissa, exponent
    local sign = value < 0

    value = math.abs(value)
    mantissa, exponent = math.frexp(value)

    if value == math.huge then
        if sign then
            buffer.writeu8(buf, offset, 0b_11111100)
        else
            buffer.writeu8(buf, offset, 0b_01111100)
        end

        buffer.writeu8(buf, offset + 1, 0b_00000000)
    elseif value ~= value or value == 0 then
        buffer.writeu16(buf, offset, 0)
    elseif exponent + 15 <= 1 then -- Bias for halfs is 15
        mantissa = math.floor(mantissa * 1024 + 0.5)

        if sign then
            buffer.writeu8(buf, offset, (128 + bit32.rshift(mantissa, 8))) -- Sign bit, 5 empty bits, 2 from mantissa
        else
            buffer.writeu8(buf, offset, (bit32.rshift(mantissa, 8)))
        end

        buffer.writeu8(buf, offset + 1, bit32.band(mantissa, 255)) -- Get last 8 bits from mantissa
    else
        mantissa = ((mantissa - 0.5) * 2048 + 0.5) // 1

        -- The bias for halfs is 15, 15-1 is 14
        if sign then
            buffer.writeu8(buf, offset, (128 + bit32.lshift(exponent + 14, 2) + bit32.rshift(mantissa, 8)))
        else
            buffer.writeu8(buf, offset, (bit32.lshift(exponent + 14, 2) + bit32.rshift(mantissa, 8)))
        end

        buffer.writeu8(buf, offset + 1, bit32.band(mantissa, 255))
    end
end

local function readVarInt(buf: buffer, offset: number)
    local result = 0
    local shift = 0
    local byte

    repeat
        byte = buffer.readu8(buf, offset)
        result += bit32.lshift(bit32.band(byte, 127), shift)

        offset += 1
        shift += 7
    until bit32.btest(byte, 128)

    return result, offset
end

local function writeVarInt(buf: buffer, offset: number, value: number)
    repeat
        local byte = bit32.band(value, 127)
        value = bit32.rshift(value, 7)

        if value ~= 0 then
            byte = bit32.bor(byte, 128)
        end

        buffer.writeu8(buf, offset, byte)
        offset += 1
    until value == 0

    return offset
end

return table.freeze({
    ReadFloat16 = readf16,
    WriteFloat16 = writef16,

    ReadVarInt = readVarInt,
    WriteVarInt = writeVarInt,
})