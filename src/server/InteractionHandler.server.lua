local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))

local PlantService = require(script.Parent:WaitForChild("PlantService"))
local ProductionService = require(script.Parent:WaitForChild("ProductionService"))
local ConstructionService = require(script.Parent:WaitForChild("ConstructionService"))

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local command = remotes:WaitForChild("ProductionCommand")
local state = remotes:WaitForChild("ProductionState")
local plots = workspace:WaitForChild("Plots")

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

    if prompt.Name ~= "ActionPrompt" and prompt.Name ~= "CollectPrompt" then
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

    if definition.BuildsInto then
        local success, reason = ConstructionService.Build(player, object)
        if not success then
            warn("[CONSTRUCTION]", reason)
        end
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
