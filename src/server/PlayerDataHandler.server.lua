local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local InventoryService = require(ServerScriptService:WaitForChild("InventoryService"))
local MoneyService = require(ServerScriptService:WaitForChild("MoneyService"))
local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataService"))
local TravelService = require(ServerScriptService:WaitForChild("WorldTravelService"))

local plotModule = ServerScriptService:FindFirstChild("PlayerPlotService")
local PlayerPlotService = plotModule and require(plotModule)
local PlotDataService = plotModule and require(ServerScriptService:WaitForChild("PlotDataService"))
local PlotSectionService = plotModule and require(ServerScriptService:WaitForChild("PlotSectionService"))
local ProductionService = plotModule and require(ServerScriptService:WaitForChild("ProductionService"))
local OrderService = plotModule and require(ServerScriptService:WaitForChild("OrderService"))

local loadedData = {}
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

    if PlayerPlotService then
        PlayerPlotService.assignPlotToPlayer(player)

        if not player:GetAttribute("PlotName") then
            player:Kick("No free plots. Please try another server.")
            return
        end
    end

    InventoryService.Initialize(player)
    MoneyService.Initialize(player)

    player.PlayerData.MoneyCents.Value = data.Money

    for i = 1, 6 do
        local savedSlot = data.Inventory[i]

        if savedSlot then
            if not InventoryService.IsValidObjectRow(savedSlot) then
                player:Kick("Failed to load a packed building. Please try again later.")
                return
            end
            local slot = player.Inventory["Slot" .. i]
            slot.ItemName.Value = savedSlot.ItemName
            slot.Amount.Value = savedSlot.Amount
            slot:SetAttribute("ObjectData", savedSlot.ObjectData)
        end
    end

    if PlotDataService then
        local plot = workspace.Plots[player:GetAttribute("PlotName")]
        local success, reason = PlotSectionService.loadData(plot, data.UnlockedPlotSections)
        if success then
            success, reason = PlotDataService.loadData(player, data.PlacedObjects or {})
        end

        if not success then
            warn("[PLOT LOAD ERROR]", player.UserId, reason)
            player:Kick("Failed to load your farm. Please try again later.")
            return
        end
    end

    if OrderService then
        local success, reason = OrderService.LoadData(player, data.Orders)
        if not success then
            warn("[ORDER LOAD ERROR]", player.UserId, reason)
            player:Kick("Failed to load your orders. Please try again later.")
            return
        end
    end

    loadedData[player] = data
    player:SetAttribute("DataLoaded", true)
end

local function savePlayerData(player, preparingTeleport)
    if savingPlayers[player] or player:GetAttribute("DataLoaded") ~= true or not loadedData[player] then
        return false
    end

    savingPlayers[player] = true
    player:SetAttribute("DataLoaded", false)

    local data
    local releasedPlot = false

    local ok, result = pcall(function()
        if ProductionService then
            ProductionService.Close(player, "Saving")
        end

        local inventoryData = InventoryService.GetInventory(player)
        if inventoryData == nil then
            return false
        end

        data = table.clone(loadedData[player])
        data.Money = MoneyService.GetMoney(player)
        data.Inventory = inventoryData

        if OrderService then
            data.Orders = OrderService.GetData(player)
            if data.Orders == nil then
                return false
            end
        end

        if PlotDataService then
            local placedObjects = PlotDataService.getData(player)
            if placedObjects == nil then
                return false
            end
            data.PlacedObjects = placedObjects
            data.UnlockedPlotSections = PlotSectionService.getData(workspace.Plots[player:GetAttribute("PlotName")])
        end

        if PlayerPlotService and not preparingTeleport then
            PlayerPlotService.releasePlot(player)
            releasedPlot = true
        end

        return PlayerDataService.saveData(player.UserId, data)
    end)

    local success = ok and result == true
    savingPlayers[player] = nil

    if PlayerPlotService and not preparingTeleport and not releasedPlot then
        PlayerPlotService.releasePlot(player)
    elseif preparingTeleport and not success and player.Parent == Players then
        player:SetAttribute("DataLoaded", true)
    end

    if success then
        if player.Parent == Players then
            loadedData[player] = data
        end
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
    loadedData[player] = nil
    if OrderService then
        OrderService.Clear(player)
    end
    if PlayerPlotService then
        PlayerPlotService.releasePlot(player)
    end
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
