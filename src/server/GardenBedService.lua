local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Configs.GardenBedConfig)
local PlacementRules = require(ReplicatedStorage.PlacementScripts.PlacementRules)
local Layout = require(ReplicatedStorage.PlacementScripts.GardenBedLayout)
local InventoryService = require(script.Parent.InventoryService)
local MoneyService = require(script.Parent.MoneyService)
local PlantService = require(script.Parent.PlantService)
local StorageService = require(script.Parent.StorageService)
local Journal = require(script.Parent.FarmJournalService)
local plots = workspace:WaitForChild("Plots")

local GardenBeds = {}
local ownershipConnections = {}

local function isBed(item)
    return Config.Types[item] ~= nil
end

local function ownedPlot(player)
    local plot = plots:FindFirstChild(player:GetAttribute("PlotName") or "")
    if plot and plot:GetAttribute("OwnerUserId") == player.UserId then return plot end
end

local function countSlots(folder)
    local count = 0
    for _, slot in ipairs(folder and folder:GetChildren() or {}) do
        if isBed(slot.ItemName.Value) then count += slot.Amount.Value end
    end
    return count
end

function GardenBeds.CountOwned(player)
    local plot = ownedPlot(player)
    if not plot then return 0 end
    local count = countSlots(player:FindFirstChild("Inventory")) + countSlots(player:FindFirstChild("StorageInventory")) +
        StorageService.CountReturns(player, isBed)
    for _, object in ipairs(plot.PlacedObjects:GetChildren()) do
        if object:GetAttribute("OwnerUserId") == player.UserId and isBed(object:GetAttribute("ItemName") or object.Name) then
            count += 1
        end
    end
    return count
end

function GardenBeds.WatchOwnership(player)
    local plot = ownedPlot(player)
    if not plot then return end
    local connections = {}
    ownershipConnections[player] = connections
    local queued = false
    local function refresh()
        if queued then return end
        queued = true
        task.defer(function()
            queued = false
            if ownershipConnections[player] == connections then
                player:SetAttribute("OwnedGardenBeds", GardenBeds.CountOwned(player))
            end
        end)
    end
    local function watch(signal)
        table.insert(connections, signal:Connect(refresh))
    end
    for _, folder in ipairs({player.Inventory, player.StorageInventory}) do
        for _, slot in ipairs(folder:GetChildren()) do
            watch(slot.ItemName.Changed)
            watch(slot.Amount.Changed)
        end
    end
    watch(plot.PlacedObjects.ChildAdded)
    watch(plot.PlacedObjects.ChildRemoved)
    watch(player:GetAttributeChangedSignal("StorageReturnCount"))
    player:SetAttribute("OwnedGardenBeds", GardenBeds.CountOwned(player))
end

Players.PlayerRemoving:Connect(function(player)
    local connections = ownershipConnections[player]
    if not connections then return end
    ownershipConnections[player] = nil
    for _, connection in ipairs(connections) do connection:Disconnect() end
end)

function GardenBeds.Offer(player, object)
    if player:GetAttribute("Teleporting") or player:GetAttribute("ProductionMode") or player:GetAttribute("Milking") or
        not Journal.TutorialComplete(player) or not PlantService.CanUse(player, object) then
        return nil, "Move closer to your garden bed."
    end
    local item = object:GetAttribute("ItemName") or object.Name
    local level = object:GetAttribute("BedLevel") or 1
    local definition = Config.Types[item]
    local price = definition and definition.UpgradePrices[level]
    if not price then return nil, "This bed is fully expanded." end
    return {Item = item, Level = level, Price = price}
end

function GardenBeds.Upgrade(player, object, expectedLevel)
    local offer, reason = GardenBeds.Offer(player, object)
    if not offer then return false, reason end
    if offer.Level ~= expectedLevel then return false, "This bed has already changed. Open the preview again." end

    local plot = ownedPlot(player)
    local _, _, valid, conflict = PlacementRules.getBedExpansion(plot, object, offer.Item, offer.Level + 1, player.Character)
    if not valid then return false, conflict end

    local total = (object:GetAttribute("PurchaseCents") or 0) + offer.Price
    if not InventoryService.IsPurchaseCost(total) then return false, "This bed's purchase cost could not be recorded." end
    if not MoneyService.RemoveMoney(player, offer.Price) then return false, "Not enough money." end

    Layout.Expand(object, offer.Item, offer.Level + 1)
    object:SetAttribute("PurchaseCents", total)
    return true, "Garden bed expanded."
end

return GardenBeds
