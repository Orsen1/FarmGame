local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local InventoryService = require(ServerScriptService:WaitForChild("InventoryService"))
local MoneyService = require(ServerScriptService:WaitForChild("MoneyService"))
local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataService"))

local function loadPlayerData(player)
	player:SetAttribute("DataLoaded", false)

    local data = PlayerDataService.loadData(player.UserId)
    if data == nil then
        player:Kick("Failed to load player data. Please try again later.")
        return
    end

    if player.Parent ~= Players then
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

    player:SetAttribute("DataLoaded", true)
end

Players.PlayerAdded:Connect(function(player)
    loadPlayerData(player)
end)

Players.PlayerRemoving:Connect(function(player)
	if player:GetAttribute("DataLoaded") ~= true then
		return
	end

	local inventoryData = InventoryService.GetInventory(player)

	if inventoryData == nil then
		warn("[SAVE ERROR] Could not retrieve inventory data for", player.UserId)
		return
	end

	local data = {
		Money = MoneyService.GetMoney(player),
		Inventory = inventoryData,
	}

	player:SetAttribute("DataLoaded", false)

	PlayerDataService.saveData(player.UserId, data)
end)