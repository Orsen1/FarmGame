local HttpService = game:GetService("HttpService")
local ItemDefinitions = require(game:GetService("ReplicatedStorage").Configs.ItemDefinitions)
local InventoryService = require(script.Parent.InventoryService)
local AnimalService = require(script.Parent.AnimalService)
local Journal = require(script.Parent.FarmJournalService)
local CoopUpgradeService = {}

function CoopUpgradeService.Pack(player, object, upgradeItemName)
    local allowed, reason = AnimalService.CanUse(player, object)
    if not allowed then return false, reason end
    local slot = player.Inventory:FindFirstChild("Slot" .. (player:GetAttribute("SelectedSlot") or 1))
    local itemName = upgradeItemName or slot and slot.ItemName.Value
    local definition = ItemDefinitions[itemName]
    if not definition or definition.UpgradeFrom ~= (object:GetAttribute("ItemName") or object.Name) or
        not InventoryService.CanExchangeItems(player, {[itemName] = 1}, {}) then
        return false, "You need the matching coop upgrade."
    end
    if not Journal.CanBuild(player, itemName) then return false, "This upgrade requires a higher farm level" end
    local contents, message = AnimalService.Snapshot(object)
    if not contents then return false, message end
    local previous = object:GetAttribute("PurchaseCents") or 0
    local exchanged, errorMessage = InventoryService.ExchangeForObject(player, itemName, definition.PacksInto, function(paid)
        if not InventoryService.IsPurchaseCost(previous + paid) then return nil end
        return HttpService:JSONEncode({Version = 1, ItemName = definition.PacksInto, Contents = contents,
            PurchaseCents = previous + paid, BuildingId = object:GetAttribute("BuildingId")})
    end)
    if not exchanged then return false, errorMessage end
    object:Destroy()
    return true, "Coop packed. Select its renovation blueprint to place it."
end

function CoopUpgradeService.Prepare(object, itemName, encoded)
    if typeof(encoded) ~= "string" then return false, "Choose a packed coop." end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, encoded)
    if not ok or typeof(data) ~= "table" or data.Version ~= 1 or data.ItemName ~= itemName or
        typeof(data.Contents) ~= "table" then return false, "Invalid packed coop." end
    if data.PurchaseCents ~= nil and not InventoryService.IsPurchaseCost(data.PurchaseCents) then
        return false, "Invalid packed coop purchase cost."
    end
    local captured = data.Contents.CapturedAt
    local now = workspace:GetServerTimeNow()
    if typeof(captured) ~= "number" or captured ~= captured or captured < 0 or captured > now + 5 then
        return false, "Invalid packed coop time."
    end
    local restored, reason = AnimalService.Restore(object, data.Contents, math.max(0, now - captured))
    if not restored then return false, reason end
    object:SetAttribute("PurchaseCents", data.PurchaseCents)
    object:SetAttribute("BuildingId", data.BuildingId)
    return true
end

return CoopUpgradeService
