--!strict
local StoryBuilder = {}
local Common = script.Parent
local Cache = shared.StoryCache

local React = require(Common.React)
local ReactRoblox = require(Common.ReactRoblox)
local RootState = require(Common.RootState)

if not Cache then
    Cache = {}
    shared.StoryCache = Cache
end

local Story = {}
Story.__index = Story

type LazyTable = {
    [string]: any,
}

type StoryBind = {
    Binding: React.Binding<any>,
    SetValue: (any) -> (),
}

export type Class = typeof(setmetatable({} :: {
    Props: any,

    Callbacks: {
        [string]: () -> any,
    },

    Bindings: {
        [string]: StoryBind
    },

    Name: string,
    Story: any,
    Root: any,
}, Story))

local requireUnsafe: (ModuleScript) -> any = require

local function assertStoryBind(value: any): StoryBind
    assert(type(value) == "table", "Expected table for binding value")
    assert(type(value.Binding) == "table", "Expected table for binding value")
    assert(type(value.SetValue) == "function", "Expected function for binding setter")
    return value :: StoryBind
end

local function findStoryRoot(target: Instance)
    local root = target:FindFirstChild("StoryRoot")
    if root and root:IsA("ModuleScript") then
        return requireUnsafe(root)
    end

    local parent = target.Parent
    root = parent and parent:FindFirstChild("StoryRoot")
    if root and root:IsA("ModuleScript") then
        return requireUnsafe(root)
    end

    return nil
end

function Story.AddCallback(self: Class, key: string, callback: (any) -> ())
    self.Callbacks[key] = callback
end

function Story.__call(self: Class, target: Instance)
    local name = self.Name
    local story = self.Story

    local props = self.Props
    local storyRoot = self.Root
    local root = ReactRoblox.createRoot(target)

    local restore = Cache[name] or {}
    local listeners = {}

    local function update()
        local props = target:GetAttributes()
        Cache[name] = table.clone(props)

        for key, callback in self.Callbacks do
            props[key] = callback()
        end

        for key, data in self.Bindings do
            local value = props[key]
            local current = data.Binding:getValue()

            if value ~= current then
                data.SetValue(value)
            end

            props[key] = data.Binding
        end

        local element
        local rootElement
        local rootRef = React.createRef()

        if storyRoot then
            element = React.createElement(storyRoot, {}, {
                Story = React.createElement(story, props)
            })
        else
            element = React.createElement(story, props)
        end

        rootElement = React.createElement("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            ref = rootRef,
        }, {
            React.createElement(RootState.Driver, {
                Root = rootRef,
            }, element)
        })

        root:render(rootElement)
    end

    for key, value in pairs(props) do
        local success, conn = pcall(function(...)
            local listener = target:GetAttributeChangedSignal(key)
            local saved = restore[key]

            if saved ~= nil then
                value = saved
            end

            if type(value) == "table" then
                local sb = assertStoryBind(value)

                if saved ~= nil then
                    sb.SetValue(saved)
                else
                    value = sb.Binding:getValue()
                end
            end

            target:SetAttribute(key, value)
            return listener:Connect(update)
        end)

        if success then
            table.insert(listeners, conn)
        end
    end

    update()

    return function()
        for _, listener in ipairs(listeners) do
            listener:Disconnect()
        end
        root:unmount()
    end
end

function StoryBuilder.Create(target: ModuleScript, maybeProps: LazyTable?): Class
    local bindings = {}
    local callbacks = {}

    local root = findStoryRoot(target)
    local props = maybeProps or {} :: LazyTable

    for key, prop in pairs(props) do
        if type(prop) == "function" then
            callbacks[key] = prop
            props[key] = nil
        elseif type(prop) == "table" then
            bindings[key] = assertStoryBind(prop)
        end
    end

    return setmetatable({
        Name = target:GetFullName(),
        Story = requireUnsafe(target),
        Callbacks = callbacks,
        Bindings = bindings,
        Props = props,
        Root = root,
    }, Story)
end

function StoryBuilder.Binding(initialValue: any)
    local binding, setValue = React.createBinding(initialValue)
    return {
        Binding = binding,
        SetValue = setValue,
    }
end

function StoryBuilder.BindAll(props: LazyTable): LazyTable
    local bindings = {}

    for key, value in pairs(props) do
        bindings[key] = StoryBuilder.Binding(value)
    end
    
    return bindings
end

function StoryBuilder.Custom<P>(story: React.FC<P>, props: P?): Class
    local name = debug.info(2, "s")
    return setmetatable({
        Name = name,
        Story = story,
        Bindings = {},
        Callbacks = {},
        Props = props or {},
    }, Story)
end

return StoryBuilder