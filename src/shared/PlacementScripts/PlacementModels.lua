local ReplicatedStorage = game:GetService("ReplicatedStorage")
local models = ReplicatedStorage:WaitForChild("PlaceableModels")
local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))

local PlacementModels = {}

function PlacementModels.getTemplate(itemName)
    if typeof(itemName) ~= "string" then
        return nil
    end

    local definition = ItemDefinitions[itemName]
    local modelName = definition and definition.ModelFolder or itemName

    local object = models:FindFirstChild(modelName)

    if not object then
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
