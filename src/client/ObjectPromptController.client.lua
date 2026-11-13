local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))
local ConstructionDefinitions = require(ReplicatedStorage:WaitForChild("Configs")
    :WaitForChild("ConstructionDefinitions"))

local ConstructionPromptView = require(script.Parent:WaitForChild("ConstructionPromptView"))
local AnimalShopPromptView = require(script.Parent:WaitForChild("AnimalShopPromptView"))
local AnimalConfig = require(ReplicatedStorage.Configs.AnimalConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local inventory = player:WaitForChild("Inventory")
local plots = workspace:WaitForChild("Plots")

local boundPrompts = {}
local promptViews = {}

local function hidePrompt(prompt)
    local view = promptViews[prompt]
    if not view then return end
    promptViews[prompt] = nil
    view.destroy()
end

local function getConstructionStep(object, itemName)
    local definition = ConstructionDefinitions[itemName]
    local stage = object:GetAttribute("ConstructionStage") or 0
    return definition and typeof(stage) == "number" and definition.Stages[stage + 1]
end

local function isSupportedPrompt(object)
    return object:IsA("ProximityPrompt") and
               (object.Name == "ActionPrompt" or object.Name == "CollectPrompt" or object.Name == "StoragePrompt" or
                   object.Name == "FeedPrompt" or object.Name == "EggPrompt")
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
        player:GetAttribute("FeederOpen") == true or
        object:GetAttribute("OwnerUserId") ~= player.UserId then
        prompt.Enabled = false
        hidePrompt(prompt)
        return
    end

    local itemName = object:GetAttribute("ItemName") or object.Name
    local definition = ItemDefinitions[itemName]

    if not definition or definition.Placeable ~= true then
        prompt.Enabled = false
        hidePrompt(prompt)
        return
    end

    prompt.ObjectText = definition.DisplayName or itemName

    if prompt.Name == "FeedPrompt" or prompt.Name == "EggPrompt" then
        local home = AnimalConfig.Coops[itemName]
        if not home then prompt.Enabled = false;hidePrompt(prompt);return end
        local selectedItemName = getSelectedItem()
        local selected = ItemDefinitions[selectedItemName]
        local caring = (not selected or selected.UpgradeFrom ~= itemName) and
            (not definition.BuildsInto or selectedItemName == home.FeedItem or selectedItemName == home.EggItem)
        local amount = getOutputAmount(object)
        local hungry = (object:GetAttribute("HungryCount") or 0) > 0
        local refilling = home.FeedCapacity > 0 and selectedItemName == home.FeedItem and
            (object:GetAttribute("FeedStock") or 0) < home.FeedCapacity
        prompt.Enabled = selectedItemName ~= home.ItemName and selectedItemName ~= "Shovel" and
            player:GetAttribute("ProductionMode") ~= true and caring and
            (prompt.Name == "FeedPrompt" and (hungry or refilling) or
                prompt.Name == "EggPrompt" and amount > 0)
        if prompt.Name == "FeedPrompt" then
            local wheat = 0
            for _, slot in ipairs(inventory:GetChildren()) do
                if slot.ItemName.Value == home.FeedItem then wheat += slot.Amount.Value end
            end
            prompt.ActionText = home.FeedCapacity > 0 and "Fill feeder" or "Feed 1 wheat"
            prompt:SetAttribute("Context", string.format("Hungry: %d | Wheat: %d", object:GetAttribute("HungryCount") or 0, wheat))
        else
            prompt.ActionText = "Collect eggs"
            prompt:SetAttribute("Context", string.format("Eggs ready: %d / %d", amount, home.EggCapacity))
        end
        if not prompt.Enabled then hidePrompt(prompt)
        elseif promptViews[prompt] then promptViews[prompt].update() end
        return
    end

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
    local home = AnimalConfig.Coops[itemName]
    local selectedDefinition = ItemDefinitions[selectedItemName]
    local upgrading = selectedDefinition and selectedDefinition.UpgradeFrom == itemName and selectedAmount > 0
    local adding = home and selectedItemName == home.ItemName and selectedAmount > 0
    prompt:SetAttribute("CareAction", adding or upgrading or false)
    if home and (adding or upgrading) and not removing then
        if prompt.Style ~= Enum.ProximityPromptStyle.Custom then hidePrompt(prompt);prompt.Style = Enum.ProximityPromptStyle.Custom end
        local count = object:GetAttribute("AnimalCount") or 0
        prompt.ActionText = upgrading and "Pack for upgrade" or count < home.Capacity and
            "Add " .. (ItemDefinitions[home.ItemName].DisplayName or home.ItemName):lower() or "Home full"
        prompt:SetAttribute("Context", upgrading and "Coop I to II" or string.format("%s: %d / %d", home.PluralName, count, home.Capacity))
        prompt.Enabled = player:GetAttribute("ProductionMode") ~= true
        if promptViews[prompt] then promptViews[prompt].update() end
        return
    end
    if definition.BuildsInto then
        local step = getConstructionStep(object, itemName)
        local custom = step ~= nil and step ~= false and not removing
        local style = custom and Enum.ProximityPromptStyle.Custom or Enum.ProximityPromptStyle.Default
        if prompt.Style ~= style then
            prompt.Enabled = false
            hidePrompt(prompt)
            prompt.Style = style
        end

        prompt.ActionText = removing and "Remove" or "Add Materials"
        local caring = home and (selectedItemName == home.FeedItem or selectedItemName == home.EggItem)
        prompt.Enabled = removing or (custom and not caring and player:GetAttribute("ProductionMode") ~= true)
        if promptViews[prompt] then
            if prompt.Enabled and custom then
                promptViews[prompt].update()
            else
                hidePrompt(prompt)
            end
        end
        return
    end

    if definition.ShopCategoryWhenEmpty then
        local style = removing and Enum.ProximityPromptStyle.Default or Enum.ProximityPromptStyle.Custom
        if prompt.Style ~= style then
            prompt.Enabled = false
            hidePrompt(prompt)
            prompt.Style = style
        end
        local home = AnimalConfig.Coops[itemName]
        local count = object:GetAttribute("AnimalCount") or 0
        local adding = home and selectedItemName == home.ItemName and selectedAmount > 0
        prompt.ActionText = removing and "Remove" or adding and
            (count < home.Capacity and "Add " .. home.ItemName:lower() or "Home full") or definition.ShopPromptText
        prompt:SetAttribute("Context", home and string.format("%s: %d / %d", home.PluralName, count, home.Capacity) or prompt.ObjectText)
        prompt.Enabled = removing or ((adding or count == 0) and player:GetAttribute("ProductionMode") ~= true)
        if not prompt.Enabled then hidePrompt(prompt)
        elseif promptViews[prompt] then promptViews[prompt].update() end
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

    if prompt.Name == "CollectPrompt" or prompt.Name == "EggPrompt" then
        local function watchItem(item)
            if item:IsA("IntValue") then
                table.insert(connections, item.Changed:Connect(refresh))
            end

            refresh()
        end

        local watched = {}
        local function watchOutput(folder)
            if folder.Name ~= "OutputInventory" or watched[folder] then return end
            watched[folder] = true
            table.insert(connections, folder.ChildAdded:Connect(watchItem))
            table.insert(connections, folder.ChildRemoved:Connect(refresh))
            for _, item in ipairs(folder:GetChildren()) do watchItem(item) end
            refresh()
        end
        table.insert(connections, object.ChildAdded:Connect(watchOutput))
        if outputInventory then watchOutput(outputInventory) end
    end

    table.insert(connections, prompt.Destroying:Connect(function()
        hidePrompt(prompt)
        boundPrompts[prompt] = nil

        for _, connection in ipairs(connections) do
            connection:Disconnect()
        end
    end))

    refresh()
end

ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
    if not boundPrompts[prompt] or (prompt.Name ~= "ActionPrompt" and prompt.Name ~= "FeedPrompt" and prompt.Name ~= "EggPrompt") or
        prompt.Style ~= Enum.ProximityPromptStyle.Custom or not prompt.Enabled then
        return
    end
    local object = prompt:FindFirstAncestorOfClass("Model")
    if not object or object:GetAttribute("OwnerUserId") ~= player.UserId then
        return
    end
    local itemName = object:GetAttribute("ItemName") or object.Name
    local step = getConstructionStep(object, itemName)
    if prompt.Name ~= "ActionPrompt" or prompt:GetAttribute("CareAction") then step = nil end
    local definition = ItemDefinitions[itemName]
    if not step and not (definition and (definition.ShopCategoryWhenEmpty or AnimalConfig.Coops[itemName])) then return end
    hidePrompt(prompt)
    if step then
        promptViews[prompt] = ConstructionPromptView.show(playerGui, prompt, object, step, ItemDefinitions, inputType)
    else
        promptViews[prompt] = AnimalShopPromptView.show(playerGui, prompt, inputType)
    end
end)
ProximityPromptService.PromptHidden:Connect(hidePrompt)
ReplicatedStorage.RemoteEvents.AnimalFeedback.OnClientEvent:Connect(function(object, success, message, promptName)
    if message == "OpenFeeder" then return end
    for prompt, view in pairs(promptViews) do
        if prompt:FindFirstAncestorOfClass("Model") == object and view.message and
            prompt.Name == (promptName or "ActionPrompt") then view.message(message, success) end
    end
end)

player:GetAttributeChangedSignal("ProductionMode"):Connect(updateAllPrompts)
player:GetAttributeChangedSignal("SelectedSlot"):Connect(updateAllPrompts)
player:GetAttributeChangedSignal("DataLoaded"):Connect(updateAllPrompts)
player:GetAttributeChangedSignal("StorageOpen"):Connect(updateAllPrompts)
player:GetAttributeChangedSignal("FeederOpen"):Connect(updateAllPrompts)

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
