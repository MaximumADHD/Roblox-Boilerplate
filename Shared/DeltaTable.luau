--!native
--!strict

local DeltaTable = {}

export type LazyTable = {
    [any]: any,
}

export type Patch = {
    Path: { string },
    Value: any,
}

export type Trace = {
    Path: { string },
    OnApply: (path: { string }, value: any) -> (),
}

local function Deep(tbl: any): any
    local tCopy = table.create(#tbl)
    setmetatable(tCopy, getmetatable(tbl))

    for k, v in pairs(tbl) do
        if type(v) == "table" then
            tCopy[k] = Deep(v)
        else
            tCopy[k] = v
        end
    end

    return tCopy
end

local function GetDeltaKey(key: any): any
    if type(key) == "number" then
        return `_#{key}`
    end

    return key
end

local function ParseDeltaKey(key: any): any
    if type(key) == "string" and key:sub(1, 2) == "_#" then
        return tonumber(key:sub(3))
    end

    return key
end

local function Apply(maybeTarget: LazyTable?, deltaTable: LazyTable, trace: Trace?)
    local target: LazyTable = maybeTarget or {}
    local deletions = deltaTable.__deletions

    for deltaKey in deltaTable do
        if deltaKey == "__deletions" then
            continue
        end
        
        local key = ParseDeltaKey(deltaKey)

        if trace then
            table.insert(trace.Path, tostring(key))
        end

        if type(deltaTable[deltaKey]) == "table" then
            target[key] = Apply(target[key], deltaTable[deltaKey], trace)
        else
            target[key] = deltaTable[deltaKey]

            if trace then
                trace.OnApply(trace.Path, deltaTable[deltaKey])
            end
        end

        if trace then
            table.remove(trace.Path)
        end
    end

    if deletions then
        for i, key in pairs(deletions) do
            target[key] = nil

            if trace then
                table.insert(trace.Path, key)
                trace.OnApply(trace.Path, nil)
                table.remove(trace.Path)
            end
        end
    end

    return target
end

DeltaTable.DeepCopy = Deep

-- Compares two tables, and produces a new table containing the differences
function DeltaTable.Create(oldTable: any, newTable: any, fuzzyEpsilon: number?): (any, number)
    if oldTable == nil then
        return Deep(newTable), 0
    end

    local deltaTable = {}
    local changes = 0

    for key, data in pairs(newTable) do
        local deltaKey = GetDeltaKey(key)

        if oldTable[key] == nil then
            changes += 1
            deltaTable[deltaKey] = data
        else
            if type(newTable[key]) == "table" then
                -- its a table, recurse
                local childTable, num = DeltaTable.Create(oldTable[key], newTable[key])

                if num > 0 then
                    changes += num
                    deltaTable[deltaKey] = childTable
                end
            else
                local old = oldTable[key]
                local new = newTable[key]

                if fuzzyEpsilon then
                    if type(old) == "number" and type(new) == "number" then
                        if math.abs(old - new) < fuzzyEpsilon then
                            continue
                        end
                    elseif type(old) == "vector" and type(new) == "vector" then
                        if vector.magnitude((new - old) :: any) < fuzzyEpsilon then
                            continue
                        end
                    end
                end

                if old ~= new then
                    changes += 1
                    deltaTable[deltaKey] = new
                end
            end
        end
    end

    -- Check for deletions
    local deletions = {}

    for key in pairs(oldTable) do
        if newTable[key] == nil then
            table.insert(deletions, key)
            changes += 1
        end
    end
    
    if next(deletions) then
        deltaTable.__deletions = deletions
    end

    return deltaTable, changes
end

--- Produces a new table that is the combination of a target, and a deltaTable produced by DeltaTable.Create
function DeltaTable.Apply(target: LazyTable?, deltaTable: LazyTable, onApply: (path: {string}, value: any) -> ()?): LazyTable
    local trace: Trace?

    if onApply then
        trace = {
            Path = {},
            OnApply = onApply,
        }
    end

    return Apply(target, deltaTable, trace)
end

return DeltaTable
