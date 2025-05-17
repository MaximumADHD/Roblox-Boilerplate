local Players = game:GetService("Players")
local Shared = script.Parent

local ConVar = require(Shared.ConVar)
export type IColor = Color3 | string
type ConVar = ConVar.Class

local Colors = {
    Black = Color3.fromHex("#000000"),
    White = Color3.fromHex("#ffffff"),

    Red = Color3.fromHex("#ff0000"),
    Green = Color3.fromHex("#00ff00"),
    Blue = Color3.fromHex("#0000ff"),

    Yellow = Color3.fromHex("#ffff00"),
    Cyan = Color3.fromHex("#00ffff"),
    Magenta = Color3.fromHex("#ff00ff"),

    Brick = table.freeze({
        Red = Color3.fromHex("#c4281c"),
        Orange = Color3.fromHex("#da8541"),
        Yellow = Color3.fromHex("#f5cd30"),
        Shrek = Color3.fromHex("#a4bd47"),
        Green = Color3.fromHex("#4b974b"),
        Blue = Color3.fromHex("#0d69ac"),
        Purple = Color3.fromHex("#6b327c"),
        White = Color3.fromHex("#f2f3f3"),
        Gray = Color3.fromHex("#a3a2a5"),
        Dark = Color3.fromHex("#635f62"),
        Black = Color3.fromHex("#1b2a35"),
        Pink = Color3.fromHex("#e8bac8"),
        Tan = Color3.fromHex("#d7c59a"),
    }),
}

Colors.ConVars = {
    BLOOD = ConVar.Declare("cl_blood_color", "#ff0000", ConVar.LOCAL, "Sets the color of blood effects.")
}

Colors.Gradient = table.freeze({
    Blue = ColorSequence.new(
        Color3.fromHex("#2CB9F7"),
        Color3.fromHex("#1441FF")
    ),
    Cyan = ColorSequence.new(
        Color3.fromHex("#3CEEFD"),
        Color3.fromHex("#29A4FF")
    ),
    Toothpaste = ColorSequence.new(
        Color3.fromHex("#3E3EFF"),
        Color3.fromHex("#0DFFAB")
    ),
    Green = ColorSequence.new(
        Color3.fromHex("#2CF77A"),
        Color3.fromHex("#10B274")
    ),
    LimeGreen = ColorSequence.new(
        Color3.fromHex("#39F791"),
        Color3.fromHex("#17FF79")
    ),
    Pink = ColorSequence.new(
        Color3.fromHex("#D341FF"),
        Color3.fromHex("#FF365D")
    ),
    Red = ColorSequence.new(
        Color3.fromHex("#F72C63"),
        Color3.fromHex("#D11440")
    ),
    Purple = ColorSequence.new(
        Color3.fromHex("#6514FF"),
        Color3.fromHex("#A12CF7")
    ),
    PurpleBurst = ColorSequence.new(
        Color3.fromHex("#8239F7"),
        Color3.fromHex("#2917FF")
    ),
    Yellow = ColorSequence.new(
        Color3.fromHex("#F7D02C"),
        Color3.fromHex("#FF7714")
    ),
    Orange = ColorSequence.new(
        Color3.fromHex("#F72C53"),
        Color3.fromHex("#FF7714")
    ),
    LightGrey = ColorSequence.new(
        Color3.fromHex("#e8e8e8"),
        Color3.fromHex("#cccccc")
    ),
    MediumGrey = ColorSequence.new(
        Color3.fromHex("#939393"),
        Color3.fromHex("#636363")
    ),
    Grey = ColorSequence.new(
        Color3.fromHex("#4d4d4d"),
        Color3.fromHex("#2d2d2d")
    ),
    DarkGrey = ColorSequence.new(
        Color3.fromHex("#3C3C3C"),
        Color3.fromHex("#1C1C1C")
    ),
    RedShade = ColorSequence.new(
        Color3.fromHex("#ff0000"),
        Color3.fromHex("#7f0000")
    ),
    GreenShade = ColorSequence.new(
        Color3.fromHex("#00ff00"),
        Color3.fromHex("#007f00")
    ),
    BlueShade = ColorSequence.new(
        Color3.fromHex("#0000ff"),
        Color3.fromHex("#00007f")
    ),
    PurpleShade = ColorSequence.new(
        Color3.fromHex("#ff00ff"),
        Color3.fromHex("#7f007f")
    ),
    MagentaShade = ColorSequence.new(
        Color3.fromHex("#ff00af"),
        Color3.fromHex("#7f005f")
    ),
    Admin = ColorSequence.new({
        ColorSequenceKeypoint.new(0 / 3, Color3.fromHex("#7F0000")),
        ColorSequenceKeypoint.new(2 / 3, Color3.fromHex("#FF00AF")),
        ColorSequenceKeypoint.new(3 / 3, Color3.fromHex("#7F0000")),
    }),
    Vintage = ColorSequence.new(
        Color3.fromHex("#5883ce"),
        Color3.fromHex("#2D3A4B")
    ),
    SelfMade = ColorSequence.new(
        Color3.fromHex("#70B04A"),
        Color3.fromHex("#4A7F2A")
    ),
})

Colors.TierColor = table.freeze({
    Default = Colors.Gradient.DarkGrey,
    Stock = Colors.Gradient.DarkGrey,
    Common = Colors.Gradient.DarkGrey,
    Uncommon = Colors.Gradient.Green,
    Rare = Colors.Gradient.Cyan,
    Epic = Colors.Gradient.Red,
    Legendary = Colors.Gradient.Orange,
    Mythic = Colors.Gradient.Purple,
    Exclusive = Colors.Gradient.Pink,
    Vintage = Colors.Gradient.Vintage,
    SelfMade = Colors.Gradient.SelfMade,
    Admin = Colors.Gradient.Admin,
})

Colors.Index8 = table.freeze({
    Colors.Brick.Red,
    Colors.Brick.Blue,
    Colors.Brick.Green,
    Colors.Brick.Purple,
    Colors.Brick.Orange,
    Colors.Brick.Yellow,
    Colors.Brick.Pink,
    Colors.Brick.Tan,
})

function Colors.fromIndex8(index: number)
    return Colors.Index8[1 + index % 8]
end

function Colors.fromName(rawName: string)
    local name = buffer.fromstring(rawName)
    local len = buffer.len(name)
    local value = 0

	for i = 1, len do 
		local byte = buffer.readu8(name, i - 1)
		local revIndex = len - i + 1

		if len % 2 == 1 then 
			revIndex -= 1			
		end

		if revIndex % 4 >= 2 then
            value -= byte
        else
            value += byte
		end
	end

    return Colors.fromIndex8(value)
end

function Colors.fromPlayer(player: Player)
    if player.Neutral then
        return Colors.fromName(player.Name)
    else
        return player.TeamColor.Color
    end
end

function Colors.fromUserId(userId: number)
    local player = Players:GetPlayerByUserId(userId)

    if player then
        return Colors.fromName(player.Name)
    else
        return Colors.fromIndex8(userId)
    end
end

function Colors.GetColorDelta(color: Color3, delta: number)
	local H, S, V = color:ToHSV()
	return Color3.fromHSV(math.abs(H), math.abs(S + (delta / 255)), math.abs(V))
end

function Colors.ResolveColor(color: IColor?): Color3
    if type(color) == "string" then
        if color:lower():match("#?%x%x%x%x%x%x") then
            return Color3.fromHex(color)
        elseif color:sub(1, 1) == "@" then
            local id = color:sub(2)
            local cvar = Colors.ConVars[id]

            if cvar then
                return cvar:GetColor3()
            end
        else
            local indexed = Colors[color]

            if typeof(indexed) == "Color3" then
                return indexed
            end
        end
    elseif typeof(color) == "Color3" then
        return color
    end

    return Colors.Black
end

function Colors.AvgLumOfSequence(color: ColorSequence)
    local keypoints = color.Keypoints
    local count = #keypoints
    local avg = 0

    for i, keypoint in keypoints do
        local color = keypoint.Value
        local r, g, b = color.R, color.G, color.B

        local luminance = 0.299 * r + 0.587 * g + 0.114 * b
        avg += (luminance / count)
    end

    return avg
end

return table.freeze(Colors)