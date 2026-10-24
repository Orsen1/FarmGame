local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local InventoryService = require(ServerScriptService:WaitForChild("InventoryService"))
local PlacementRules = require(ReplicatedStorage:WaitForChild("PlacementScripts"):WaitForChild("PlacementRules"))
local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))

local models = ReplicatedStorage:WaitForChild("PlaceableModels")
local plots = workspace:WaitForChild("Plots")

local PlacementService = {}

function PlacementService.placeItem(player, itemName, position)
    if player.Parent ~= Players
        or player:GetAttribute("DataLoaded") ~= true then
        return false, "Player data is not ready"
    end

    local definition = ItemDefinitions[itemName]
    local template = models:FindFirstChild(itemName)

    local plotName = player:GetAttribute("PlotName")
    local plot = plotName and plots:FindFirstChild(plotName)

    if not plot or plot:GetAttribute("OwnerUserId") ~= player.UserId then
        return false, "You do not own this plot"
    end

    local placedObjects = plot:FindFirstChild("PlacedObjects")

    if not placedObjects or not placedObjects:IsA("Folder") then
        return false, "PlacedObjects folder is missing"
    end

    local pivot, valid, reason = PlacementRules.getPlacement(plot, position, template)

    if not valid then
        return false, reason
    end

    local placedModel = template:Clone()

    placedModel:SetAttribute("OwnerUserId", player.UserId)
    placedModel:SetAttribute("ItemName", itemName)

    if definition.Plantable == true then
        placedModel:SetAttribute("Occupied", false)
        placedModel:SetAttribute("ReadyToHarvest", false)
        placedModel:SetAttribute("PlantType", "")
        placedModel:SetAttribute("GrowthStage", 0)
    end

    for _, object in ipairs(placedModel:GetDescendants()) do
        if object:IsA("BasePart") then
            object.Anchored = true
            object.CanQuery = true
        end
    end

    placedModel:PivotTo(pivot)

    if not InventoryService.RemoveItem(player, itemName, 1) then
        placedModel:Destroy()
        return false, "You do not have this item"
    end

    placedModel.Parent = placedObjects

    return true, "Item placed"
end

return PlacementService