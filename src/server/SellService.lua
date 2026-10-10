local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryService = require(ServerScriptService:WaitForChild("InventoryService"))
local MoneyService = require(ServerScriptService:WaitForChild("MoneyService"))

local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))

local SellService = {}

function SellService.SellItem(player, itemName, amount)
    local item = ItemDefinitions[itemName]
    local price = item and item.SellPriceCents

    if price == nil then
        print("Item cannot be sold:", itemName)
        return false
    end

    if typeof(amount) ~= "number" or amount <= 0 or amount % 1 ~= 0 then
        return false
    end

    local removed = InventoryService.RemoveItem(player, itemName, amount)

    if not removed then
        print("Player does not have item:", itemName)
        return false
    end

    local totalPrice = price * amount
    MoneyService.AddMoney(player, totalPrice)

    print(player.Name .. " sold " .. amount .. "x " .. itemName .. " for " .. totalPrice .. " cents")

    return true
end

return SellService
