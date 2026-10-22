local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local InventoryService = require(ServerScriptService:WaitForChild("InventoryService"))
local PlacementRules = require(ReplicatedStorage:WaitForChild("PlacementRules"))
local template = ReplicatedStorage:WaitForChild("PlaceableModels"):WaitForChild("GardenBed")
local plots = workspace:WaitForChild("Plots")

local PlacementService = {}

function PlacementService.placeGardenBed(player, position)
    if player.Parent ~= Players
        or player:GetAttribute("DataLoaded") ~= true then
        return false, "Player data is not ready"
    end

    local plotName = player:GetAttribute("PlotName")
    local plot = plotName and plots:FindFirstChild(plotName)

    if not plot or plot:GetAttribute("OwnerUserId") ~= player.UserId then
        return false, "You do not own this plot"
    end

    local placedObjects = plot:FindFirstChild("PlacedObjects")

    if not placedObjects or not placedObjects:IsA("Folder") then
        return false, "PlacedObjects folder is missing"
    end

    local pivot, valid, reason = PlacementRules.getPlacement(plot, position)

    if not valid then
        return false, reason
    end

    local bed = template:Clone()

    bed:SetAttribute("OwnerUserId", player.UserId)
    bed:SetAttribute("Occupied", false)
    bed:SetAttribute("ReadyToHarvest", false)
    bed:SetAttribute("PlantType", "")
    bed:SetAttribute("GrowthStage", 0)

    for _, object in ipairs(bed:GetDescendants()) do
        if object:IsA("BasePart") then
            object.Anchored = true
            object.CanQuery = true
        end
    end

    bed:PivotTo(pivot)

    if not InventoryService.RemoveItem(player, "GardenBed", 1) then
        bed:Destroy()
        return false, "You have no garden beds"
    end

    bed.Parent = placedObjects

    return true, "Garden bed placed"
end

return PlacementService