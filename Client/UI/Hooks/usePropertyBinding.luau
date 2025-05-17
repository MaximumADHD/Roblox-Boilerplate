--!strict

local UI = script:FindFirstAncestor("UI")
local React = require(UI.Common.React)

local Shared = game.ReplicatedStorage.Shared
local Guid = require(Shared.Guid)

local useRef = React.useRef
local useState = React.useState

type Binding<T> = React.Binding<T>
local nullBinding = React.createBinding(nil)

type PropertyMemo = {
    Binding: Binding<any>,
    SetValue: (any) -> (),
}

type InstanceMemo = {
    [string]: PropertyMemo
}

local memos = {} :: {
    [Instance]: InstanceMemo
}

local function getInstanceMemo(inst: Instance)
    if not memos[inst] then
        memos[inst] = {}
        --print("alloc inst-prop memo", inst)

        inst.Destroying:Once(function ()
            --print("free inst-prop memo", inst)
            memos[inst] = nil
        end)
    end
    
    return memos[inst]
end

local function getPropertyMemo(inst: Instance, propName: string): PropertyMemo
    local instMemo = getInstanceMemo(inst)

    if instMemo[propName] then
        return instMemo[propName]
    end

    local listener = inst:GetPropertyChangedSignal(propName)
    local memo, setMemo = React.createBinding((inst :: any)[propName])

    local conn: RBXScriptConnection? = listener:Connect(function ()
        local newValue = (inst :: any)[propName]
        setMemo(newValue)
    end)

    inst.Destroying:Once(function ()
        if conn then
            conn:Disconnect()
            conn = nil
        end

        instMemo[propName] = nil
        --print("free prop memo", inst, propName)
    end)

    local propMemo = {
        Binding = memo,
        SetValue = setMemo,
    }
    
    instMemo[propName] = propMemo
    --print("alloc prop memo", inst, propName)

    return propMemo
end

--[=[
    Uses **one** property from an instance, indexed using the provided `read` function.
    The property is then watched for changes and the component will re-render when it changes.
    You may mutate the return value to your heart's content (i.e. turning a `number` into a `boolean`, etc.)

    * The `read` function **MUST** be a pure function. Do not mutate the instance or any other state. The proxy object is not the instance itself.
    * You must index **one property** of the `proxy` so the hook knows what to observe (via `GetPropertyChangeSignal`)
]=]--
local function usePropertyBinding<Inst, T>(inst: Inst, read: (proxy: Inst) -> T): Binding<T?>
    local rawPtr: any = inst
    local instPtr: Instance? = rawPtr

    local propRef = useRef("")
    local value, setValue = useState(nil :: T?)

    assert(instPtr == nil or typeof(instPtr) == "Instance", "useProperty must be called with an instance")

    if propRef.current == "" then
        local locked = false

        value = read(setmetatable({}, {
            __index = function (self, key: string): T
                assert(not locked, "useProperty can only read one property.")
                local value = nil

                if rawPtr ~= nil then
                    value = rawPtr[key]
                    assert(type(value) ~= "function", "useProperty cannot read functions.")
                    assert(typeof(value) ~= "RBXScriptSignal", "useProperty cannot read events.")
                end

                propRef.current = key
                locked = true

                return value
            end
        }) :: any)

        setValue(value)
    end

    local propName = propRef.current
    local propMemo = instPtr and getPropertyMemo(instPtr, propName)

    return propMemo and propMemo.Binding or nullBinding
end

return usePropertyBinding
