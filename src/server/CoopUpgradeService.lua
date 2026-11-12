local HttpService = game:GetService("HttpService")
local ItemDefinitions = require(game:GetService("ReplicatedStorage").Configs.ItemDefinitions)
local InventoryService = require(script.Parent.InventoryService)
local AnimalService = require(script.Parent.AnimalService)
local CoopUpgradeService = {}

function CoopUpgradeService.Pack(player, object)
    local allowed, reason = AnimalService.CanUse(player, object)
    if not allowed then return false, reason end
    local slot = player.Inventory:FindFirstChild("Slot" .. (player:GetAttribute("SelectedSlot") or 1))
    local itemName = slot and slot.ItemName.Value
    local definition = ItemDefinitions[itemName]
    if not definition or definition.UpgradeFrom ~= (object:GetAttribute("ItemName") or object.Name) or
        slot.Amount.Value < 1 then return false, "Select the matching coop upgrade." end
    local contents, message = AnimalService.Snapshot(object)
    if not contents then return false, message end
    local data = HttpService:JSONEncode({Version = 1, ItemName = definition.PacksInto, Contents = contents})
    local exchanged, errorMessage = InventoryService.ExchangeForObject(player, {[itemName] = 1}, definition.PacksInto, data)
    if not exchanged then return false, errorMessage end
    object:Destroy()
    return true, "Coop packed. Select its renovation blueprint to place it."
end

function CoopUpgradeService.Prepare(player, object, itemName)
    local index = player:GetAttribute("SelectedSlot") or 1
    local slot = player.Inventory:FindFirstChild("Slot" .. index)
    local encoded = slot and slot:GetAttribute("ObjectData")
    if not slot or slot.ItemName.Value ~= itemName or slot.Amount.Value ~= 1 or typeof(encoded) ~= "string" then
        return false, "Select this packed coop first."
    end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, encoded)
    if not ok or typeof(data) ~= "table" or data.Version ~= 1 or data.ItemName ~= itemName or
        typeof(data.Contents) ~= "table" then return false, "Invalid packed coop." end
    local captured = data.Contents.CapturedAt
    local now = workspace:GetServerTimeNow()
    if typeof(captured) ~= "number" or captured ~= captured or captured < 0 or captured > now + 5 then
        return false, "Invalid packed coop time."
    end
    local restored, reason = AnimalService.Restore(object, data.Contents, math.max(0, now - captured))
    if not restored then return false, reason end
    return true, encoded, index
end

return CoopUpgradeService
