local UI = script:FindFirstAncestor("UI")
local Common = UI.Common
local Hooks = UI.Hooks

local React = require(Common.React)
local useA11Y = require(Hooks.useA11Y)
local useTimer = require(Hooks.useTimer)

local NOISE_CROP = Vector2.new(256, 256)
local NOISE_SIZE = Vector2.new(1023, 577)

local NOISE_RANGE = NOISE_SIZE - NOISE_CROP
local NOISE_IMG = "rbxassetid://13928716599"

type Prop<T> = T | React.Binding<T>

export type Props = {
    Size: Prop<UDim2>?,
    Position: Prop<UDim2>?,
    AnchorPoint: Prop<Vector2>?,
    
    ImageColor3: Prop<Color3>?,
    ImageTransparency: Prop<number>?,
    OnStep: (ImageLabel) -> ()?,
}

local function Noise(props: Props)
    local noiseRef = React.useRef(nil :: ImageLabel?)
    local a11y = useA11Y()

    useTimer(a11y.ReducedMotion and 2 or 60, function ()
        local noise = noiseRef.current

        if noise then
            noise.ImageRectOffset = Vector2.new(
                math.random() * NOISE_RANGE.X,
                math.random() * NOISE_RANGE.Y
            )

            if props.OnStep then
                props.OnStep(noise)
            end
        end
    end, { props.OnStep })

    return React.createElement("ImageLabel", {
        Size = props.Size,
        Position = props.Position,
        AnchorPoint = props.AnchorPoint,
        ScaleType = Enum.ScaleType.Crop,
        BackgroundTransparency = 1,

        Image = NOISE_IMG,
        ImageRectSize = NOISE_CROP,
        ImageColor3 = props.ImageColor3,
        ImageTransparency = props.ImageTransparency,

        ref = noiseRef,
    })
end

return Noise