local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))
local BedConfig = require(ReplicatedStorage.Configs.GardenBedConfig)
local ConstructionDefinitions = require(ReplicatedStorage:WaitForChild("Configs")
    :WaitForChild("ConstructionDefinitions"))

local ConstructionPromptView = require(script.Parent:WaitForChild("ConstructionPromptView"))
local AnimalShopPromptView = require(script.Parent:WaitForChild("AnimalShopPromptView"))
local AnimalConfig = require(ReplicatedStorage.Configs.AnimalConfig)
local CropConfig = require(ReplicatedStorage.Configs.CropConfig)
local InteractionConfig = require(ReplicatedStorage.Configs.InteractionConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local inventory = player:WaitForChild("Inventory")
local plots = workspace:WaitForChild("Plots")

local boundPrompts = {}
local promptViews = {}
local eligible = {}
local focusedObject
local focusOutline = Instance.new("Highlight")
focusOutline.Name = "InteractionFocus"
focusOutline.FillTransparency = 1
focusOutline.OutlineColor = Color3.fromRGB(244, 204, 121)
focusOutline.OutlineTransparency = 0.35
focusOutline.Enabled = false
focusOutline.Parent = workspace

local function setEnabled(prompt, available)
    eligible[prompt] = available == true
    prompt.Enabled = available == true and ProximityPromptService.Enabled and
        focusedObject == prompt:FindFirstAncestorOfClass("Model")
end

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
               (object.Name == "FarmStandPrompt" or object.Name == "ActionPrompt" or object.Name == "CollectPrompt" or
                   object.Name == "StoragePrompt" or object.Name == "ReturnsPrompt" or object.Name == "WarehouseBuyPrompt" or
                   object.Name == "FeedPrompt" or object.Name == "EggPrompt" or object.Name == "CarePrompt" or object.Name == "TankPrompt")
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
        player:GetAttribute("FeederOpen") == true or player:GetAttribute("AnimalMenuOpen") == true or
        player:GetAttribute("LaboratoryOpen") == true or
        object:GetAttribute("OwnerUserId") ~= player.UserId then
        setEnabled(prompt, false)
        hidePrompt(prompt)
        return
    end

    if prompt.Name == "FarmStandPrompt" then
        setEnabled(prompt, true)
        return
    end
    local itemName = object:GetAttribute("ItemName") or object.Name
    local definition = ItemDefinitions[itemName]

    if not definition or not (definition.Placeable or definition.PermanentHouse or definition.FixedWarehouse) then
        setEnabled(prompt, false)
        hidePrompt(prompt)
        return
    end

    prompt.ObjectText = definition.DisplayName or itemName
    if definition.PermanentHouse then
        prompt.Style = Enum.ProximityPromptStyle.Custom
        prompt.ActionText = "Open home"
        prompt:SetAttribute("Compact", true)
        prompt:SetAttribute("Icon", definition.Icon)
        setEnabled(prompt, player:GetAttribute("ProductionMode") ~= true and player:GetAttribute("Milking") ~= true)
        if not prompt.Enabled then hidePrompt(prompt)
        elseif promptViews[prompt] then promptViews[prompt].update() end
        return
    end
    local home = AnimalConfig.Coops[itemName]
    if home and home.InteractionMenu or definition.InteractionMenu or definition.Laboratory then
        local selected = getSelectedItem()
        if selected ~= "Shovel" then
            if prompt.Name ~= "ActionPrompt" then setEnabled(prompt, false);hidePrompt(prompt);return end
            if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
                setEnabled(prompt, false)
                hidePrompt(prompt)
                prompt.Style = Enum.ProximityPromptStyle.Custom
            end
            prompt.ActionText = "Open"
            prompt:SetAttribute("Compact", true)
            prompt:SetAttribute("Icon", definition.Icon or home and ItemDefinitions[home.ItemName].Icon or "")
            prompt:SetAttribute("Context", definition.DisplayName)
            setEnabled(prompt, player:GetAttribute("ProductionMode") ~= true and player:GetAttribute("Milking") ~= true)
            if not prompt.Enabled then hidePrompt(prompt)
            elseif promptViews[prompt] then promptViews[prompt].update() end
            return
        end
        prompt:SetAttribute("Compact", nil)
    end
    if definition.AutomaticProduction then
        prompt:SetAttribute("PairedPrompt", prompt.Name == "CollectPrompt" and "ActionPrompt" or "CollectPrompt")
        prompt:SetAttribute("StackSide", prompt.Name == "CollectPrompt" and 1 or -1)
        prompt:SetAttribute("Icon", definition.Icon)
        prompt:SetAttribute("Context", prompt.Name == "CollectPrompt" and "Ready to collect" or "Dairy workshop")
    end

    if prompt.Name == "TankPrompt" then
        local selected = getSelectedItem()
        setEnabled(prompt, definition.MilkTank ~= nil and selected ~= "Shovel" and player:GetAttribute("ProductionMode") ~= true)
        prompt.ActionText = "Fill milk tank"
        prompt:SetAttribute("Context", string.format("Milk: %d / %d", object:GetAttribute("MilkStock") or 0, definition.MilkTank.Capacity))
        if not prompt.Enabled then hidePrompt(prompt)
        elseif promptViews[prompt] then promptViews[prompt].update() end
        return
    end

    if prompt.Name == "CarePrompt" then
        local home = AnimalConfig.Coops[itemName]
        local selected = getSelectedItem()
        setEnabled(prompt, home ~= nil and home.HoofCare ~= nil and (object:GetAttribute("AnimalCount") or 0) > 0 and
            object:GetAttribute("AnimalBusy") ~= true and selected ~= "Shovel" and selected ~= home.ItemName and
            player:GetAttribute("ProductionMode") ~= true)
        prompt.ActionText = "Clean hooves"
        prompt:SetAttribute("Context", "Ready for a little spa?")
        prompt:SetAttribute("Icon", definition.Icon)
        if not prompt.Enabled then hidePrompt(prompt)
        elseif promptViews[prompt] then promptViews[prompt].update() end
        return
    end

    if prompt.Name == "FeedPrompt" or prompt.Name == "EggPrompt" then
        local home = AnimalConfig.Coops[itemName]
        if not home then setEnabled(prompt, false);hidePrompt(prompt);return end
        local selectedItemName = getSelectedItem()
        local selected = ItemDefinitions[selectedItemName]
        local caring = (not selected or selected.UpgradeFrom ~= itemName) and
            (not definition.BuildsInto or selectedItemName == home.FeedItem or selectedItemName == home.EggItem) and
            not (home.Milking and selectedItemName == home.Milking.BucketItem)
        local amount = getOutputAmount(object)
        local hungry = (object:GetAttribute("HungryCount") or 0) > 0
        local refilling = home.FeedCapacity > 0 and selectedItemName == home.FeedItem and
            (object:GetAttribute("FeedStock") or 0) < home.FeedCapacity
        setEnabled(prompt, selectedItemName ~= home.ItemName and selectedItemName ~= "Shovel" and
            player:GetAttribute("ProductionMode") ~= true and caring and
            (prompt.Name == "FeedPrompt" and (hungry or refilling) or
                prompt.Name == "EggPrompt" and amount > 0))
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

    if prompt.Name == "WarehouseBuyPrompt" then
        prompt.ActionText = "Buy blueprint"
        prompt:SetAttribute("Context", string.format("Warehouse  $%.2f", definition.SitePriceCents / 100))
        prompt:SetAttribute("Icon", definition.Icon)
        setEnabled(prompt, true)
        if not prompt.Enabled then hidePrompt(prompt)
        elseif promptViews[prompt] then promptViews[prompt].update() end
        return
    end

    if prompt.Name == "StoragePrompt" or prompt.Name == "ReturnsPrompt" then
        local returning = prompt.Name == "ReturnsPrompt"
        prompt.ActionText = returning and "Open returns" or "Open warehouse"
        prompt:SetAttribute("Compact", true)
        prompt:SetAttribute("Icon", definition.Icon)
        if returning then prompt:SetAttribute("StackSide", 1) end
        setEnabled(prompt, definition.FixedWarehouse == true and
            (not returning or (player:GetAttribute("StorageReturnCount") or 0) > 0))
        if not prompt.Enabled then hidePrompt(prompt)
        elseif promptViews[prompt] then promptViews[prompt].update() end
        return
    end

    if prompt.Name == "CollectPrompt" then
        if definition.Plantable == true then
            prompt.ActionText = "Harvest"
            local step = player:GetAttribute("TutorialStep")
            setEnabled(prompt, object:GetAttribute("ReadyToHarvest") == true and (step == nil or step == "Complete" or step == "Harvest"))
        elseif definition.Recipes then
            local amount = getOutputAmount(object)
            prompt.ActionText = "Collect (" .. amount .. ")"
            setEnabled(prompt, amount > 0)
        else
            setEnabled(prompt, false)
        end
        return
    end

    local selectedItemName, selectedAmount = getSelectedItem()

    local removing = selectedItemName == "Shovel" and selectedAmount > 0 and not definition.FixedWarehouse
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
        setEnabled(prompt, player:GetAttribute("ProductionMode") ~= true)
        if promptViews[prompt] then promptViews[prompt].update() end
        return
    end
    if definition.BuildsInto then
        if removing then setEnabled(prompt, false);hidePrompt(prompt);return end
        local step = getConstructionStep(object, itemName)
        local custom = step ~= nil and step ~= false
        local style = custom and Enum.ProximityPromptStyle.Custom or Enum.ProximityPromptStyle.Default
        if prompt.Style ~= style then
            setEnabled(prompt, false)
            hidePrompt(prompt)
            prompt.Style = style
        end

        prompt.ActionText = "Add Materials"
        local caring = home and (selectedItemName == home.FeedItem or selectedItemName == home.EggItem)
        setEnabled(prompt, custom and not caring and player:GetAttribute("ProductionMode") ~= true)
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
            setEnabled(prompt, false)
            hidePrompt(prompt)
            prompt.Style = style
        end
        local home = AnimalConfig.Coops[itemName]
        local count = object:GetAttribute("AnimalCount") or 0
        local adding = home and selectedItemName == home.ItemName and selectedAmount > 0
        prompt.ActionText = removing and "Remove" or adding and
            (count < home.Capacity and "Add " .. home.ItemName:lower() or "Home full") or definition.ShopPromptText
        prompt:SetAttribute("Context", home and string.format("%s: %d / %d", home.PluralName, count, home.Capacity) or prompt.ObjectText)
        setEnabled(prompt, removing or ((adding or count == 0) and player:GetAttribute("ProductionMode") ~= true))
        if not prompt.Enabled then hidePrompt(prompt)
        elseif promptViews[prompt] then promptViews[prompt].update() end
        return
    end

    if definition.Plantable then
        local style = selectedItemName == "WateringCan" and Enum.ProximityPromptStyle.Custom or Enum.ProximityPromptStyle.Default
        if prompt.Style ~= style then
            setEnabled(prompt, false)
            hidePrompt(prompt)
            prompt.Style = style
        end
    end

    if removing then
        prompt.ActionText = "Remove"
        setEnabled(prompt, true)
        return
    end

    if definition.Plantable == true then
        local selectedDefinition = ItemDefinitions[selectedItemName]

        if selectedItemName == "WateringCan" then
            prompt.ActionText = "Water crops"
            prompt:SetAttribute("Icon", ItemDefinitions.WateringCan.Icon)
            prompt:SetAttribute("Context", string.format("+%d%% growth speed", math.round((CropConfig.WateringGrowthMultiplier - 1) * 100)))
            setEnabled(prompt, selectedAmount > 0 and object:GetAttribute("CanWater") == true)
            if not prompt.Enabled then hidePrompt(prompt)
            elseif promptViews[prompt] then promptViews[prompt].update() end
            return
        end
        local planted = object:GetAttribute("PlantedCount") or 0
        local capacity = object:GetAttribute("PlantingCapacity") or definition.PlantingCapacity
        local crop = ItemDefinitions[object:GetAttribute("PlantType")]
        local amount = capacity and math.min(capacity - planted, selectedAmount) or 0
        prompt.ActionText = amount > 0 and (planted > 0 and "Add " or "Plant ") .. amount or "Plant"
        if capacity then
            prompt.ObjectText = string.format("%s  %d/%d", crop and crop.DisplayName or definition.DisplayName, planted, capacity)
        end
        local step = player:GetAttribute("TutorialStep") or "Complete"
        if not selectedDefinition or selectedDefinition.Type ~= "Seed" then
            local bed = BedConfig.Types[itemName]
            prompt.ActionText = "Expand bed"
            setEnabled(prompt, step == "Complete" and bed ~= nil and bed.UpgradePrices[object:GetAttribute("BedLevel") or 1] ~= nil)
            return
        end
        setEnabled(prompt,
            amount > 0 and selectedDefinition ~= nil and selectedDefinition.Type == "Seed" and
                (not crop or selectedDefinition.PlantId == object:GetAttribute("PlantType")) and (step == "Complete" or
                    step ~= "Sell" and selectedItemName == player:GetAttribute("TutorialSeedItem")))

    elseif definition.Recipes then
        prompt.ActionText = "Work"
        setEnabled(prompt, true)
    else
        setEnabled(prompt, false)
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
        eligible[prompt] = nil

        for _, connection in ipairs(connections) do
            connection:Disconnect()
        end
    end))

    refresh()
end

ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
    local warehouse = prompt.Name == "StoragePrompt" or prompt.Name == "ReturnsPrompt" or prompt.Name == "WarehouseBuyPrompt"
    if not boundPrompts[prompt] or (not warehouse and prompt.Name ~= "FarmStandPrompt" and prompt.Name ~= "ActionPrompt" and
        prompt.Name ~= "FeedPrompt" and prompt.Name ~= "EggPrompt" and prompt.Name ~= "CarePrompt" and
        prompt.Name ~= "TankPrompt" and prompt.Name ~= "CollectPrompt") or
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
    if not warehouse and prompt.Name ~= "FarmStandPrompt" and not step and not (definition and (definition.PermanentHouse or definition.Plantable or definition.ShopCategoryWhenEmpty or definition.Laboratory or AnimalConfig.Coops[itemName] or definition.AutomaticProduction)) then return end
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
player:GetAttributeChangedSignal("StorageReturnCount"):Connect(updateAllPrompts)
player:GetAttributeChangedSignal("FeederOpen"):Connect(updateAllPrompts)
player:GetAttributeChangedSignal("AnimalMenuOpen"):Connect(updateAllPrompts)
player:GetAttributeChangedSignal("LaboratoryOpen"):Connect(updateAllPrompts)

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

local focusElapsed = 0
RunService.Heartbeat:Connect(function(dt)
    focusElapsed += dt
    if focusElapsed < InteractionConfig.FocusInterval then return end
    focusElapsed = 0
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local camera = workspace.CurrentCamera
    local shop = playerGui:FindFirstChild("BuyGui")
    local sell = playerGui:FindFirstChild("FarmStandGui")
    local blocked = not root or not humanoid or humanoid.Health <= 0 or not camera or not ProximityPromptService.Enabled or
        player:GetAttribute("AnimalMenuOpen") == true or player:GetAttribute("StorageOpen") == true or
        player:GetAttribute("FeederOpen") == true or player:GetAttribute("ProductionMode") == true or
        player:GetAttribute("Milking") == true or player:GetAttribute("LaboratoryOpen") == true or
        player:GetAttribute("BedUpgradeOpen") == true or
        (shop and shop.Enabled and shop.MainFrame.Visible) or (sell and sell.Enabled and sell.MainFrame.Visible)
    local scores = {}
    if not blocked then
        for prompt, available in pairs(eligible) do
            local attachment = prompt.Parent
            local object = prompt:FindFirstAncestorOfClass("Model")
            if available and object and attachment and attachment:IsA("Attachment") then
                local distance = (root.Position - attachment.WorldPosition).Magnitude
                local direction = attachment.WorldPosition - camera.CFrame.Position
                local _, visible = camera:WorldToViewportPoint(attachment.WorldPosition)
                if visible and distance <= prompt.MaxActivationDistance then
                    local alignment = direction.Magnitude > 0.01 and camera.CFrame.LookVector:Dot(direction.Unit) or 1
                    local score = distance + (1 - alignment) * 0.75
                    scores[object] = math.min(scores[object] or math.huge, score)
                end
            end
        end
    end
    local best, bestScore
    for object, score in pairs(scores) do
        if not bestScore or score < bestScore then best, bestScore = object, score end
    end
    if focusedObject and scores[focusedObject] and best and
        scores[focusedObject] <= bestScore + InteractionConfig.FocusSwitchMargin then best = focusedObject end
    focusedObject = best
    focusOutline.Adornee = best
    focusOutline.Enabled = best ~= nil
    for prompt, available in pairs(eligible) do
        local enabled = not blocked and available and prompt:FindFirstAncestorOfClass("Model") == best
        if prompt.Enabled ~= enabled then prompt.Enabled = enabled end
        if not enabled then hidePrompt(prompt) end
    end
end)

script.Destroying:Connect(function() focusOutline:Destroy() end)


player:GetAttributeChangedSignal("TutorialStep"):Connect(updateAllPrompts)
