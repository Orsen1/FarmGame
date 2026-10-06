local InventoryService = {}
local SLOT_COUNT = 6

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

function InventoryService.Initialize(player)
	if player:FindFirstChild("Inventory") then
		return
	end
	
	local inventory = Instance.new("Folder")
	inventory.Name = "Inventory"
	inventory.Parent = player
	
	for i = 1, SLOT_COUNT do
		createSlot(inventory, i)
	end
end

function InventoryService.AddItem(player, itemName, amount)
	local inventory = player:WaitForChild("Inventory")
	
	for _, slot in ipairs(inventory:GetChildren()) do
		if slot.ItemName.Value == itemName then
			slot.Amount.Value += amount
			return true
		end
	end

	for _, slot in ipairs(inventory:GetChildren()) do
		if slot.ItemName.Value == "" then
			slot.ItemName.Value = itemName
			slot.Amount.Value = amount
			return true
		end
	end

	print("Inventory is full")
	return false
end

function InventoryService.RemoveItem(player, itemName, amount)
	local inventory = player:WaitForChild("Inventory")
	
	for _, slot in ipairs(inventory:GetChildren()) do
		if slot.ItemName.Value == itemName then
			if slot.Amount.Value < amount then
				return false
			end

			slot.Amount.Value -= amount

			if slot.Amount.Value <= 0 then
				slot.ItemName.Value = ""
				slot.Amount.Value = 0
			end

			return true
		end
	end

	return false
end

return InventoryService
