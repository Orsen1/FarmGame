local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local InventoryService = require(ServerScriptService:WaitForChild("InventoryService"))
local MoneyService = require(ServerScriptService:WaitForChild("MoneyService"))

Players.PlayerAdded:Connect(function(player)
	InventoryService.Initialize(player)
	MoneyService.Initialize(player)

	InventoryService.AddItem(player, "CarrotSeed", 5)

	MoneyService.AddMoney(player, 125) -- тест: $1.25
	player:SetAttribute("SelectedSlot", 1)
end)