local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))
local ConstructionDefinitions = require(ReplicatedStorage:WaitForChild("Configs")
    :WaitForChild("ConstructionDefinitions"))

local player = Players.LocalPlayer
local inventory = player:WaitForChild("Inventory")
local plots = workspace:WaitForChild("Plots")

local boundPrompts = {}

local function isSupportedPrompt(object)
    return object:IsA("ProximityPrompt") and (object.Name == "ActionPrompt" or object.Name == "CollectPrompt")
end

local function getSelectedItem()
    local slotNumber = player:GetAttribute("SelectedSlot") or 1
    local slot = inventory:FindFirstChild("Slot" .. slotNumber)

    if not slot then
        return "", 0
    end

    return slot.ItemName.Value, slot.Amount.Value
end

local function getOutputAmount(object)
    local outputInventory = object:FindFirstChild("OutputInventory")
    local total = 0

    if outputInventory then
        for _, item in ipairs(outputInventory:GetChildren()) do
            if item:IsA("IntValue") and item.Value > 0 then
                total = total + item.Value
            end
        end
    end

    return total
end

local function updatePrompt(prompt)
    local object = prompt:FindFirstAncestorOfClass("Model")
    prompt.Enabled = false

    if not object or player:GetAttribute("DataLoaded") ~= true or object:GetAttribute("OwnerUserId") ~= player.UserId then
        return
    end

    local itemName = object:GetAttribute("ItemName") or object.Name
    local definition = ItemDefinitions[itemName]

    if not definition or definition.Placeable ~= true then
        return
    end

    prompt.ObjectText = definition.DisplayName or itemName

    if prompt.Name == "CollectPrompt" then
        if definition.Plantable == true then
            prompt.ActionText = "Harvest"
            prompt.Enabled = object:GetAttribute("ReadyToHarvest") == true
        elseif definition.Recipes then
            local amount = getOutputAmount(object)
            prompt.ActionText = "Collect (" .. amount .. ")"
            prompt.Enabled = amount > 0
        end
        return
    end

    local selectedItemName, selectedAmount = getSelectedItem()

    if selectedItemName == "Shovel" and selectedAmount > 0 then
        prompt.ActionText = "Remove"
        prompt.Enabled = true
        return
    end

    if definition.BuildsInto then
        local construction = ConstructionDefinitions[itemName]
        local stage = object:GetAttribute("ConstructionStage") or 0
        local step = construction and construction.Stages and construction.Stages[stage + 1]
        if step then
            prompt.ActionText = "Build: " .. step.DisplayName
            prompt.Enabled = true
        end
        return
    end

    if definition.Plantable == true then
        local selectedDefinition = ItemDefinitions[selectedItemName]

        prompt.ActionText = "Plant"
        prompt.Enabled =
            object:GetAttribute("Occupied") ~= true and selectedAmount > 0 and selectedDefinition ~= nil and
                selectedDefinition.Type == "Seed"

    elseif definition.Recipes then
        prompt.ActionText = "Work"
        prompt.Enabled = true
    end
end

local function updateAllPrompts()
    for prompt in pairs(boundPrompts) do
        updatePrompt(prompt)
    end
end

local function bindPrompt(prompt)
    if not isSupportedPrompt(prompt) or boundPrompts[prompt] then
        return
    end

    local object = prompt:FindFirstAncestorOfClass("Model")

    if not object then
        return
    end

    local connections = {}
    boundPrompts[prompt] = connections

    local function refresh()
        updatePrompt(prompt)
    end

    table.insert(connections, object.AttributeChanged:Connect(refresh))

    local outputInventory = object:FindFirstChild("OutputInventory")

    if prompt.Name == "CollectPrompt" and outputInventory then
        local function watchItem(item)
            if item:IsA("IntValue") then
                table.insert(connections, item.Changed:Connect(refresh))
            end

            refresh()
        end

        for _, item in ipairs(outputInventory:GetChildren()) do
            watchItem(item)
        end

        table.insert(connections, outputInventory.ChildAdded:Connect(watchItem))

        table.insert(connections, outputInventory.ChildRemoved:Connect(refresh))
    end

    table.insert(connections, prompt.Destroying:Connect(function()
        boundPrompts[prompt] = nil

        for _, connection in ipairs(connections) do
            connection:Disconnect()
        end
    end))

    refresh()
end

player:GetAttributeChangedSignal("SelectedSlot"):Connect(updateAllPrompts)
player:GetAttributeChangedSignal("DataLoaded"):Connect(updateAllPrompts)

for i = 1, 6 do
    local slot = inventory:WaitForChild("Slot" .. i)

    slot:WaitForChild("ItemName").Changed:Connect(updateAllPrompts)
    slot:WaitForChild("Amount").Changed:Connect(updateAllPrompts)
end

plots.DescendantAdded:Connect(function(object)
    if isSupportedPrompt(object) then
        task.defer(bindPrompt, object)
    end
end)

for _, object in ipairs(plots:GetDescendants()) do
    if isSupportedPrompt(object) then
        bindPrompt(object)
    end
end
