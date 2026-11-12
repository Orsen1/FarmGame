local ItemDefinitions = require(game:GetService("ReplicatedStorage").Configs.ItemDefinitions)
local InventoryService = {}
local SLOT_COUNT = 6
local MAX_INTEGER = 9007199254740991

function InventoryService.IsValidObjectRow(row)
    if typeof(row) ~= "table" or typeof(row.ItemName) ~= "string" or typeof(row.Amount) ~= "number" then return false end
    local definition = ItemDefinitions[row.ItemName]
    if row.ObjectData ~= nil then
        return definition ~= nil and definition.InstanceItem == true and row.Amount == 1 and
            typeof(row.ObjectData) == "string" and #row.ObjectData > 0 and #row.ObjectData <= 32768
    end
    return not (definition and definition.InstanceItem and row.Amount > 0)
end

local function writeInventory(player, data)
    for index, row in ipairs(data) do
        local slot = player.Inventory["Slot" .. index]
        slot.ItemName.Value = row.ItemName
        slot.Amount.Value = row.Amount
        slot:SetAttribute("ObjectData", row.ObjectData)
    end
end

local function isValidAmount(amount)
    return typeof(amount) == "number" and amount >= 1 and amount % 1 == 0
end

local function isValidItemName(itemName)
    return typeof(itemName) == "string" and itemName ~= ""
end

local function createSlot(inventory, slotNumber)
    local slot = Instance.new("Folder")
    slot.Name = "Slot" .. slotNumber
    slot.Parent = inventory

    local itemName = Instance.new("StringValue")
    itemName.Name = "ItemName"
    itemName.Value = ""
    itemName.Parent = slot

    local amount = Instance.new("IntValue")
    amount.Name = "Amount"
    amount.Value = 0
    amount.Parent = slot
end

local function findTargetSlot(inventory, itemName)
    local emptySlot = nil

    for slotNumber = 1, SLOT_COUNT do
        local slot = inventory:FindFirstChild("Slot" .. slotNumber)
        local nameValue = slot and slot:FindFirstChild("ItemName")
        local amountValue = slot and slot:FindFirstChild("Amount")

        if nameValue and amountValue then
            if nameValue.Value == itemName then
                return slot
            end

            if nameValue.Value == "" and not emptySlot then
                emptySlot = slot
            end
        end
    end

    return emptySlot
end

local function planExchange(player, inputs, outputs)
    if typeof(inputs) ~= "table" or typeof(outputs) ~= "table" then
        return nil, "InvalidRecipeItems"
    end

    local data = InventoryService.GetInventory(player)

    if not data then
        return nil, "InventoryNotReady"
    end

    for itemName, amount in pairs(inputs) do
        if not isValidItemName(itemName) or not isValidAmount(amount) then
            return nil, "InvalidItemOrAmount"
        end

        local remaining = amount

        for _, slot in ipairs(data) do
            if slot.ItemName == itemName then
                if slot.ObjectData then return nil, "UseSelectedBuilding" end
                local taken = math.min(slot.Amount, remaining)

                slot.Amount = slot.Amount - taken
                remaining = remaining - taken

                if slot.Amount == 0 then
                    slot.ItemName = ""
                end

                if remaining == 0 then
                    break
                end
            end
        end

        if remaining > 0 then
            return nil, "NotEnoughItems: " .. itemName
        end
    end

    for itemName, amount in pairs(outputs) do
        if not isValidItemName(itemName) or not isValidAmount(amount) then
            return nil, "InvalidItemOrAmount"
        end
        if ItemDefinitions[itemName] and ItemDefinitions[itemName].InstanceItem then return nil, "MissingObjectData" end

        local target
        local empty

        for _, slot in ipairs(data) do
            if slot.ItemName == itemName then
                target = slot
                break
            end

            if slot.ItemName == "" and not empty then
                empty = slot
            end
        end

        target = target or empty

        if not target then
            return nil, "InventoryFull"
        end

        target.ItemName = itemName
        target.Amount = target.Amount + amount
    end

    return data
end

function InventoryService.CanExchangeItems(player, inputs, outputs)
    local data, reason = planExchange(player, inputs, outputs)

    return data ~= nil, reason
end

function InventoryService.ExchangeItems(player, inputs, outputs)
    local data, reason = planExchange(player, inputs, outputs)

    if not data then
        return false, reason
    end

    writeInventory(player, data)

    return true
end

function InventoryService.Initialize(player)
    if player:FindFirstChild("Inventory") then
        return
    end

    local inventory = Instance.new("Folder")
    inventory.Name = "Inventory"
    inventory.Parent = player

    for slotNumber = 1, SLOT_COUNT do
        createSlot(inventory, slotNumber)
    end
end

function InventoryService.CanAddItem(player, itemName, amount)
    if not isValidItemName(itemName) or not isValidAmount(amount) then
        return false, "InvalidItemOrAmount"
    end
    if ItemDefinitions[itemName] and ItemDefinitions[itemName].InstanceItem then return false, "MissingObjectData" end

    local inventory = player:FindFirstChild("Inventory")
    if not inventory then
        return false, "InventoryNotReady"
    end

    local slot = findTargetSlot(inventory, itemName)
    if not slot then
        return false, "InventoryFull"
    end

    local currentAmount = slot.Amount.Value
    if currentAmount < 0 or currentAmount % 1 ~= 0 then
        return false, "AmountTooLarge"
    end

    return true
end

function InventoryService.AddItem(player, itemName, amount)
    local canAdd, reason = InventoryService.CanAddItem(player, itemName, amount)
    if not canAdd then
        return false, reason
    end

    local slot = findTargetSlot(player.Inventory, itemName)
    slot.ItemName.Value = itemName
    slot.Amount.Value = slot.Amount.Value + amount
    return true
end

function InventoryService.RemoveItem(player, itemName, amount)
    if not isValidItemName(itemName) or not isValidAmount(amount) then
        return false, "InvalidItemOrAmount"
    end

    return InventoryService.ExchangeItems(player, {
        [itemName] = amount
    }, {})
end

function InventoryService.GetInventory(player)
    local inventory = player:FindFirstChild("Inventory")
    if not inventory then
        return nil
    end

    local inventoryData = {}

    for i = 1, SLOT_COUNT do
        local slot = inventory:FindFirstChild("Slot" .. i)

        if not slot then
            return nil
        end

        local nameValue = slot:FindFirstChild("ItemName")
        local amountValue = slot:FindFirstChild("Amount")

        if not nameValue or not amountValue then
            return nil
        end

        inventoryData[i] = {
            ItemName = nameValue.Value,
            Amount = amountValue.Value,
            ObjectData = slot:GetAttribute("ObjectData")
        }
        if not InventoryService.IsValidObjectRow(inventoryData[i]) then return nil end
    end

    return inventoryData
end

function InventoryService.MoveBetweenSlots(fromFolder, fromCount, toFolder, toCount, fromIndex, toIndex, expectedFrom,
    expectedTo)
    local function validIndex(index, count)
        return typeof(index) == "number" and index % 1 == 0 and index >= 1 and index <= count
    end

    if not validIndex(fromIndex, fromCount) or not validIndex(toIndex, toCount) or typeof(expectedFrom) ~= "table" or
        typeof(expectedTo) ~= "table" then
        return false, "InvalidSlot"
    end

    if not fromFolder or not toFolder then
        return false, "InventoryNotReady"
    end

    local from = fromFolder:FindFirstChild("Slot" .. fromIndex)
    local to = toFolder:FindFirstChild("Slot" .. toIndex)

    if not from or not to then
        return false, "InvalidSlot"
    end

    local fromName = from:FindFirstChild("ItemName")
    local fromAmount = from:FindFirstChild("Amount")
    local toName = to:FindFirstChild("ItemName")
    local toAmount = to:FindFirstChild("Amount")

    if not fromName or not fromAmount or not toName or not toAmount then
        return false, "InvalidSlot"
    end

    if fromName.Value ~= expectedFrom.ItemName or fromAmount.Value ~= expectedFrom.Amount or toName.Value ~=
        expectedTo.ItemName or toAmount.Value ~= expectedTo.Amount or
        from:GetAttribute("ObjectData") ~= expectedFrom.ObjectData or to:GetAttribute("ObjectData") ~= expectedTo.ObjectData then
        return false, "InventoryChanged"
    end

    if fromName.Value == "" or not isValidAmount(fromAmount.Value) then
        return false, "SourceSlotEmpty"
    end

    if (toName.Value == "" and toAmount.Value ~= 0) or (toName.Value ~= "" and not isValidAmount(toAmount.Value)) then
        return false, "InvalidSlot"
    end

    if from == to then
        return true
    end

    local aName, aAmount = fromName.Value, fromAmount.Value
    local bName, bAmount = toName.Value, toAmount.Value
    local aData, bData = from:GetAttribute("ObjectData"), to:GetAttribute("ObjectData")

    if aName == bName and not aData and not bData then
        aName, aAmount, bAmount = "", 0, bAmount + aAmount
    else
        aName, aAmount, bName, bAmount = bName, bAmount, aName, aAmount
        aData, bData = bData, aData
    end

    fromName.Value = aName
    fromAmount.Value = aAmount
    toName.Value = bName
    toAmount.Value = bAmount
    from:SetAttribute("ObjectData", aData)
    to:SetAttribute("ObjectData", bData)

    return true
end

function InventoryService.MoveSlot(player, fromIndex, toIndex, expectedFrom, expectedTo)
    local inventory = player:FindFirstChild("Inventory")

    return InventoryService.MoveBetweenSlots(inventory, SLOT_COUNT, inventory, SLOT_COUNT, fromIndex, toIndex,
        expectedFrom, expectedTo)
end

function InventoryService.ExchangeForObject(player, inputs, itemName, objectData)
    local row = {ItemName = itemName, Amount = 1, ObjectData = objectData}
    if not InventoryService.IsValidObjectRow(row) then return false, "Invalid object data." end
    local data, reason = planExchange(player, inputs, {})
    if not data then return false, reason end
    for index, slot in ipairs(data) do
        if slot.ItemName == "" then
            data[index] = row
            writeInventory(player, data)
            return true
        end
    end
    return false, "Free an inventory slot for the packed coop."
end

function InventoryService.RemoveObject(player, slotIndex, objectData)
    local slot = player.Inventory:FindFirstChild("Slot" .. slotIndex)
    if not slot or slot.Amount.Value ~= 1 or not objectData or slot:GetAttribute("ObjectData") ~= objectData then
        return false
    end
    slot:SetAttribute("ObjectData", nil)
    slot.ItemName.Value = ""
    slot.Amount.Value = 0
    return true
end

return InventoryService
