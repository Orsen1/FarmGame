local PlantService = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlantsFolder = ReplicatedStorage:WaitForChild("Plants")
local ServerScriptService = game:GetService("ServerScriptService")
local InventoryService = require(ServerScriptService:WaitForChild("InventoryService"))
local ItemDefinitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local plots = workspace:WaitForChild("Plots")

local function canUse(player, gardenBed)
    if typeof(gardenBed) ~= "Instance" or not gardenBed:IsA("Model") or
        player:GetAttribute("DataLoaded") ~= true then return false end
    local definition = ItemDefinitions[gardenBed:GetAttribute("ItemName") or gardenBed.Name]
    local plot = plots:FindFirstChild(player:GetAttribute("PlotName") or "")
    if not definition or not definition.Plantable or not plot or gardenBed.Parent ~= plot:FindFirstChild("PlacedObjects") or
        plot:GetAttribute("OwnerUserId") ~= player.UserId or gardenBed:GetAttribute("OwnerUserId") ~= player.UserId then return false end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local prompt = gardenBed:FindFirstChild("ActionPrompt", true)
    local attachment = prompt and prompt.Parent
    return root and humanoid and humanoid.Health > 0 and attachment and attachment:IsA("Attachment") and
        (root.Position - attachment.WorldPosition).Magnitude <= prompt.MaxActivationDistance
end

local function getPositions(gardenBed)
    local spots = gardenBed:FindFirstChild("PlantingSpots")
    if not spots or not spots:IsA("Folder") then return end
    local positions = {}
    for _, spot in ipairs(spots:GetChildren()) do
        local position = spot:FindFirstChild("PlantPosition")
        if not position or not position:IsA("BasePart") then return end
        table.insert(positions, position)
    end
    if #positions > 0 then return positions end
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
    local positions = getPositions(gardenBed)
    local plantFolder = PlantsFolder:FindFirstChild(plantType)
    local stages = plantFolder and getStages(plantFolder)
    if not positions or not stages or #stages == 0 then return end
    startStage = math.clamp(startStage or 1, 1, #stages)

    for i = startStage, #stages do
        if not gardenBed:IsDescendantOf(workspace) or gardenBed:GetAttribute("Occupied") ~= true then
            return
        end

        for _, plantPosition in ipairs(positions) do
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

    if not canUse(player, gardenBed) or gardenBed:GetAttribute("Occupied") then return false end
    local seed = typeof(seedType) == "string" and ItemDefinitions[seedType]
    if not seed or seed.Type ~= "Seed" or typeof(seed.PlantId) ~= "string" then return false end
    local plantType = seed.PlantId
    local positions = getPositions(gardenBed)
    local folder = PlantsFolder:FindFirstChild(plantType)
    local stages = folder and getStages(folder)
    if not positions or not ItemDefinitions[plantType] or not stages or #stages == 0 then return false end
    if not InventoryService.RemoveItem(player, seedType, #positions) then return false end

    gardenBed:SetAttribute("Occupied", true)
    gardenBed:SetAttribute("PlantType", plantType)
    gardenBed:SetAttribute("GrowthStage", 0)
    gardenBed:SetAttribute("ReadyToHarvest", false)

    task.spawn(PlantService.Grow, gardenBed, plantType)
    return true
end

function PlantService.Harvest(player, gardenBed)
    if not canUse(player, gardenBed) or not gardenBed:GetAttribute("ReadyToHarvest") then return false end
    local positions = getPositions(gardenBed)
    if not positions then return false end

    local plantType = gardenBed:GetAttribute("PlantType")

    if not InventoryService.AddItem(player, plantType, #positions) then return false end

    for _, plantPosition in ipairs(positions) do
        local plant = plantPosition:FindFirstChildWhichIsA("Model")
        if plant then
            plant:Destroy()
        end
    end

    gardenBed:SetAttribute("Occupied", false)
    gardenBed:SetAttribute("PlantType", "")
    gardenBed:SetAttribute("GrowthStage", 0)
    gardenBed:SetAttribute("ReadyToHarvest", false)
    return true
end

return PlantService
