local Players = game:GetService("Players")
local CropConfig = require(game:GetService("ReplicatedStorage").Configs.CropConfig)
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
local HouseService = plotModule and require(ServerScriptService:WaitForChild("HouseService"))
local OrderService = plotModule and require(ServerScriptService:WaitForChild("OrderService"))
local FarmStandService = plotModule and require(ServerScriptService:WaitForChild("FarmStandService"))
local Laboratory = plotModule and require(ServerScriptService:WaitForChild("LaboratoryService"))
local StorageService = plotModule and require(ServerScriptService.StorageService)
local WarehouseMigration = plotModule and require(ServerScriptService.WarehouseMigration)
local GardenBeds = plotModule and require(ServerScriptService.GardenBedService)

local Journal = require(ServerScriptService.FarmJournalService)
local loadedData = {}
local savingPlayers = {}

local function loadSeedPurchases(player, purchases)
    if purchases == nil then return true end
    if typeof(purchases) ~= "table" then return false end
    for crop in pairs(CropConfig.Crops) do
        local count = purchases[crop]
        if count ~= nil then
            if typeof(count) ~= "number" or count % 1 ~= 0 or count < 0 or count > 9007199254740991 then return false end
            player:SetAttribute(CropConfig.SeedPurchaseAttribute(crop), count)
        end
    end
    return true
end

local function loadPlayerData(player)
    if player:GetAttribute("DataLoaded") ~= nil then
        return
    end

    player:SetAttribute("DataLoaded", false)

    local data, newPlayer = PlayerDataService.loadData(player.UserId)

    if data == nil then
        player:Kick("Failed to load player data. Please try again later.")
        return
    end

    if player.Parent ~= Players then
        return
    end

    if not loadSeedPurchases(player, data.SeedPurchases) then
        player:Kick("Failed to load your seed purchase history. Please try again.")
        return
    end

    if Laboratory and not Laboratory.Load(player, data.Laboratory) then
        player:Kick("Failed to load your research. Please try again later.")
        return
    end

    local originalData = data
    local houseMigrated, warehouseMigrated = false, false
    if WarehouseMigration then
        local reason
        data, warehouseMigrated, reason = WarehouseMigration.Apply(data)
        if not data then
            warn("[WAREHOUSE MIGRATION]", player.UserId, reason)
            player:Kick("Failed to load your warehouse update. Your previous farm is safe.")
            return
        end
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
            slot:SetAttribute("PaidLots", savedSlot.PaidLots)
        end
    end

    if PlotDataService then
        local plot = workspace.Plots[player:GetAttribute("PlotName")]
        local success, reason = PlotSectionService.loadData(plot, data.UnlockedPlotSections)
        if success then
            local migrated
            migrated, houseMigrated, reason = PlotDataService.migrateStarterHouse(plot, data)
            success = migrated ~= nil
            if success then data = migrated end
        end
        if success then
            success, reason = HouseService.Load(plot.StarterHouse, data.House)
        end
        if success then
            success, reason = PlotDataService.loadData(player, data.PlacedObjects or {})
        end
        if success then
            success, reason = StorageService.Load(player, plot, data.Warehouse, data.StorageReturns)
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

    if FarmStandService and not FarmStandService.Load(player, data.StandStock, data.TotalUnitsSold) then
        player:Kick("Failed to load your farm stand. Please try again later.")
        return
    end

    if not Journal.Load(player, data.FarmJournal, data) then player:Kick("Failed to load your farm journal.");return end
    if (houseMigrated or warehouseMigrated) and not newPlayer and
        not PlayerDataService.saveData(player.UserId, data, originalData) then
        player:Kick("Could not save the farm update. Please rejoin.")
        return
    end
    if player.Parent ~= Players then return end
    loadedData[player] = data
    if GardenBeds then GardenBeds.WatchOwnership(player) end
    player:SetAttribute("DataLoaded", true)
    if not PlayerPlotService then Journal.Record(player, "VisitResources") end
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
        local purchases = table.clone(data.SeedPurchases or {})
        for crop in pairs(CropConfig.Crops) do
            purchases[crop] = player:GetAttribute(CropConfig.SeedPurchaseAttribute(crop))
        end
        data.SeedPurchases = next(purchases) and purchases or nil
        data.CropRecord = nil
        data.FarmJournal = Journal.GetData(player)
        if Laboratory then
            Laboratory.Close(player)
            data.Laboratory = Laboratory.GetData(player)
            if not data.Laboratory then return false end
        end

        if OrderService then
            data.Orders = OrderService.GetData(player)
            if data.Orders == nil then
                return false
            end
        end

        if FarmStandService then
            data.StandStock, data.TotalUnitsSold = FarmStandService.GetData(player)
            if not data.StandStock then return false end
        end

        if PlotDataService then
            local placedObjects = PlotDataService.getData(player)
            if placedObjects == nil then
                return false
            end
            data.PlacedObjects = placedObjects
            local plot = workspace.Plots[player:GetAttribute("PlotName")]
            data.Warehouse, data.StorageReturns = StorageService.Snapshot(player, plot)
            if not data.Warehouse then return false end
            data.House = HouseService.GetData(plot.StarterHouse)
            if data.House == nil then return false end
            data.UnlockedPlotSections = PlotSectionService.getData(plot)
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
    Journal.Clear(player)
    if Laboratory then Laboratory.Clear(player) end
    if OrderService then
        OrderService.Clear(player)
    end
    if FarmStandService then FarmStandService.Clear(player) end
    if StorageService then StorageService.Clear(player) end
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
