local ItemDefinitions = require(game:GetService("ReplicatedStorage").Configs.ItemDefinitions)
local HttpService = game:GetService("HttpService")
local InventoryService = {}
local SLOT_COUNT = 6
local MAX_INTEGER = 9007199254740991

local function isValidAmount(amount)
    return typeof(amount) == "number" and amount >= 1 and amount <= MAX_INTEGER and amount % 1 == 0
end

local function isValidItemName(itemName)
    return typeof(itemName) == "string" and ItemDefinitions[itemName] ~= nil
end

function InventoryService.IsPurchaseCost(cents)
    return cents == 0 or isValidAmount(cents)
end

local function readPaidLots(row)
    if row.PaidLots == nil then return {}, 0 end
    if typeof(row.PaidLots) ~= "string" then return end
    local ok, lots = pcall(HttpService.JSONDecode, HttpService, row.PaidLots)
    if not ok or typeof(lots) ~= "table" or #lots == 0 then return end
    local count = 0
    for _, lot in ipairs(lots) do
        if typeof(lot) ~= "table" or not isValidAmount(lot[1]) or not isValidAmount(lot[2]) or
            lot[2] > row.Amount - count then return end
        count += lot[2]
    end
    return lots, count
end

local function encodeLots(lots)
    return #lots > 0 and HttpService:JSONEncode(lots) or nil
end

local function appendLot(lots, cents, count)
    local last = lots[#lots]
    if last and last[1] == cents then last[2] += count
    else table.insert(lots, {cents, count}) end
end

local function takeRow(row, amount)
    local taken = {ItemName = row.ItemName, Amount = amount, ObjectData = row.ObjectData}
    if row.PaidLots then
        local lots, paidCount = readPaidLots(row)
        local remaining = math.max(0, amount - (row.Amount - paidCount))
        local removed, left = {}, {}
        for _, lot in ipairs(lots) do
            local count = math.min(lot[2], remaining)
            if count > 0 then appendLot(removed, lot[1], count);remaining -= count end
            if lot[2] > count then appendLot(left, lot[1], lot[2] - count) end
        end
        taken.PaidLots, row.PaidLots = encodeLots(removed), encodeLots(left)
    end
    row.Amount -= amount
    if row.Amount == 0 then row.ItemName, row.ObjectData = "", nil end
    return taken
end

local function addRow(slot, row)
    if row.PaidLots then
        local lots = readPaidLots(slot)
        for _, lot in ipairs(readPaidLots(row)) do appendLot(lots, lot[1], lot[2]) end
        slot.PaidLots = encodeLots(lots)
    end
    slot.ItemName, slot.Amount, slot.ObjectData = row.ItemName, slot.Amount + row.Amount, row.ObjectData
end

local function paidForOne(row)
    local lots = readPaidLots(row)
    return lots[1] and lots[1][1] or 0
end

function InventoryService.IsValidObjectRow(row)
    if typeof(row) ~= "table" or typeof(row.ItemName) ~= "string" or typeof(row.Amount) ~= "number" then return false end
    if row.ItemName == "" then return row.Amount == 0 and row.ObjectData == nil and row.PaidLots == nil end
    local definition = ItemDefinitions[row.ItemName]
    if not definition or not isValidAmount(row.Amount) then return false end
    if row.ObjectData ~= nil then
        return (definition.Placeable == true or definition.Type == "Animal") and row.Amount == 1 and row.PaidLots == nil and
            typeof(row.ObjectData) == "string" and #row.ObjectData > 0 and #row.ObjectData <= 32768
    end
    return definition.InstanceItem ~= true and (row.PaidLots == nil or
        ((definition.Placeable or definition.UpgradeFrom) and readPaidLots(row) ~= nil))
end

local function writeSlot(slot, row)
    slot.ItemName.Value = row.ItemName
    slot.Amount.Value = row.Amount
    slot:SetAttribute("ObjectData", row.ObjectData)
    slot:SetAttribute("PaidLots", row.PaidLots)
end

function InventoryService.WriteSlots(folder, data)
    for index, row in ipairs(data) do
        writeSlot(folder["Slot" .. index], row)
    end
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

function InventoryService.CreateSlots(inventory, count)
    for index = 1, count do
        createSlot(inventory, index)
    end
end

local function planExchange(player, inputs, outputs, purchasePrice)
    if player:GetAttribute("DataLoaded") ~= true then return nil, "InventoryNotReady" end
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
            if slot.ItemName == itemName and not slot.ObjectData then
                local taken = math.min(slot.Amount, remaining)
                takeRow(slot, taken)
                remaining -= taken
                if remaining == 0 then break end
            end
        end
        if remaining > 0 then return nil, "NotEnoughItems: " .. itemName end
    end

    for itemName, amount in pairs(outputs) do
        if not isValidItemName(itemName) or not isValidAmount(amount) then
            return nil, "InvalidItemOrAmount"
        end
        if ItemDefinitions[itemName] and ItemDefinitions[itemName].InstanceItem then return nil, "MissingObjectData" end

        local target
        local empty

        for _, slot in ipairs(data) do
            if slot.ItemName == itemName and not slot.ObjectData then
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
        if target.Amount > MAX_INTEGER - amount then return nil, "AmountTooLarge" end

        local definition = ItemDefinitions[itemName]
        local bought = purchasePrice and purchasePrice > 0 and (definition.Placeable or definition.UpgradeFrom)
        addRow(target, {ItemName = itemName, Amount = amount,
            PaidLots = bought and HttpService:JSONEncode({{purchasePrice, amount}}) or nil})
    end

    return data
end

function InventoryService.CanExchangeItems(player, inputs, outputs)
    local data, reason = planExchange(player, inputs, outputs)

    return data ~= nil, reason
end

function InventoryService.ExchangeItems(player, inputs, outputs, purchasePrice)
    local data, reason = planExchange(player, inputs, outputs, purchasePrice)

    if not data then
        return false, reason
    end

    InventoryService.WriteSlots(player.Inventory, data)

    return true
end

function InventoryService.Initialize(player)
    if player:FindFirstChild("Inventory") then
        return
    end

    local inventory = Instance.new("Folder")
    inventory.Name = "Inventory"
    inventory.Parent = player

    InventoryService.CreateSlots(inventory, SLOT_COUNT)
end

function InventoryService.CanAddItem(player, itemName, amount)
    if not isValidItemName(itemName) or not isValidAmount(amount) then
        return false, "InvalidItemOrAmount"
    end
    return InventoryService.CanExchangeItems(player, {}, {[itemName] = amount})
end

function InventoryService.AddItem(player, itemName, amount, purchasePrice)
    if not isValidItemName(itemName) or not isValidAmount(amount) then
        return false, "InvalidItemOrAmount"
    end
    return InventoryService.ExchangeItems(player, {}, {[itemName] = amount}, purchasePrice)
end

function InventoryService.RemoveItem(player, itemName, amount)
    if not isValidItemName(itemName) or not isValidAmount(amount) then
        return false, "InvalidItemOrAmount"
    end

    return InventoryService.ExchangeItems(player, {
        [itemName] = amount
    }, {})
end

function InventoryService.TakeFromSlot(slot, itemName, amount, expectedData)
    if not slot or not isValidAmount(amount) or slot.ItemName.Value ~= itemName or slot.Amount.Value < amount or
        slot:GetAttribute("ObjectData") ~= expectedData then return false end
    local row = {ItemName = itemName, Amount = slot.Amount.Value, ObjectData = expectedData, PaidLots = slot:GetAttribute("PaidLots")}
    if not InventoryService.IsValidObjectRow(row) then return false end
    local taken = takeRow(row, amount)
    writeSlot(slot, row)
    return true, amount == 1 and paidForOne(taken) or 0
end

function InventoryService.RemoveFromSlot(player, slotIndex, itemName, amount)
    if player:GetAttribute("DataLoaded") ~= true or typeof(slotIndex) ~= "number" then return false end
    local folder = player:FindFirstChild("Inventory")
    local slot = folder and folder:FindFirstChild("Slot" .. slotIndex)
    return InventoryService.TakeFromSlot(slot, itemName, amount)
end

local function matchingSlot(data, itemName, preferred)
    local selected = data[preferred]
    if selected and selected.ItemName == itemName then return selected, preferred end
    for index, row in ipairs(data) do
        if row.ItemName == itemName then return row, index end
    end
end

function InventoryService.FindItem(player, itemName)
    local data = InventoryService.GetInventory(player)
    if data then return matchingSlot(data, itemName, player:GetAttribute("SelectedSlot") or 1) end
end

function InventoryService.ReadSlots(folder, count)
    if not folder then
        return nil
    end

    local inventoryData = {}

    for i = 1, count do
        local slot = folder:FindFirstChild("Slot" .. i)

        if not slot then
            return nil
        end

        local nameValue = slot:FindFirstChild("ItemName")
        local amountValue = slot:FindFirstChild("Amount")

        if not nameValue or not nameValue:IsA("StringValue") or not amountValue or not amountValue:IsA("IntValue") then
            return nil
        end

        inventoryData[i] = {
            ItemName = nameValue.Value,
            Amount = amountValue.Value,
            ObjectData = slot:GetAttribute("ObjectData"),
            PaidLots = slot:GetAttribute("PaidLots")
        }
        if not InventoryService.IsValidObjectRow(inventoryData[i]) then return nil end
    end

    return inventoryData
end

function InventoryService.GetInventory(player)
    return InventoryService.ReadSlots(player:FindFirstChild("Inventory"), SLOT_COUNT)
end

function InventoryService.ReceiveInto(data, source, amount)
    local remaining = amount
    local empty
    for index, slot in ipairs(data) do
        if slot.ItemName == "" then
            empty = empty or index
        elseif not source.ObjectData and not slot.ObjectData and slot.ItemName == source.ItemName then
            local added = math.min(remaining, MAX_INTEGER - slot.Amount)
            if added > 0 then addRow(slot, takeRow(source, added)) end
            remaining -= added
            if remaining == 0 then break end
        end
    end
    if remaining > 0 and empty then
        data[empty] = takeRow(source, remaining)
        remaining = 0
    end
    return amount - remaining
end

function InventoryService.ReceiveRow(folder, count, row, amount)
    local data = InventoryService.ReadSlots(folder, count)
    if not data or not InventoryService.IsValidObjectRow(row) or not isValidAmount(amount) or amount > row.Amount then
        return 0
    end
    local moved = InventoryService.ReceiveInto(data, row, amount)
    if moved > 0 then InventoryService.WriteSlots(folder, data) end
    return moved
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
        from:GetAttribute("ObjectData") ~= expectedFrom.ObjectData or to:GetAttribute("ObjectData") ~= expectedTo.ObjectData or
        from:GetAttribute("PaidLots") ~= expectedFrom.PaidLots or to:GetAttribute("PaidLots") ~= expectedTo.PaidLots then
        return false, "InventoryChanged"
    end

    if fromName.Value == "" or not isValidAmount(fromAmount.Value) then
        return false, "SourceSlotEmpty"
    end

    local a = {ItemName = fromName.Value, Amount = fromAmount.Value, ObjectData = from:GetAttribute("ObjectData"),
        PaidLots = from:GetAttribute("PaidLots")}
    local b = {ItemName = toName.Value, Amount = toAmount.Value, ObjectData = to:GetAttribute("ObjectData"),
        PaidLots = to:GetAttribute("PaidLots")}
    if not InventoryService.IsValidObjectRow(a) or not InventoryService.IsValidObjectRow(b) then
        return false, "InvalidSlot"
    end

    if from == to then
        return true
    end

    if a.ItemName == b.ItemName and not a.ObjectData and not b.ObjectData then
        if b.Amount > MAX_INTEGER - a.Amount then return false, "AmountTooLarge" end
        addRow(b, takeRow(a, a.Amount))
    else
        a, b = b, a
    end

    writeSlot(from, a)
    writeSlot(to, b)

    return true
end

function InventoryService.MoveSlot(player, fromIndex, toIndex, expectedFrom, expectedTo)
    local inventory = player:FindFirstChild("Inventory")

    return InventoryService.MoveBetweenSlots(inventory, SLOT_COUNT, inventory, SLOT_COUNT, fromIndex, toIndex,
        expectedFrom, expectedTo)
end

function InventoryService.MoveToFirstFreeSlot(fromFolder, fromCount, toFolder, toCount, fromIndex, expectedFrom)
    local destination = InventoryService.ReadSlots(toFolder, toCount)
    if not destination then return false, "InventoryNotReady" end

    for index, row in ipairs(destination) do
        if row.Amount == 0 then
            return InventoryService.MoveBetweenSlots(fromFolder, fromCount, toFolder, toCount, fromIndex,
                index, expectedFrom, row)
        end
    end

    return false, "DestinationFull"
end

function InventoryService.DiscardSlot(player, slotIndex, expected)
    if player:GetAttribute("DataLoaded") ~= true then return false, "InventoryNotReady" end
    if typeof(slotIndex) ~= "number" or slotIndex % 1 ~= 0 or slotIndex < 1 or slotIndex > SLOT_COUNT or
        typeof(expected) ~= "table" then return false, "InvalidSlot" end
    local data = InventoryService.GetInventory(player)
    if not data then return false, "InventoryNotReady" end
    local row = data[slotIndex]
    if row.ItemName ~= expected.ItemName or row.Amount ~= expected.Amount or
        row.ObjectData ~= expected.ObjectData or row.PaidLots ~= expected.PaidLots then
        return false, "InventoryChanged"
    end
    if row.Amount < 1 then return false, "SourceSlotEmpty" end
    local definition = ItemDefinitions[row.ItemName]
    if definition and definition.Type == "Seed" then return false, "PermanentSeed" end
    data[slotIndex] = {ItemName = "", Amount = 0}
    InventoryService.WriteSlots(player.Inventory, data)
    return true
end

function InventoryService.ExchangeForObject(player, purchaseItem, itemName, encode)
    if player:GetAttribute("DataLoaded") ~= true then return false, "InventoryNotReady" end
    local data = InventoryService.GetInventory(player)
    local upgrade = data and matchingSlot(data, purchaseItem, player:GetAttribute("SelectedSlot") or 1)
    if not upgrade or upgrade.ObjectData then return false, "You need the matching coop upgrade." end
    local payment = paidForOne(takeRow(upgrade, 1))
    local objectData = encode(payment)
    local row = {ItemName = itemName, Amount = 1, ObjectData = objectData}
    if not InventoryService.IsValidObjectRow(row) then return false, "Invalid object data." end
    for index, slot in ipairs(data) do
        if slot.ItemName == "" then
            data[index] = row
            InventoryService.WriteSlots(player.Inventory, data)
            return true
        end
    end
    return false, "Free an inventory slot for the packed coop."
end

function InventoryService.RemoveObject(player, slotIndex, objectData)
    if player:GetAttribute("DataLoaded") ~= true then return false end
    local slot = player.Inventory:FindFirstChild("Slot" .. slotIndex)
    if not slot or slot.Amount.Value ~= 1 or not objectData or slot:GetAttribute("ObjectData") ~= objectData then
        return false
    end
    writeSlot(slot, {ItemName = "", Amount = 0})
    return true
end

return InventoryService
