local HttpService = game:GetService("HttpService")

local function create()
    return HttpService:GenerateGUID(false)
end

return table.freeze({
    Create = create
})