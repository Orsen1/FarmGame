local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))
local plots = workspace:WaitForChild("Plots")
local AnimalConfig = require(ReplicatedStorage.Configs.AnimalConfig)
local AnimalService = require(script.Parent.Parent.AnimalService)

local MAX_DISTANCE = 12

local ObjectRemovalService = {}

function ObjectRemovalService.remove(player, object)
    if player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true then
        return false, "Player data is not ready."
    end

    if typeof(object) ~= "Instance" or not object:IsA("Model") then
        return false, "Object no longer exists."
    end

    local plotName = player:GetAttribute("PlotName")
    local plot = plotName and plots:FindFirstChild(plotName)
    local objects = plot and plot:FindFirstChild("PlacedObjects")

    if not plot or not objects or plot:GetAttribute("OwnerUserId") ~= player.UserId or object.Parent ~= objects or
        object:GetAttribute("OwnerUserId") ~= player.UserId then
        return false, "You can only remove objects on your own farm."
    end

    local itemName = object:GetAttribute("ItemName") or object.Name
    local definition = ItemDefinitions[itemName]

    if not definition or definition.Placeable ~= true then
        return false, "This object cannot be removed."
    end

    local character = player.Character
    local tool = character and character:FindFirstChild("EquippedItem")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")

    local inventory = player:FindFirstChild("Inventory")
    local slotNumber = player:GetAttribute("SelectedSlot") or 1
    local slot = inventory and inventory:FindFirstChild("Slot" .. slotNumber)

    if not tool or not tool:IsA("Tool") or tool:GetAttribute("ItemName") ~= "Shovel" or not slot or slot.ItemName.Value ~=
        "Shovel" or slot.Amount.Value <= 0 then
        return false, "Equip your shovel first."
    end

    if not humanoid or humanoid.Health <= 0 or not root then
        return false, "Your character is not ready."
    end

    local prompt = object:FindFirstChild("ActionPrompt", true)
    local attachment = prompt and prompt.Parent

    if not prompt or not prompt:IsA("ProximityPrompt") or not attachment or not attachment:IsA("Attachment") then
        return false, " prompt is missing."
    end

    local distance = (root.Position - attachment.WorldPosition).Magnitude

    if distance ~= distance or distance > MAX_DISTANCE then
        return false, "Move closer to the object."
    end

    if AnimalConfig.Coops[itemName] then
        if definition.InstanceItem then return false, "Finish this renovation before removing the coop." end
        local released, message = AnimalService.Release(player, object)
        if not released then return false, message end
    end

    object:Destroy()

    return true, "Object removed."
end

return ObjectRemovalService
