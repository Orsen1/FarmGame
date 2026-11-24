local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryService = require(ServerScriptService:WaitForChild("InventoryService"))
local MoneyService = require(ServerScriptService:WaitForChild("MoneyService"))
local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))

local Journal = require(ServerScriptService.FarmJournalService)
local GardenBeds = require(ServerScriptService.GardenBedService)
local BedConfig = require(ReplicatedStorage.Configs.GardenBedConfig)
local CropConfig = require(ReplicatedStorage.Configs.CropConfig)
local BuyService = {}
local MAX_INTEGER = 9007199254740991

function BuyService.BuyItem(player, itemName, amount, quotedPurchases)
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

	if not Journal.CanBuy(player, itemName) then return false, "FarmLevelRequired" end

	local permitted, tutorialReason = Journal.CheckPurchase(player, itemName, amount)
	if not permitted then return false, tutorialReason end

	if BedConfig.Types[itemName] and amount > BedConfig.Limit(Journal.GetLevel(player)) - GardenBeds.CountOwned(player) then
		return false, "GardenBedLimit"
	end

	local totalPrice = price * amount
	local counter, purchased
	if item.Type == "Seed" then
		counter = CropConfig.SeedPurchaseAttribute(item.PlantId)
		purchased = player:GetAttribute(counter) or 0
		if quotedPurchases ~= nil and quotedPurchases ~= purchased then return false, "SeedPriceChanged" end
		totalPrice = CropConfig.SeedTotal(price, purchased, amount)
	end
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

	local added, addReason = InventoryService.AddItem(player, itemName, amount, price)
	if not added then
		MoneyService.AddMoney(player, totalPrice)
		return false, addReason
	end

	if counter then player:SetAttribute(counter, math.min(MAX_INTEGER, purchased + amount)) end
	Journal.Record(player, "Buy", amount, itemName)
	print(player.Name .. " bought " .. amount .. "x " .. itemName
		.. " for " .. totalPrice .. " cents")
	return true
end

return BuyService
