local ScriptEditorService = game:GetService("ScriptEditorService")
local Shared = game.ReplicatedStorage.Shared

local StringBuilder = require(Shared.StringBuilder)
local Settings = require(Shared.Settings)

local typeNames = table.freeze({
    "Bool",
    "Color",
    "Number",
    "String",
})

local enumTypes = table.freeze({
    {
        Name = "GetEnum",
        Impl = "GetEnumImpl<%s, %s>",
    },

    {
        Name = "SetEnum",
        Impl = "SetEnumImpl<%s, %s>",
    },

    {
        Name = "GetEnumSetting",
        Impl = "GetEnumSettingImpl<T, %s, %s>",
        Template = "<T>",
    },

    {
        Name = "GetEnumChangedSignal",
        Impl = "GetEnumChangedSignalImpl<%s, %s>",
    },
})

local function CompileSettings()
    local file = StringBuilder.new()
    file:WriteLine("-- AUTO GENERATED FILE!! DO NOT MANUALLY EDIT!!")
    file:WriteLine("-- Use the `Developer/CompileSettings` story to update this.")
    file:WriteLine()
    file:WriteLine("local EnumTypes = require(script.Parent.EnumTypes)")

    for i, data in ipairs(enumTypes) do
        local enumType = string.format(data.Impl, "Setting", "Options")
        file:WriteLine(`type {enumType} = EnumTypes.{enumType}`)
    end

    file:WriteLine()
    
    local settingsByType = {} :: {
        [string]: { 
            [string]: { string }
        }
    }

    local optionLists = {} :: {
        [string]: { string }
    }

    local optionNames = {} :: {
        [number]: string
    }

    local categories = Settings.GetData()
    local categoryNames = {}

    for categoryName in categories do
        table.insert(categoryNames, categoryName)
    end

    table.sort(categoryNames, function (a, b)
        return categories[a].Order < categories[b].Order
    end)

    for i, categoryName in ipairs(categoryNames) do
        local category = categories[categoryName]
        local settingList = category.Settings

        table.sort(settingList, function (a, b)
            return (a.Order or 0) < (b.Order or 0)
        end)

        for i, setting in ipairs(settingList) do
            local typeId: string = setting.Type
            local typeList = settingsByType[typeId]

            if not typeList then
                typeList = {}
                settingsByType[typeId] = typeList
            end

            local categoryList = typeList[categoryName]

            if not categoryList then
                categoryList = {}
                typeList[categoryName] = categoryList
            end

            table.insert(categoryList, setting.Name)

            if setting.Type == "String" then
                local metadata = setting.Metadata
                local options = metadata and metadata.Options

                if options then
                    optionLists[setting.Name] = options
                    table.insert(optionNames, setting.Name)
                end
            end
        end
    end

    table.sort(optionNames, function (a, b)
        if #a ~= #b then
            return #a < #b
        end

        return a < b
    end)

    for i, settingType in ipairs(typeNames) do
        local typeList = settingsByType[settingType]
        file:WriteLine(`export type {settingType}Name =`)
        file:OpenStack()

        if typeList then
            for i, categoryName in ipairs(categoryNames) do
                local categoryList = typeList[categoryName]

                if categoryList then
                    file:WriteLine(`-- {categoryName}`)

                    for i, settingName in ipairs(categoryList) do
                        file:WriteLine(`| "{settingName}"`)
                    end

                    file:WriteLine()
                end
            end
        else
            -- No names for this type yet...
            file:WriteLine(`| "__UNIMPLEMENTED (DO NOT USE YET)__"`)
            file:WriteLine()
        end

        file:CloseStack()
    end

    if next(optionLists) then
        local stringList = settingsByType.String
        file:WriteLine("-- Enums")

        for i, name in ipairs(optionNames) do
            local options = optionLists[name]
            file:WriteLine(`export type Enum{name} =`)
            file:OpenStack()

            for i, option in ipairs(options) do
                file:WriteLine(`| "{option}"`)
            end

            file:CloseStack()
            file:WriteLine()
        end

        for i, data in ipairs(enumTypes) do
            local typeName = `{data.Name}{data.Template or ""}`
            file:WriteLine(`-- {typeName}`)
            file:WriteLine(`export type {typeName} =`)
            file:OpenStack()

            for i, category in ipairs(categoryNames) do
                local categoryList = stringList[category]

                if not categoryList then
                    continue
                end

                file:WriteLine(`-- {category}`)

                for i, settingName in ipairs(categoryList) do
                    local options = optionLists[settingName]

                    if options then
                        file:WriteLine(`& {data.Impl}`, `"{settingName}"`, `Enum{settingName}`)
                    end
                end

                file:WriteLine()
            end

            file:CloseStack()
        end
    end

    file:WriteLine("export type SettingName =")
    file:OpenStack()

    for i, typeName in ipairs(typeNames) do
        file:WriteLine(`| {typeName}Name`)
    end

    file:CloseStack()
    file:WriteLine()

    file:WriteLine("return table.freeze({")
    file:OpenStack()

    file:WriteLine("Enums = table.freeze({")
    file:OpenStack()

    for i, name in ipairs(optionNames) do
        file:WriteLine(`{name} = newproxy() :: Enum{name},`)
    end

    file:CloseStack()
    file:WriteLine("})")

    file:CloseStack()
    file:WriteLine("})")

    local tempScript = Instance.new("Script")
    tempScript.Source = file:GetContent()
    tempScript.Parent = game

    local document do
        ScriptEditorService:OpenScriptDocumentAsync(tempScript)
        document = ScriptEditorService:FindScriptDocument(tempScript)
    end

    if document then
        local numLines = document:GetLineCount()
        local lastLine = document:GetLine(numLines)

        document.Destroying:Once(function ()
            tempScript:Destroy()
        end)

        document:ForceSetSelectionAsync(1, 1, numLines, #lastLine + 1)
    end

    return nil
end

return CompileSettings