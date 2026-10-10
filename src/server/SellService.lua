local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryService = require(ServerScriptService:WaitForChild("InventoryService"))
local MoneyService = require(ServerScriptService:WaitForChild("MoneyService"))
local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))

local SellService = {}
local MAX_INTEGER = 9007199254740991

function SellService.SellItem(player, itemName, amount)
	if typeof(itemName) ~= "string" then
		return false, "InvalidItem"
	end

	if typeof(amount) ~= "number" or amount < 1
		or amount > MAX_INTEGER or amount % 1 ~= 0 then
		return false, "InvalidAmount"
	end

	local item = ItemDefinitions[itemName]
	local price = item and item.SellPriceCents

	if typeof(price) ~= "number" or price < 0
		or price > MAX_INTEGER or price % 1 ~= 0 then
		return false, "ItemCannotBeSold"
	end

	local totalPrice = price * amount
	if not MoneyService.CanAddMoney(player, totalPrice) then
		return false, "InvalidBalanceOrAmountTooLarge"
	end

	local removed, reason = InventoryService.RemoveItem(player, itemName, amount)
	if not removed then
		return false, reason
	end

	local added = MoneyService.AddMoney(player, totalPrice)
	if not added then
		InventoryService.AddItem(player, itemName, amount)
		return false, "MoneyCouldNotBeAdded"
	end

	print(player.Name .. " sold " .. amount .. "x " .. itemName
		.. " for " .. totalPrice .. " cents")
	return true
end

return SellService
