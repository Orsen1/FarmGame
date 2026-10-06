local Players = game:GetService("Players")

local player = Players.LocalPlayer
local inventory = player:WaitForChild("Inventory")

local function isSeed(itemName)
	return itemName:match("Seed$") ~= nil
end

local function getSelectedSlot()
	local selectedSlotNumber = player:GetAttribute("SelectedSlot") or 1
	return inventory:FindFirstChild("Slot" .. selectedSlotNumber)
end

local function getSelectedItemName()
	local selectedSlot = getSelectedSlot()

	if not selectedSlot then
		return "", 0
	end

	local itemName = selectedSlot:WaitForChild("ItemName").Value
	local amount = selectedSlot:WaitForChild("Amount").Value

	return itemName, amount
end

local function getGardenBedFromPrompt(prompt)
	-- GardenBed > Soil > PromtAttachment > GardenBedPrompt
	return prompt.Parent.Parent.Parent
end

local function updatePrompt(prompt)
	local gardenBed = getGardenBedFromPrompt(prompt)

	if not gardenBed then
		return
	end

	local occupied = gardenBed:GetAttribute("Occupied")
	local readyToHarvest = gardenBed:GetAttribute("ReadyToHarvest")

	if readyToHarvest then
		prompt.Enabled = true
		prompt.ActionText = "Собрать"
		return
	end

	if occupied then
		prompt.Enabled = false
		return
	end

	-- Только если грядка пустая, смотрим выбранный предмет
	local selectedItemName, selectedAmount = getSelectedItemName()
	local selectedItemIsSeed = isSeed(selectedItemName) and selectedAmount > 0

	if selectedItemIsSeed then
		prompt.Enabled = true
		prompt.ActionText = "Посадить"
	else
		prompt.Enabled = false
	end
end

local function updateAllPrompts()
	for _, object in ipairs(workspace:GetDescendants()) do
		if object:IsA("ProximityPrompt") and object.Name == "GardenBedPrompt" then
			updatePrompt(object)
		end
	end
end

local function bindGardenBedPrompt(prompt)
	local gardenBed = getGardenBedFromPrompt(prompt)

	if gardenBed then
		gardenBed:GetAttributeChangedSignal("Occupied"):Connect(function()
			updatePrompt(prompt)
		end)

		gardenBed:GetAttributeChangedSignal("ReadyToHarvest"):Connect(function()
			updatePrompt(prompt)
		end)
	end

	updatePrompt(prompt)
end

for _, object in ipairs(workspace:GetDescendants()) do
	if object:IsA("ProximityPrompt") and object.Name == "GardenBedPrompt" then
		bindGardenBedPrompt(object)
	end
end

workspace.DescendantAdded:Connect(function(object)
	if object:IsA("ProximityPrompt") and object.Name == "GardenBedPrompt" then
		task.wait()
		bindGardenBedPrompt(object)
	end
end)

player:GetAttributeChangedSignal("SelectedSlot"):Connect(function()
	updateAllPrompts()
end)

for _, slot in ipairs(inventory:GetChildren()) do
	local itemName = slot:WaitForChild("ItemName")
	local amount = slot:WaitForChild("Amount")

	itemName.Changed:Connect(updateAllPrompts)
	amount.Changed:Connect(updateAllPrompts)
end

updateAllPrompts()