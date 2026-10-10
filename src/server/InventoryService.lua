local InventoryService = {}
local SLOT_COUNT = 6
local MAX_INTEGER = 9007199254740991

local function isValidAmount(amount)
	return typeof(amount) == "number"
		and amount >= 1
		and amount <= MAX_INTEGER
		and amount % 1 == 0
end

local function isValidItemName(itemName)
	return typeof(itemName) == "string" and itemName ~= ""
end

local function createSlot(inventory, slotNumber)
	local slot = Instance.new("Folder")
	slot.Name = "Slot" .. slotNumber
	slot.Parent = inventory

	local itemName = Instance.new("StringValue")
	itemName.Name = "ItemName"
	itemName.Value = ""
	itemName.Parent = slot

	local amount = Instance.new("IntValue")
	amount.Name = "Amount"
	amount.Value = 0
	amount.Parent = slot
end

local function findTargetSlot(inventory, itemName)
	local emptySlot = nil

	for slotNumber = 1, SLOT_COUNT do
		local slot = inventory:FindFirstChild("Slot" .. slotNumber)
		local nameValue = slot and slot:FindFirstChild("ItemName")
		local amountValue = slot and slot:FindFirstChild("Amount")

		if nameValue and amountValue then
			if nameValue.Value == itemName then
				return slot
			end

			if nameValue.Value == "" and not emptySlot then
				emptySlot = slot
			end
		end
	end

	return emptySlot
end

function InventoryService.Initialize(player)
	if player:FindFirstChild("Inventory") then
		return
	end

	local inventory = Instance.new("Folder")
	inventory.Name = "Inventory"
	inventory.Parent = player

	for slotNumber = 1, SLOT_COUNT do
		createSlot(inventory, slotNumber)
	end
end

function InventoryService.CanAddItem(player, itemName, amount)
	if not isValidItemName(itemName) or not isValidAmount(amount) then
		return false, "InvalidItemOrAmount"
	end

	local inventory = player:FindFirstChild("Inventory")
	if not inventory then
		return false, "InventoryNotReady"
	end

	local slot = findTargetSlot(inventory, itemName)
	if not slot then
		return false, "InventoryFull"
	end

	local currentAmount = slot.Amount.Value
	if currentAmount < 0 or currentAmount % 1 ~= 0
		or currentAmount > MAX_INTEGER - amount then
		return false, "AmountTooLarge"
	end

	return true
end

function InventoryService.AddItem(player, itemName, amount)
	local canAdd, reason = InventoryService.CanAddItem(player, itemName, amount)
	if not canAdd then
		return false, reason
	end

	local slot = findTargetSlot(player.Inventory, itemName)
	slot.ItemName.Value = itemName
	slot.Amount.Value = slot.Amount.Value + amount
	return true
end

function InventoryService.RemoveItem(player, itemName, amount)
	if not isValidItemName(itemName) or not isValidAmount(amount) then
		return false, "InvalidItemOrAmount"
	end

	local inventory = player:FindFirstChild("Inventory")
	if not inventory then
		return false, "InventoryNotReady"
	end

	for slotNumber = 1, SLOT_COUNT do
		local slot = inventory:FindFirstChild("Slot" .. slotNumber)
		local nameValue = slot and slot:FindFirstChild("ItemName")
		local amountValue = slot and slot:FindFirstChild("Amount")

		if nameValue and amountValue and nameValue.Value == itemName then
			if amountValue.Value < amount then
				return false, "NotEnoughItems"
			end

			amountValue.Value = amountValue.Value - amount
			if amountValue.Value == 0 then
				nameValue.Value = ""
			end

			return true
		end
	end

	return false, "NotEnoughItems"
end

return InventoryService
