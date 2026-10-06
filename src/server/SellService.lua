local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryService = require(ServerScriptService:WaitForChild("InventoryService"))
local MoneyService = require(ServerScriptService:WaitForChild("MoneyService"))


local SellPrices = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("SellPrices"))

local SellService = {}

function SellService.SellItem(player, itemName, amount)
	local price = SellPrices[itemName]

	if not price then
		print("Item cannot be sold:", itemName)
		return false
	end

	local removed = InventoryService.RemoveItem(player, itemName, amount)

	if not removed then
		print("Player does not have item:", itemName)
		return false
	end
	
	local totalPrice = price * amount
	MoneyService.AddMoney(player, totalPrice)

	print(player.Name .. " sold " .. itemName .. " for " .. price .. " money")

	return true
end

return SellService
