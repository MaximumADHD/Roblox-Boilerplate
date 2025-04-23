local UI = script:FindFirstAncestor("UI")
local React = require(UI.Common.React)

local Players = game:GetService("Players")
local Hooks = UI.Hooks

local useMotion = require(Hooks.useMotion)
local useSignal = require(Hooks.useSignal)
local useProperty = require(Hooks.useProperty)

export type Props = {
    Player: Player,
}

local myPlayer = Players.LocalPlayer
local USE_DEBUG_AUDIO = false

local testAudio = Instance.new("AudioPlayer")
testAudio.Asset = "rbxassetid://157518993"
testAudio.Looping = true
testAudio.Volume = 3

if USE_DEBUG_AUDIO then
    testAudio.Parent = script
    testAudio:Play()
end

local function usePlayers()
    local players, setPlayers = React.useState(Players:GetPlayers())

    useSignal(Players.PlayerAdded, function(player)
        setPlayers(Players:GetPlayers())
    end)

    useSignal(Players.PlayerRemoving, function(player)
        setPlayers(Players:GetPlayers())
    end)

    return players
end

local function SourceMic(props: Props)
    local player = props.Player
    local microphone: AudioDeviceInput?, setMicrophone = React.useState(player:FindFirstChildOfClass("AudioDeviceInput"))
    
    local analyzerRef = React.useRef(nil :: AudioAnalyzer?)
    local outputRef = React.useRef(nil :: AudioDeviceOutput?)
    local highPassRef = React.useRef(nil :: AudioFilter?)
    local lowPassRef = React.useRef(nil :: AudioFilter?)

    if USE_DEBUG_AUDIO then
        if microphone ~= testAudio :: any then
            setMicrophone(testAudio :: any)
        end
    else
        useSignal(player.ChildAdded, function (child)
            if child:IsA("AudioDeviceInput") then
                setMicrophone(child)
            end
        end, { player })

        useSignal(player.ChildRemoved, function (child)
            if child == microphone then
                setMicrophone(nil)
            end
        end, {
            player,
            microphone,
        } :: { any })
    end

    local character = useProperty(player, function (ref)
        return ref.Character
    end)

    local primary = useProperty(character, function (ref)
        return ref and ref.PrimaryPart
    end)
    
    local isActive = if USE_DEBUG_AUDIO then true else useProperty(microphone, function (ref)
        return ref and ref.Active
    end)

    local lastEnable, setLastEnable = React.useBinding(0)
    local peakLevel, setPeakLevel = React.useBinding(0)
    local fadeBind, fadeMotion = useMotion(1)

    React.useEffect(function (): (() -> ())?
        if not isActive then
            setPeakLevel(0)
            return nil
        end

        local analyzer = analyzerRef.current

        if not analyzer then
            return nil
        end

        local thread = task.spawn(function ()
            while task.wait(1 / 60) do
                local peak = analyzer.PeakLevel
                local current = peakLevel:getValue()

                if peak > 0.01 and current <= 0.01 then
                    setLastEnable((os.clock() * 60) // 1)
                    fadeMotion:immediate(0)
                elseif peak <= 0.01 and current > 0.01 then
                    fadeMotion:tween(2, {
                        style = Enum.EasingStyle.Linear,
                        delayTime = 1,
                    })
                end

                setPeakLevel(peak)
            end
        end)

        return function ()
            task.cancel(thread)
        end
    end, { isActive })

    return React.createElement("CanvasGroup", {
        Size = UDim2.fromScale(1, 1),

        BackgroundColor3 = peakLevel:map(function (value)
            return Color3.new(value, 0, 0)
        end),

        LayoutOrder = lastEnable,
        BackgroundTransparency = 0.2,
        GroupTransparency = fadeBind,

        Visible = fadeBind:map(function (value)
            return value < 1
        end)
    }, {
        List = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),

        Padding = React.createElement("UIPadding", {
            PaddingLeft = UDim.new(0, 4),
            PaddingRight = UDim.new(0, 4),
            PaddingTop = UDim.new(0, 4),
            PaddingBottom = UDim.new(0, 4),
        }),

        Avatar = React.createElement("ImageLabel", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.fromHex("444444"),
            SizeConstraint = Enum.SizeConstraint.RelativeYY,
            Image = `rbxthumb://type=AvatarHeadShot&w=150&h=150&id={player.UserId}`,
        }, {
            Corner = React.createElement("UICorner", {
                CornerRadius = UDim.new(0, 2),
            }),
        }),

        Name = React.createElement("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0.6),
            Text = player.DisplayName,
            TextColor3 = Color3.new(1, 1, 1),
            TextScaled = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            Font = Enum.Font.SourceSansSemibold,
        }, {
            Flex = React.createElement("UIFlexItem", {
                FlexMode = Enum.UIFlexMode.Fill,
            })
        }),

        Corner = React.createElement("UICorner", {
            CornerRadius = UDim.new(0, 4),
        }),

        Microphone = React.createElement("BillboardGui", {
            Brightness = 4,
            LightInfluence = 0,

            Enabled = peakLevel:map(function (level)
                return level > 0.01
            end),

            Adornee = primary or character,
            Size = UDim2.fromScale(2, 2),
            SizeOffset = Vector2.new(0.2, 0.5),
            StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0),  
        }, {
            Image = React.createElement("ImageLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                Image = "rbxassetid://132205751496494",
            }),
        }),

        HighPass = React.createElement("AudioFilter", {
            FilterType = Enum.AudioFilterType.Highpass48dB,
            Frequency = 100,
            Q = 0.1,

            ref = highPassRef,
        }, {
            Wire = React.createElement("Wire", {
                SourceInstance = microphone,
                TargetInstance = highPassRef,
            })
        }),

        LowPass = React.createElement("AudioFilter", {
            FilterType = Enum.AudioFilterType.Lowpass48dB,
            Frequency = 7000,
            Q = 0.2,

            ref = lowPassRef,
        }, {
            Wire = React.createElement("Wire", {
                SourceInstance = highPassRef,
                TargetInstance = lowPassRef,
            })
        }),

        Listener = React.createElement("AudioAnalyzer", {
            SpectrumEnabled = false,
            ref = analyzerRef,
        }, {
            Wire = React.createElement("Wire", {
                SourceInstance = lowPassRef,
                TargetInstance = analyzerRef,
            })
        }),

        Output = React.createElement("AudioDeviceOutput", {
            Player = myPlayer,
            ref = outputRef,
        }, {
            Wire = React.createElement("Wire", {
                SourceInstance = lowPassRef,
                TargetInstance = outputRef,
            })
        })
    })
end

local function SourceMics()
    local players = usePlayers()

    local nodes = {} :: {
        [string]: React.Node
    }

    for i, player in ipairs(players) do
        nodes[`${player.UserId}`] = React.createElement(SourceMic, {
            Player = player,
        })
    end

    return React.createElement("Frame", {
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(328, 54),
        Position = UDim2.new(1, -68, 1, -135),
        AnchorPoint = Vector2.xAxis,
        BackgroundTransparency = 1,
    }, {
        _list = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            VerticalAlignment = Enum.VerticalAlignment.Bottom,
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    }, nodes)
end

return SourceMics