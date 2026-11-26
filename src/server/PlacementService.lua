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

local Catalog = require(ReplicatedStorage.PlacementScripts.BuildCatalog)
local PlacementService = {}

local function ownedPlot(player)
    if player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true then
        return nil, "Player data is not ready"
    end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 or player:GetAttribute("Teleporting") or player:GetAttribute("ProductionMode")
        or player:GetAttribute("Milking") then return nil, "Building is unavailable" end
    local plot = plots:FindFirstChild(player:GetAttribute("PlotName") or "")
    if not plot or plot:GetAttribute("OwnerUserId") ~= player.UserId then
        return nil, "You do not own this plot"
    end
    return plot
end

function PlacementService.moveObject(player, object, position, rotation)
    local plot, reason = ownedPlot(player)
    if not plot then return false, reason end
    local item = PlacementRules.movableItem(plot, object, player.UserId)
    if not item then return false, "Choose a building on your farm" end
    if object:GetAttribute("OperatorUserId") then return false, "This building is in use" end

    local pivot, valid, conflict = PlacementRules.getMovePlacement(plot, object, item, position, rotation)
    if not valid then return false, conflict end

    object:PivotTo(pivot)
    return true, "Building moved"
end

function PlacementService.placeItem(player, itemName, position, rotation, area, index, expected)
    local plot, reason = ownedPlot(player)
    if not plot then return false, reason end
    if typeof(itemName) ~= "string" then return false, "Invalid item" end
    local definition = ItemDefinitions[itemName]
    local template = PlacementModels.getTemplate(itemName)

    if not definition or definition.Placeable ~= true or not template then
        return false, "Missing placeable definition or model"
    end

    if not Journal.CanBuild(player, itemName) then return false, "This building requires a higher farm level" end

    local placedObjects = plot:FindFirstChild("PlacedObjects")

    if not placedObjects or not placedObjects:IsA("Folder") then
        return false, "PlacedObjects folder is missing"
    end

    if area == nil then
        local row, found = InventoryService.FindItem(player, itemName)
        area, index, expected = "Inventory", found, row and row.ObjectData
    end
    local slot = Catalog.Resolve(player, itemName, area, index, expected)
    if not slot then return false, "This item is no longer available" end

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

    local data = slot:GetAttribute("ObjectData")
    if definition.InstanceItem then
        local prepared, message = CoopUpgradeService.Prepare(placedModel, itemName, data)
        if not prepared then placedModel:Destroy(); return false, message end
    end
    local removed, price = InventoryService.TakeFromSlot(slot, itemName, 1, data)
    if not removed then
        placedModel:Destroy()
        return false, "This item is no longer available"
    end
    if not data then placedModel:SetAttribute("PurchaseCents", price) end

    placedModel.Parent = placedObjects
    Journal.Update(player)

    return true, "Item placed"
end

return PlacementService
