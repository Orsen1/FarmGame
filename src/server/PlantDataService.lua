local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))
local PlantService = require(ServerScriptService:WaitForChild("PlantService"))
local plants = ReplicatedStorage:WaitForChild("Plants")

local PlantDataService = {}

local function isPlantable(object)
    local itemName = object:GetAttribute("ItemName") or object.Name
    local definition = ItemDefinitions[itemName]

    return definition ~= nil and definition.Plantable == true
end

local function validateData(template, plant)
    if not isPlantable(template) then
        if plant ~= nil then
            return false, "Saved crop belongs to a non-plantable object"
        end
        return true
    end

    local plantingSpots = template:FindFirstChild("PlantingSpots")

    if not plantingSpots or not plantingSpots:IsA("Folder") then
        return false, "Missing PlantingSpots in " .. template.Name
    end

    local spots = plantingSpots:GetChildren()

    if #spots == 0 then
        return false, "No planting spots in " .. template.Name
    end

    for _, spot in ipairs(spots) do
        local plantPosition = spot:FindFirstChild("PlantPosition")

        if not plantPosition or not plantPosition:IsA("BasePart") then
            return false, "Missing PlantPosition in " .. spot.Name
        end
    end

    -- Пустая грядка тоже является корректным сохранением.
    if plant == nil then
        return true
    end

    if typeof(plant) ~= "table" or typeof(plant.Type) ~= "string" or typeof(plant.Stage) ~= "number" then
        return false, "Invalid saved crop data"
    end

    if plant.Stage < 0 or plant.Stage % 1 ~= 0 then
        return false, "Crop stage must be a non-negative integer"
    end

    local plantFolder = plants:FindFirstChild(plant.Type)
    local firstStage = plantFolder and plantFolder:FindFirstChild("Stage1")

    if not firstStage or not firstStage:IsA("Model") then
        return false, "Missing growth models for " .. plant.Type
    end

    return true
end

function PlantDataService.getData(object)
    if not isPlantable(object) or object:GetAttribute("Occupied") ~= true then
        return nil
    end

    return {
        Type = object:GetAttribute("PlantType"),
        Stage = object:GetAttribute("GrowthStage") or 0
    }
end

function PlantDataService.loadData(template, object, savedObject)
    local plant = savedObject.Plant
    local isValid, errorMessage = validateData(template, plant)

    if not isValid then
        return false, errorMessage
    end

    object:SetAttribute("Occupied", plant ~= nil)
    object:SetAttribute("PlantType", plant and plant.Type or "")
    object:SetAttribute("GrowthStage", plant and plant.Stage or 0)
    object:SetAttribute("ReadyToHarvest", false)

    if plant then
        task.spawn(PlantService.Grow, object, plant.Type, plant.Stage)
    end

    return true
end

return PlantDataService
