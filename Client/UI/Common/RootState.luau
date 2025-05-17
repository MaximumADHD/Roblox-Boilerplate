local Common = script.Parent
local React = require(Common.React)

local Context = React.createContext({} :: {
    BasePlayerGui: BasePlayerGui?,
    Root: { current: GuiBase2d },

    DisplayOrder: number,
    SetDisplayOrder: (number) -> (),

    ScreenInsets: Enum.ScreenInsets,
    SetScreenInsets: (Enum.ScreenInsets) -> (),

    IgnoreGuiInset: boolean,
    SetIgnoreGuiInset: (boolean) -> (),

    SafeAreaCompatibility: Enum.SafeAreaCompatibility,
    SetSafeAreaCompatibility: (Enum.SafeAreaCompatibility) -> (),

    ClipToDeviceSafeArea: boolean,
    SetClipToDeviceSafeArea: (boolean) -> (),
})

type Props = {
    Root: { current: GuiBase2d? },
    children: any?
}

local function Driver(props: Props)
    local rootRef = props.Root
    local screenGui: ScreenGui?, setScreenGui = React.useState(nil :: ScreenGui?)
    local basePlayerGui: BasePlayerGui?, setBasePlayerGui = React.useState(nil :: BasePlayerGui?)

    local displayOrder, setDisplayOrder = React.useState(0)
    local ignoreGuiInset, setIgnoreGuiInset = React.useState(true)
    local clipToDeviceSafeArea, setClipToDeviceSafeArea = React.useState(false)
    local screenInsets, setScreenInsets = React.useState(Enum.ScreenInsets.DeviceSafeInsets)
    local safeAreaCompatibility, setSafeAreaCompatibility = React.useState(Enum.SafeAreaCompatibility.FullscreenExtension)

    React.useEffect(function ()
        local root = rootRef.current

        if not root then
            return
        end

        if root:IsA("ScreenGui") then
            setScreenGui(root)
        end

        local function update()
            local newBase = root:FindFirstAncestorWhichIsA("BasePlayerGui")

            if basePlayerGui ~= newBase then
                setBasePlayerGui(newBase)
            end
        end

        local conn = root.AncestryChanged:Connect(update)
        update()

        return function ()
            conn:Disconnect()
        end
    end)

    React.useEffect(function ()
        if screenGui then
            screenGui.DisplayOrder = displayOrder
        end
    end, {
        screenGui,
        displayOrder,
    } :: { any })

    React.useEffect(function ()
        if screenGui then
            screenGui.IgnoreGuiInset = ignoreGuiInset
        end
    end, {
        screenGui,
        ignoreGuiInset,
    } :: { any })

    React.useEffect(function ()
        if screenGui then
            screenGui.ClipToDeviceSafeArea = clipToDeviceSafeArea
        end
    end, {
        screenGui,
        clipToDeviceSafeArea,
    } :: { any })

    React.useEffect(function ()
        if screenGui then
            screenGui.SafeAreaCompatibility = safeAreaCompatibility
        end
    end, {
        screenGui,
        safeAreaCompatibility,
    } :: { any })

    React.useEffect(function ()
        if screenGui then
            screenGui.ScreenInsets = screenInsets
        end
    end, {
        screenGui,
        screenInsets,
    } :: { any })

    return React.createElement(Context.Provider, {
        value = {
            BasePlayerGui = basePlayerGui,
            Root = rootRef,
            
            DisplayOrder = displayOrder,
            SetDisplayOrder = setDisplayOrder,

            ScreenInsets = screenInsets,
            SetScreenInsets = setScreenInsets,

            IgnoreGuiInset = ignoreGuiInset,
            SetIgnoreGuiInset = setIgnoreGuiInset,

            ClipToDeviceSafeArea = clipToDeviceSafeArea,
            SetClipToDeviceSafeArea = setClipToDeviceSafeArea,

            SafeAreaCompatibility = safeAreaCompatibility,
            SetSafeAreaCompatibility = setSafeAreaCompatibility,
        }
    }, props.children)
end

return table.freeze({
    Driver = Driver,
    Context = Context,
})