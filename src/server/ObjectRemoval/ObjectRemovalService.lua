local Players = game:GetService("Players")
local services = script.Parent.Parent
local PlantService = require(services.PlantService)
local Journal = require(services.FarmJournalService)

local ObjectRemovalService = {}

function ObjectRemovalService.remove(player, object)
    if player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("Teleporting")
        or player:GetAttribute("ProductionMode") or player:GetAttribute("Milking") then
        return false, "Your farm is unavailable."
    end
    if not Journal.TutorialComplete(player) then return false, "Finish the tutorial before clearing crops." end

    local character = player.Character
    local tool = character and character:FindFirstChild("EquippedItem")
    local inventory = player:FindFirstChild("Inventory")
    local slotNumber = player:GetAttribute("SelectedSlot") or 1
    local slot = inventory and inventory:FindFirstChild("Slot" .. slotNumber)

    if not tool or not tool:IsA("Tool") or tool:GetAttribute("ItemName") ~= "Shovel" or not slot
        or slot.ItemName.Value ~= "Shovel" or slot.Amount.Value <= 0 then
        return false, "Equip your shovel first."
    end

    return PlantService.Clear(player, object)
end

return ObjectRemovalService
