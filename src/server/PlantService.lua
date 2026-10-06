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

function PlantService.Grow(gardenBed, seedType)
	local plantPosition = gardenBed:WaitForChild("PlantPosition")
	local plantFolder = PlantsFolder:WaitForChild(seedType)
	local stages = getStages(plantFolder)

	for i, stageModel in ipairs(stages) do
		local oldPlant = plantPosition:FindFirstChildWhichIsA("Model")
		if oldPlant then
			oldPlant:Destroy()
		end

		local newStage = stageModel:Clone()
		newStage.Parent = plantPosition
		newStage:PivotTo(plantPosition.CFrame)

		gardenBed:SetAttribute("GrowthStage", i)

		if i < #stages then
			task.wait(1)
		end
	end

	gardenBed:SetAttribute("ReadyToHarvest", true)
end

function PlantService.Plant(player, gardenBed, seedType)
	
	if gardenBed:GetAttribute("Occupied") then
		return
	end
	
	local plantType = getPlantTypeFromSeed(seedType)
	
	local removed = InventoryService.RemoveItem(player, seedType, 1)
	if not removed then
		print("No seeds left:", seedType)
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
	local plantPosition = gardenBed:WaitForChild("PlantPosition")
	local plant = plantPosition:FindFirstChildWhichIsA("Model")
	local plantType = gardenBed:GetAttribute("PlantType")
	
	if not plantType or plantType == "" then
		print("No plant type found")
		return
	end

	
	local added = InventoryService.AddItem(player, plantType, 1)
	if not added then
		print("Failed to add item")
		return
	end
	
	if plant then
		plant:Destroy()
	end

	gardenBed:SetAttribute("Occupied", false)
	gardenBed:SetAttribute("PlantType", "")
	gardenBed:SetAttribute("GrowthStage", 0)
	gardenBed:SetAttribute("ReadyToHarvest", false)
	
end

return PlantService