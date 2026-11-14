local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))

local PlantService = require(script.Parent:WaitForChild("PlantService"))
local ProductionService = require(script.Parent:WaitForChild("ProductionService"))
local ConstructionService = require(script.Parent:WaitForChild("ConstructionService"))
local AnimalService = require(script.Parent:WaitForChild("AnimalService"))
local AnimalConfig = require(ReplicatedStorage.Configs.AnimalConfig)
local CoopUpgradeService = require(script.Parent.CoopUpgradeService)
local InteractionConfig = require(ReplicatedStorage.Configs.InteractionConfig)

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local command = remotes:WaitForChild("ProductionCommand")
local state = remotes:WaitForChild("ProductionState")
local plots = workspace:WaitForChild("Plots")

local function configurePrompt(prompt)
    if not prompt:IsA("ProximityPrompt") then return end
    local object = prompt:FindFirstAncestorOfClass("Model")
    local definition = object and ItemDefinitions[object:GetAttribute("ItemName") or object.Name]
    if not definition or not definition.Placeable then return end
    local building = definition.Type == "Building" or definition.StorageSlots or
        AnimalConfig.Coops[object:GetAttribute("ItemName") or object.Name]
    local distance = definition.BuildsInto and InteractionConfig.ConstructionDistance or
        building and InteractionConfig.BuildingDistance or InteractionConfig.DefaultDistance
    prompt.MaxActivationDistance = math.min(prompt.MaxActivationDistance, distance)
    prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
end

plots.DescendantAdded:Connect(configurePrompt)
for _, prompt in ipairs(plots:GetDescendants()) do configurePrompt(prompt) end

local function getSelectedItem(player)
    local inventory = player:FindFirstChild("Inventory")
    local slotNumber = player:GetAttribute("SelectedSlot") or 1
    local slot = inventory and inventory:FindFirstChild("Slot" .. slotNumber)

    if not slot then
        return "", 0
    end

    return slot.ItemName.Value, slot.Amount.Value
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)

    if prompt.Name ~= "ActionPrompt" and prompt.Name ~= "CollectPrompt" and
        prompt.Name ~= "FeedPrompt" and prompt.Name ~= "EggPrompt" and prompt.Name ~= "CarePrompt" and prompt.Name ~= "TankPrompt" then
        return
    end

    if player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("ProductionMode") == true then
        return
    end

    local object = prompt:FindFirstAncestorOfClass("Model")
    local plotName = player:GetAttribute("PlotName")
    local plot = plotName and plots:FindFirstChild(plotName)
    local objects = plot and plot:FindFirstChild("PlacedObjects")

    if not object or not objects or object.Parent ~= objects or plot:GetAttribute("OwnerUserId") ~= player.UserId or
        object:GetAttribute("OwnerUserId") ~= player.UserId then
        return
    end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local attachment = prompt.Parent

    if not humanoid or humanoid.Health <= 0 or not root or not attachment or not attachment:IsA("Attachment") then
        return
    end

    local distance = (root.Position - attachment.WorldPosition).Magnitude

    if distance ~= distance or distance > prompt.MaxActivationDistance then
        return
    end

    local itemName = object:GetAttribute("ItemName") or object.Name
    local definition = ItemDefinitions[itemName]

    if not definition or definition.Placeable ~= true then
        return
    end

    if prompt.Name == "TankPrompt" then
        ProductionService.OpenTank(player, object)
        return
    end

    if prompt.Name == "CarePrompt" then
        local success, message = AnimalService.CleanHooves(player, object)
        remotes.AnimalFeedback:FireClient(player, object, success, message, "CarePrompt")
        return
    end

    if AnimalConfig.Coops[itemName] and (prompt.Name == "FeedPrompt" or prompt.Name == "EggPrompt") then
        local success, message
        if prompt.Name == "FeedPrompt" then success, message = AnimalService.Feed(player, object)
        else success, message = AnimalService.Collect(player, object) end
        remotes.AnimalFeedback:FireClient(player, object, success, message, prompt.Name)
        return
    end

    if prompt.Name == "CollectPrompt" then
        if definition.Plantable == true then
            PlantService.Harvest(player, object)

        elseif definition.Recipes then
            local success, reason = ProductionService.Collect(player, object)

            if not success then
                warn("[COLLECT]", reason)
            end
        end

        return
    end

    local selectedItemName, selectedAmount = getSelectedItem(player)
    local tool = character:FindFirstChild("EquippedItem")

    if selectedItemName == "Shovel" or (tool and tool:IsA("Tool") and tool:GetAttribute("ItemName") == "Shovel") then
        return
    end

    local home = AnimalConfig.Coops[itemName]
    if home and home.InteractionMenu then
        local success, message = AnimalService.OpenMenu(player, object)
        remotes.AnimalFeedback:FireClient(player, object, success, message, "HomeMenu")
        return
    end

    if definition.InteractionMenu then
        local success, message = ProductionService.OpenMenu(player, object)
        state:FireClient(player, "MenuOpened", {Station = object, Success = success, Message = message})
        return
    end

    local selectedDefinition = ItemDefinitions[selectedItemName]
    if selectedDefinition and selectedDefinition.UpgradeFrom == itemName then
        local success, message = CoopUpgradeService.Pack(player, object)
        remotes.AnimalFeedback:FireClient(player, object, success, message, "ActionPrompt")
        return
    end

    if home and selectedItemName == home.ItemName and selectedAmount > 0 then
        local success, message = AnimalService.Add(player, object)
        remotes.AnimalFeedback:FireClient(player, object, success, message, "ActionPrompt")
        return
    end

    if definition.ShopCategoryWhenEmpty then
        local home = AnimalConfig.Coops[itemName]
        if home and selectedItemName == home.ItemName and selectedAmount > 0 then
            local success, message = AnimalService.Add(player, object)
            remotes.AnimalFeedback:FireClient(player, object, success, message)
        elseif (object:GetAttribute("AnimalCount") or 0) == 0 then
            remotes.OpenBuyGuiEvent:FireClient(player, definition.ShopCategoryWhenEmpty)
        end
        return
    end

    if definition.BuildsInto then
        local success, reason = ConstructionService.Build(player, object)
        if not success then
            warn("[CONSTRUCTION]", reason)
        end
        return
    end

    if definition.Plantable and selectedItemName == "WateringCan" then
        PlantService.Water(player, object)
        return
    end

    if definition.Plantable == true then
        local seedDefinition = ItemDefinitions[selectedItemName]

        if selectedAmount > 0 and seedDefinition and seedDefinition.Type == "Seed" then
            PlantService.Plant(player, object, selectedItemName)
        end

    elseif definition.Recipes then
        local success, reason = ProductionService.Open(player, object)

        if not success and reason ~= "AlreadyOpen" then
            state:FireClient(player, "Error", {
                Message = reason
            })
        end
    end
end)

command.OnServerEvent:Connect(function(player, action, sessionId, value)
    if action == "Menu" and typeof(sessionId) == "Instance" and sessionId:IsA("Model") then
        if value ~= "Work" and value ~= "Collect" then return end
        local success, message = ProductionService.OpenMenu(player, sessionId)
        if success then
            if value == "Work" then success, message = ProductionService.Open(player, sessionId)
            else success, message = ProductionService.Collect(player, sessionId) end
        end
        state:FireClient(player, "MenuFeedback", {Station = sessionId, Success = success, Message = message or ""})
        return
    end
    if action == "Deposit" and typeof(sessionId) == "Instance" and sessionId:IsA("Model") then
        local definition = ItemDefinitions[sessionId:GetAttribute("ItemName") or sessionId.Name]
        if definition and definition.InteractionMenu then
            local allowed, reason = ProductionService.OpenMenu(player, sessionId)
            if not allowed then state:FireClient(player, "TankFeedback", {Station = sessionId, Success = false, Message = reason});return end
        end
        local success, message = ProductionService.Deposit(player, sessionId, value)
        state:FireClient(player, "TankFeedback", {Station = sessionId, Success = success, Message = message})
        return
    end
    if typeof(action) ~= "string" or typeof(sessionId) ~= "number" or sessionId ~=
        ProductionService.GetSessionId(player) then
        return
    end

    if action == "Close" then
        ProductionService.Close(player, "Exit")
        return
    end

    if action == "Hold" and value == false then
        ProductionService.SetHeld(player, sessionId, false)
        return
    end

    if action == "Select" and (value == nil or typeof(value) == "string") then
        ProductionService.Select(player, sessionId, value)

    elseif action == "Hold" and value == true then
        ProductionService.SetHeld(player, sessionId, true)
    end
end)
