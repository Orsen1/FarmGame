local CropItems = require(game.ReplicatedStorage.CropItems)
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryService = require(ServerScriptService:WaitForChild("InventoryService"))
local MoneyService = require(ServerScriptService:WaitForChild("MoneyService"))
local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))

local SellService = {}
local Journal = require(ServerScriptService.FarmJournalService)
local MAX_INTEGER = 9007199254740991

function SellService.Price(itemName, groups)
    return CropItems.Value(itemName, groups, ItemDefinitions)
end

function SellService.RecordSale(player, itemName, amount, cents)
    Journal.Record(player, "Sell", amount, itemName)
    Journal.Record(player, "Sales", cents)
end

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

	if not Journal.CanSell(player, itemName, amount) then return false, "FinishTutorialSale" end

	local removedGroups, removalError = InventoryService.GetRemoval(player, {[itemName] = amount})
    if not removedGroups then return false, removalError end
    local totalPrice = SellService.Price(itemName, removedGroups[itemName])
	if not MoneyService.CanAddMoney(player, totalPrice) then
		return false, "InvalidBalanceOrAmountTooLarge"
	end

	local inputs = {[itemName] = amount}
	local outputs = item.SellReturnItem and {[item.SellReturnItem] = amount} or {}
	local removed, reason = InventoryService.ExchangeItems(player, inputs, outputs)
	if not removed then
		return false, reason
	end

	local added = MoneyService.AddMoney(player, totalPrice)
	if not added then
		InventoryService.ExchangeItems(player, outputs, inputs, removedGroups)
		return false, "MoneyCouldNotBeAdded"
	end

    SellService.RecordSale(player, itemName, amount, totalPrice)
	print(player.Name .. " sold " .. amount .. "x " .. itemName
		.. " for " .. totalPrice .. " cents")
	return true
end

return SellService
