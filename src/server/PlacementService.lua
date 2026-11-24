local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local InventoryService = require(ServerScriptService:WaitForChild("InventoryService"))
local Journal = require(ServerScriptService.FarmJournalService)
local CoopUpgradeService = require(ServerScriptService.CoopUpgradeService)
local PlacementRules = require(ReplicatedStorage:WaitForChild("PlacementScripts"):WaitForChild("PlacementRules"))
local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))

local PlacementModels = require(ReplicatedStorage:WaitForChild("PlacementScripts"):WaitForChild("PlacementModels"))
local plots = workspace:WaitForChild("Plots")

local PlacementService = {}

function PlacementService.placeItem(player, itemName, position, rotation)
    if player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true then
        return false, "Player data is not ready"
    end

    local definition = ItemDefinitions[itemName]
    local template = PlacementModels.getTemplate(itemName)

    if not definition or definition.Placeable ~= true or not template then
        return false, "Missing placeable definition or model"
    end

    if not Journal.CanBuild(player, itemName) then return false, "This building requires a higher farm level" end

    local plotName = player:GetAttribute("PlotName")
    local plot = plotName and plots:FindFirstChild(plotName)

    if not plot or plot:GetAttribute("OwnerUserId") ~= player.UserId then
        return false, "You do not own this plot"
    end

    local placedObjects = plot:FindFirstChild("PlacedObjects")

    if not placedObjects or not placedObjects:IsA("Folder") then
        return false, "PlacedObjects folder is missing"
    end

    local pivot, valid, reason = PlacementRules.getPlacement(plot, position, template, rotation)

    if not valid then
        return false, reason
    end

    local placedModel = template:Clone()

    placedModel:SetAttribute("OwnerUserId", player.UserId)
    placedModel:SetAttribute("ItemName", itemName)

    if definition.BuildsInto then
        placedModel:SetAttribute("ConstructionStage", 0)
    end

    if definition.Plantable == true then
        placedModel:SetAttribute("Occupied", false)
        placedModel:SetAttribute("ReadyToHarvest", false)
        placedModel:SetAttribute("PlantType", "")
        placedModel:SetAttribute("PlantedCount", 0)
        placedModel:SetAttribute("PlantingCapacity", #placedModel.PlantingSpots:GetChildren())
    end

    for _, object in ipairs(placedModel:GetDescendants()) do
        if object:IsA("BasePart") then
            object.Anchored = true
            object.CanQuery = true
        end
    end

    placedModel:PivotTo(pivot)

    local removed
    if definition.InstanceItem then
        local prepared, encoded, index = CoopUpgradeService.Prepare(player, placedModel, itemName)
        if not prepared then placedModel:Destroy();return false, encoded end
        removed = InventoryService.RemoveObject(player, index, encoded)
    else
        local _, index = InventoryService.FindItem(player, itemName)
        local price
        removed, price = InventoryService.RemoveFromSlot(player, index, itemName, 1)
        if removed then placedModel:SetAttribute("PurchaseCents", price) end
    end
    if not removed then
        placedModel:Destroy()
        return false, "You do not have this item"
    end

    placedModel.Parent = placedObjects
    Journal.Update(player)

    return true, "Item placed"
end

return PlacementService
