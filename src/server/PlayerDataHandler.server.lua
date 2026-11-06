local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local InventoryService = require(ServerScriptService:WaitForChild("InventoryService"))
local MoneyService = require(ServerScriptService:WaitForChild("MoneyService"))
local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataService"))
local PlayerPlotService = require(ServerScriptService:WaitForChild("PlayerPlotService"))
local PlotDataService = require(ServerScriptService:WaitForChild("PlotDataService"))
local ProductionService = require(ServerScriptService:WaitForChild("ProductionService"))
local TravelService = require(ServerScriptService:WaitForChild("WorldTravelService"))

local savingPlayers = {}

local function loadPlayerData(player)
    if player:GetAttribute("DataLoaded") ~= nil then
        return
    end

    player:SetAttribute("DataLoaded", false)

    local data = PlayerDataService.loadData(player.UserId)

    if data == nil then
        player:Kick("Failed to load player data. Please try again later.")
        return
    end

    if player.Parent ~= Players then
        return
    end

    PlayerPlotService.assignPlotToPlayer(player)

    if not player:GetAttribute("PlotName") then
        player:Kick("No free plots. Please try another server.")
        return
    end

    InventoryService.Initialize(player)
    MoneyService.Initialize(player)

    player.PlayerData.MoneyCents.Value = data.Money

    for i = 1, 6 do
        local savedSlot = data.Inventory[i]

        if savedSlot then
            local slot = player.Inventory["Slot" .. i]
            slot.ItemName.Value = savedSlot.ItemName
            slot.Amount.Value = savedSlot.Amount
        end
    end

    local success, reason = PlotDataService.loadData(
        player,
        data.PlacedObjects or {}
    )

    if not success then
        warn("[PLOT LOAD ERROR]", player.UserId, reason)
        player:Kick("Failed to load your farm. Please try again later.")
        return
    end

    player:SetAttribute("DataLoaded", true)
end

local function savePlayerData(player, preparingTeleport)
    if savingPlayers[player] or player:GetAttribute("DataLoaded") ~= true then
        return false
    end

    savingPlayers[player] = true
    player:SetAttribute("DataLoaded", false)

    local data
    local releasedPlot = false

    local ok, result = pcall(function()
        ProductionService.Close(player, "Saving")

        local inventoryData = InventoryService.GetInventory(player)
        local placedObjects = PlotDataService.getData(player)

        if inventoryData == nil or placedObjects == nil then
            return false
        end

        data = {
            Money = MoneyService.GetMoney(player),
            Inventory = inventoryData,
            PlacedObjects = placedObjects,
        }

        if not preparingTeleport then
            PlayerPlotService.releasePlot(player)
            releasedPlot = true
        end

        return PlayerDataService.saveData(player.UserId, data)
    end)

    local success = ok and result == true
    savingPlayers[player] = nil

    if not preparingTeleport and not releasedPlot then
        PlayerPlotService.releasePlot(player)
    elseif preparingTeleport and not success and player.Parent == Players then
        player:SetAttribute("DataLoaded", true)
    end

    if success then
        print("[SAVE OK]", player.UserId, "Money:", data.Money)
    else
        warn("[SAVE FAILED]", player.UserId, ok and "Save rejected" or result)
    end

    return success
end

TravelService.SetDataCallbacks(function(player)
    return savePlayerData(player, true)
end, function(player)
    if player.Parent == Players then
        player:SetAttribute("DataLoaded", true)
    end
end)

Players.PlayerAdded:Connect(function(player)
    loadPlayerData(player)
end)

Players.PlayerRemoving:Connect(function(player)
    savePlayerData(player)
    PlayerPlotService.releasePlot(player)
end)

game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(savePlayerData, player)
    end

    while next(savingPlayers) ~= nil do
        task.wait(0.1)
    end
end)

for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(loadPlayerData, player)
end