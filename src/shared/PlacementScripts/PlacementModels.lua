local ReplicatedStorage = game:GetService("ReplicatedStorage")
local models = ReplicatedStorage:WaitForChild("PlaceableModels")
local configs = ReplicatedStorage:WaitForChild("Configs")

local ItemDefinitions = require(configs:WaitForChild("ItemDefinitions"))

local ConstructionDefinitions = require(configs:WaitForChild("ConstructionDefinitions"))

local PlacementModels = {}

function PlacementModels.getTemplate(itemName, constructionStage)
    if typeof(itemName) ~= "string" then
        return nil
    end

    local definition = ItemDefinitions[itemName]
    local modelName = definition and definition.ModelFolder or itemName
    local object = models:FindFirstChild(modelName)

    if not object then
        return nil
    end

    if definition and definition.BuildsInto then
        local construction = ConstructionDefinitions[itemName]

        if not construction or not construction.Stages or not object:IsA("Folder") then
            return nil
        end

        local stage = constructionStage

        if stage == nil then
            stage = 0
        end

        if typeof(stage) ~= "number" or stage % 1 ~= 0 or stage < 0 or stage >= #construction.Stages then
            return nil
        end

        local stageName = "Blueprint"

        if stage > 0 then
            stageName = construction.Stages[stage].Model
        end

        local template = stageName and object:FindFirstChild(stageName)

        if template and template:IsA("Model") then
            return template
        end

        return nil
    end

    if object:IsA("Model") then
        return object
    end

    if object:IsA("Folder") then
        local blueprint = object:FindFirstChild("Blueprint")

        if blueprint and blueprint:IsA("Model") then
            return blueprint
        end
    end

    return nil
end

return PlacementModels
