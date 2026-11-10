local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))
local ConstructionDefinitions = require(ReplicatedStorage:WaitForChild("Configs")
    :WaitForChild("ConstructionDefinitions"))

local ConstructionPromptView = require(script.Parent:WaitForChild("ConstructionPromptView"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local inventory = player:WaitForChild("Inventory")
local plots = workspace:WaitForChild("Plots")

local boundPrompts = {}
local activePrompt
local constructionView

local function hideConstructionPrompt(prompt)
    if prompt ~= activePrompt or not constructionView then
        return
    end

    local view = constructionView
    activePrompt = nil
    constructionView = nil
    view.destroy()
end

local function getConstructionStep(object, itemName)
    local definition = ConstructionDefinitions[itemName]
    local stage = object:GetAttribute("ConstructionStage") or 0
    return definition and typeof(stage) == "number" and definition.Stages[stage + 1]
end

local function isSupportedPrompt(object)
    return object:IsA("ProximityPrompt") and
               (object.Name == "ActionPrompt" or object.Name == "CollectPrompt" or object.Name == "StoragePrompt")
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
    if not object or player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("StorageOpen") == true or
        object:GetAttribute("OwnerUserId") ~= player.UserId then
        prompt.Enabled = false
        hideConstructionPrompt(prompt)
        return
    end

    local itemName = object:GetAttribute("ItemName") or object.Name
    local definition = ItemDefinitions[itemName]

    if not definition or definition.Placeable ~= true then
        prompt.Enabled = false
        hideConstructionPrompt(prompt)
        return
    end

    prompt.ObjectText = definition.DisplayName or itemName

    if prompt.Name == "StoragePrompt" then
        local selectedItemName, selectedAmount = getSelectedItem()

        prompt.ActionText = "Открыть"
        prompt.Enabled = typeof(definition.StorageSlots) == "number" and definition.StorageSlots > 0 and
                             not (selectedItemName == "Shovel" and selectedAmount > 0)

        return
    end

    if prompt.Name == "CollectPrompt" then
        if definition.Plantable == true then
            prompt.ActionText = "Harvest"
            prompt.Enabled = object:GetAttribute("ReadyToHarvest") == true
        elseif definition.Recipes then
            local amount = getOutputAmount(object)
            prompt.ActionText = "Collect (" .. amount .. ")"
            prompt.Enabled = amount > 0
        else
            prompt.Enabled = false
        end
        return
    end

    local selectedItemName, selectedAmount = getSelectedItem()

    local removing = selectedItemName == "Shovel" and selectedAmount > 0
    if definition.BuildsInto then
        local step = getConstructionStep(object, itemName)
        local custom = step ~= nil and step ~= false and not removing
        local style = custom and Enum.ProximityPromptStyle.Custom or Enum.ProximityPromptStyle.Default
        if prompt.Style ~= style then
            prompt.Enabled = false
            hideConstructionPrompt(prompt)
            prompt.Style = style
        end

        prompt.ActionText = removing and "Remove" or "Add Materials"
        prompt.Enabled = removing or (custom and player:GetAttribute("ProductionMode") ~= true)
        if prompt == activePrompt and constructionView then
            if prompt.Enabled and custom then
                constructionView.update()
            else
                hideConstructionPrompt(prompt)
            end
        end
        return
    end

    if removing then
        prompt.ActionText = "Remove"
        prompt.Enabled = true
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
    else
        prompt.Enabled = false
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
        hideConstructionPrompt(prompt)
        boundPrompts[prompt] = nil

        for _, connection in ipairs(connections) do
            connection:Disconnect()
        end
    end))

    refresh()
end

ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
    if not boundPrompts[prompt] or prompt.Name ~= "ActionPrompt" or
        prompt.Style ~= Enum.ProximityPromptStyle.Custom or not prompt.Enabled then
        return
    end
    local object = prompt:FindFirstAncestorOfClass("Model")
    if not object or object:GetAttribute("OwnerUserId") ~= player.UserId then
        return
    end
    local itemName = object:GetAttribute("ItemName") or object.Name
    local step = getConstructionStep(object, itemName)
    if not step then
        return
    end
    hideConstructionPrompt(activePrompt)
    constructionView = ConstructionPromptView.show(playerGui, prompt, object, step, ItemDefinitions, inputType)
    activePrompt = prompt
end)
ProximityPromptService.PromptHidden:Connect(hideConstructionPrompt)

player:GetAttributeChangedSignal("ProductionMode"):Connect(updateAllPrompts)
player:GetAttributeChangedSignal("SelectedSlot"):Connect(updateAllPrompts)
player:GetAttributeChangedSignal("DataLoaded"):Connect(updateAllPrompts)
player:GetAttributeChangedSignal("StorageOpen"):Connect(updateAllPrompts)

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
