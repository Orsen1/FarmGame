local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))
local tools = ReplicatedStorage:WaitForChild("Tools")

local EquipmentService = {}

function EquipmentService.update(player)
    local character = player.Character
    if not character then
        return
    end

    local slotNumber = player:GetAttribute("SelectedSlot") or 1
    local inventory = player:FindFirstChild("Inventory")
    local slot = inventory and inventory:FindFirstChild("Slot" .. slotNumber)

    local itemName = ""

    if player:GetAttribute("DataLoaded") == true and slot and slot.Amount.Value > 0 then
        itemName = slot.ItemName.Value
    end

    local definition = ItemDefinitions[itemName]

    local template = definition and definition.Type == "Tool" and tools:FindFirstChild(itemName)

    if template and not template:IsA("Tool") then
        template = nil
    end

    local equipped = character:FindFirstChild("EquippedItem")

    if template and equipped and equipped:IsA("Tool") and equipped:GetAttribute("ItemName") == itemName then
        return
    end

    if equipped then
        equipped:Destroy()
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")

    if not template or not humanoid or humanoid.Health <= 0 then
        return
    end

    local tool = template:Clone()
    tool.Name = "EquippedItem"
    tool.CanBeDropped = false
    tool:SetAttribute("ItemName", itemName)
    local handle = tool:FindFirstChild("Handle")

    if not handle or not handle:IsA("BasePart") then
        warn("[EQUIPMENT] Handle missing:", itemName)
        tool:Destroy()
        return
    end

    for _, object in ipairs(tool:GetDescendants()) do
        if object:IsA("WeldConstraint") then
            object:Destroy()
        end
    end

    for _, part in ipairs(tool:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = false
            part.CanCollide = false
            part.CanTouch = false
            part.Massless = true

            if part ~= handle then
                local weld = Instance.new("WeldConstraint")
                weld.Name = "HandleWeld"
                weld.Part0 = handle
                weld.Part1 = part
                weld.Enabled = true
                weld.Parent = part
            end
        end
    end

    tool.Parent = character
end

return EquipmentService
