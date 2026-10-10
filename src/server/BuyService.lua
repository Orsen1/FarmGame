local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryService = require(ServerScriptService:WaitForChild("InventoryService"))
local MoneyService = require(ServerScriptService:WaitForChild("MoneyService"))
local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))

local BuyService = {}
local MAX_INTEGER = 9007199254740991

function BuyService.BuyItem(player, itemName, amount)
	if typeof(itemName) ~= "string" then
		return false, "InvalidItem"
	end

	if typeof(amount) ~= "number" or amount < 1
		or amount > MAX_INTEGER or amount % 1 ~= 0 then
		return false, "InvalidAmount"
	end

	local item = ItemDefinitions[itemName]
	local price = item and item.BuyPriceCents

	if typeof(price) ~= "number" or price < 0
		or price > MAX_INTEGER or price % 1 ~= 0 then
		return false, "ItemCannotBeBought"
	end

	local totalPrice = price * amount
	if totalPrice > MAX_INTEGER then
		return false, "AmountTooLarge"
	end

	local canAdd, reason = InventoryService.CanAddItem(player, itemName, amount)
	if not canAdd then
		return false, reason
	end

	local removed = MoneyService.RemoveMoney(player, totalPrice)
	if not removed then
		return false, "NotEnoughMoneyOrDataNotReady"
	end

	local added, addReason = InventoryService.AddItem(player, itemName, amount)
	if not added then
		MoneyService.AddMoney(player, totalPrice)
		return false, addReason
	end

	print(player.Name .. " bought " .. amount .. "x " .. itemName
		.. " for " .. totalPrice .. " cents")
	return true
end

return BuyService
