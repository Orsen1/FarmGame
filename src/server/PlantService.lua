local PlantService = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlantsFolder = ReplicatedStorage:WaitForChild("Plants")
local ServerScriptService = game:GetService("ServerScriptService")
local InventoryService = require(ServerScriptService:WaitForChild("InventoryService"))

local function getPlantTypeFromSeed(seedType)
    return seedType:gsub("Seed", "")
end

local function getStages(plantFolder)
    local stages = {}

    for _, child in ipairs(plantFolder:GetChildren()) do
        if child:IsA("Model") and child.Name:match("^Stage%d+$") then
            table.insert(stages, child)
        end
    end

    table.sort(stages, function(a, b)
        return tonumber(a.Name:match("%d+")) < tonumber(b.Name:match("%d+"))
    end)

    return stages
end

function PlantService.Grow(gardenBed, plantType, startStage)
    local plantingSpots = gardenBed:WaitForChild("PlantingSpots")
    local spots = plantingSpots:GetChildren()

    local plantFolder = PlantsFolder:WaitForChild(plantType)
    local stages = getStages(plantFolder)
    startStage = math.clamp(startStage or 1, 1, #stages)

    for i = startStage, #stages do
        if not gardenBed:IsDescendantOf(workspace) or gardenBed:GetAttribute("Occupied") ~= true then
            return
        end

        for spotIndex = 1, #spots do
            local spot = spots[spotIndex]
            local plantPosition = spot:WaitForChild("PlantPosition")

            local oldPlant = plantPosition:FindFirstChildWhichIsA("Model")
            if oldPlant then
                oldPlant:Destroy()
            end

            local newStage = stages[i]:Clone()

            newStage:PivotTo(plantPosition.CFrame)
            newStage.Parent = plantPosition
        end

        gardenBed:SetAttribute("GrowthStage", i)
        gardenBed:SetAttribute("ReadyToHarvest", i == #stages)

        if i < #stages then
            task.wait(1)
        end
    end

    gardenBed:SetAttribute("ReadyToHarvest", true)
end

function PlantService.Plant(player, gardenBed, seedType)

    if player:GetAttribute("DataLoaded") ~= true or gardenBed:GetAttribute("OwnerUserId") ~= player.UserId then
        return
    end

    if gardenBed:GetAttribute("Occupied") then
        return
    end

    local plantType = getPlantTypeFromSeed(seedType)
    local plantingSpots = gardenBed:WaitForChild("PlantingSpots")
    local spots = plantingSpots:GetChildren()

    local removed = InventoryService.RemoveItem(player, seedType, #spots)
    if not removed then
        print("Not enough seeds:", seedType)
        return
    end

    gardenBed:SetAttribute("Occupied", true)
    gardenBed:SetAttribute("PlantType", plantType)
    gardenBed:SetAttribute("GrowthStage", 0)
    gardenBed:SetAttribute("ReadyToHarvest", false)

    task.spawn(function()
        PlantService.Grow(gardenBed, plantType)
    end)
end

function PlantService.Harvest(player, gardenBed)
    local plantingSpots = gardenBed:WaitForChild("PlantingSpots")
    local spots = plantingSpots:GetChildren()

    if player:GetAttribute("DataLoaded") ~= true or gardenBed:GetAttribute("OwnerUserId") ~= player.UserId then
        return
    end

    if not gardenBed:GetAttribute("ReadyToHarvest") then
        return
    end

    local plantType = gardenBed:GetAttribute("PlantType")

    if not plantType or plantType == "" then
        print("No plant type found")
        return
    end

    local added = InventoryService.AddItem(player, plantType, #spots)
    if not added then
        print("Failed to add item")
        return
    end

    for _, spot in ipairs(spots) do
        local plantPosition = spot:WaitForChild("PlantPosition")
        local plant = plantPosition:FindFirstChildWhichIsA("Model")
        if plant then
            plant:Destroy()
        end
    end

    gardenBed:SetAttribute("Occupied", false)
    gardenBed:SetAttribute("PlantType", "")
    gardenBed:SetAttribute("GrowthStage", 0)
    gardenBed:SetAttribute("ReadyToHarvest", false)
end

return PlantService
