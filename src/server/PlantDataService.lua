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

local function validBatches(batches, spots)
    if typeof(batches) ~= "table" or #batches < 1 or #batches > #spots then return false end
    local available = {}
    for _, spot in ipairs(spots) do available[spot.Name] = true end
    for index = 1, #batches do
        local batch = batches[index]
        if typeof(batch) ~= "table" or typeof(batch.Duration) ~= "number" or
            not (batch.Duration > 0 and batch.Duration <= 864000) or typeof(batch.Remaining) ~= "number" or
            not (batch.Remaining >= 0 and batch.Remaining <= batch.Duration) or typeof(batch.Watered) ~= "boolean" or
            typeof(batch.Slots) ~= "table" or #batch.Slots < 1 or #batch.Slots > #spots then return false end
        for i = 1, #batch.Slots do
            local slot = batch.Slots[i]
            if typeof(slot) ~= "table" or typeof(slot.Spot) ~= "string" or not available[slot.Spot] or
                typeof(slot.Yield) ~= "number" or slot.Yield % 1 ~= 0 or slot.Yield < 1 or slot.Yield > 20 then return false end
            available[slot.Spot] = nil
        end
    end
    return true
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

    if plant == nil then
        return true
    end

    if typeof(plant) ~= "table" or typeof(plant.Type) ~= "string" then
        return false, "Invalid saved crop data"
    end

    local plantFolder = plants:FindFirstChild(plant.Type)
    local firstStage = plantFolder and plantFolder:FindFirstChild("Stage1")

    if not firstStage or not firstStage:IsA("Model") then
        return false, "Missing growth models for " .. plant.Type
    end

    if plant.Version == 4 then return validBatches(plant.Batches, spots), "Invalid saved planting spots" end
    if typeof(plant.Stage) ~= "number" or plant.Stage < 0 or plant.Stage % 1 ~= 0 then
        return false, "Crop stage must be a non-negative integer"
    end

    if plant.Version ~= nil then
        local yields = plant.Version == 2 and plant.Fruits or plant.Yields
        if plant.Version ~= 2 and plant.Version ~= 3 or typeof(yields) ~= "table" or #yields ~= #spots or
            typeof(plant.Intervals) ~= "table" or #plant.Intervals < 1 or #plant.Intervals > 10 or
            typeof(plant.Segment) ~= "number" or plant.Segment % 1 ~= 0 or plant.Segment < 1 or
            plant.Segment > #plant.Intervals or typeof(plant.Remaining) ~= "number" or plant.Remaining ~= plant.Remaining or
            plant.Remaining < 0 or typeof(plant.NeedsWater) ~= "boolean" or typeof(plant.Ready) ~= "boolean" or
            (plant.Watered ~= nil and typeof(plant.Watered) ~= "boolean") then
            return false, "Invalid growth state"
        end
        for _, seconds in ipairs(plant.Intervals) do
            if typeof(seconds) ~= "number" or seconds <= 0 or seconds > 86400 then return false, "Invalid crop timing" end
        end
        if plant.Remaining > plant.Intervals[plant.Segment] or plant.NeedsWater and
            (plant.Segment == #plant.Intervals or plant.Remaining ~= 0) or plant.Ready and
            (plant.Segment ~= #plant.Intervals or plant.Remaining ~= 0 or plant.NeedsWater) then return false, "Invalid crop checkpoint" end
        for index = 1, #spots do
            local count = yields[index]
            if plant.Version == 2 then count = typeof(count) == "table" and #count end
            if typeof(count) ~= "number" or count % 1 ~= 0 or count < 1 or count > 20 then
                return false, "Invalid crop yield"
            end
        end
    end
    return true
end

function PlantDataService.getData(object)
    if not isPlantable(object) or object:GetAttribute("Occupied") ~= true then
        return nil
    end

    return PlantService.GetData(object)
end

function PlantDataService.loadData(template, object, savedObject)
    local plant = savedObject.Plant
    local isValid, errorMessage = validateData(template, plant)

    if not isValid then
        return false, errorMessage
    end

    if plant then return PlantService.Restore(object, plant) end
    object:SetAttribute("Occupied", false)
    object:SetAttribute("PlantType", "")
    object:SetAttribute("ReadyToHarvest", false)
    object:SetAttribute("PlantedCount", 0)
    object:SetAttribute("PlantingCapacity", #template.PlantingSpots:GetChildren())
    return true
end

return PlantDataService
