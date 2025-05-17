local StringBuilder = {}
StringBuilder.__index = StringBuilder

export type Class = typeof(setmetatable({} :: {
    _stack: number,
    _lines: { string },
}, StringBuilder))

function StringBuilder.new(): Class
    return setmetatable({
        _stack = 0,
        _lines = {},
    }, StringBuilder)
end

function StringBuilder.WriteLine(self: Class, format: string?, ...: any)
    if not format then
        table.insert(self._lines, "")
        return
    end

    local argCount = select("#", ...)
    local stack = string.rep(" ", self._stack * 4)
    
    if argCount == 0 then
        table.insert(self._lines, `{stack}{format}`)
        return
    end

    local line = string.format(format, ...)

    if #line == 0 then
        table.insert(self._lines, "")
        return
    end
    
    table.insert(self._lines, `{stack}{line}`)
end

function StringBuilder.OpenStack(self: Class)
    self._stack += 1
end

function StringBuilder.CloseStack(self: Class)
    self._stack -= 1
end

function StringBuilder.GetContent(self: Class): string
    return table.concat(self._lines, "\n")
end

function StringBuilder.GetLineCount(self: Class): number
    return #self._lines
end

function StringBuilder.GetLine(self: Class, index: number): string
    return self._lines[index]
end

function StringBuilder.Clear(self: Class)
    self._stack = 0
    table.clear(self._lines)
end

return StringBuilder