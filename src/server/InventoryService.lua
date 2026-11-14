local CropItems = require(game.ReplicatedStorage.CropItems)
local ItemDefinitions = require(game:GetService("ReplicatedStorage").Configs.ItemDefinitions)
local InventoryService = {}
local SLOT_COUNT = 6
local MAX_INTEGER = 9007199254740991

local function isValidAmount(amount)
    return typeof(amount) == "number" and amount >= 1 and amount <= MAX_INTEGER and amount % 1 == 0
end

local function isValidItemName(itemName)
    return typeof(itemName) == "string" and ItemDefinitions[itemName] ~= nil
end

function InventoryService.IsValidObjectRow(row)
    if typeof(row) ~= "table" or typeof(row.ItemName) ~= "string" or typeof(row.Amount) ~= "number" then return false end
    if row.ItemName == "" then return row.Amount == 0 and row.ObjectData == nil and row.Variants == nil end
    if not CropItems.Valid(row) then return false end
    local definition = ItemDefinitions[row.ItemName]
    if not definition or not isValidAmount(row.Amount) then return false end
    if row.ObjectData ~= nil then
        return definition.InstanceItem == true and row.Amount == 1 and
            typeof(row.ObjectData) == "string" and #row.ObjectData > 0 and #row.ObjectData <= 32768
    end
    return definition.InstanceItem ~= true
end

local function writeInventory(player, data)
    for index, row in ipairs(data) do
        local slot = player.Inventory["Slot" .. index]
        slot.ItemName.Value = row.ItemName
        slot.Amount.Value = row.Amount
        slot:SetAttribute("ObjectData", row.ObjectData)
        CropItems.Write(slot, row.Variants)
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

local function planExchange(player, inputs, outputs, variants)
    if player:GetAttribute("DataLoaded") ~= true then return nil, "InventoryNotReady" end
    if typeof(inputs) ~= "table" or typeof(outputs) ~= "table" then
        return nil, "InvalidRecipeItems"
    end

    local data = InventoryService.GetInventory(player)

    if not data then
        return nil, "InventoryNotReady"
    end

    local removed = {}
    for itemName, amount in pairs(inputs) do
        if not isValidItemName(itemName) or not isValidAmount(amount) then
            return nil, "InvalidItemOrAmount"
        end

        local groups, reason = CropItems.Take(data, itemName, amount)
        if not groups then return nil, reason end
        removed[itemName] = groups
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
        if target.Amount > MAX_INTEGER - amount then return nil, "AmountTooLarge" end

        local added = {ItemName = itemName, Amount = amount, Variants = variants and variants[itemName]}
        if not CropItems.Valid(added) then return nil, "InvalidCropData" end
        if target.Amount > 0 or added.Variants then
            CropItems.SetGroups(target, CropItems.Merge(CropItems.Groups(target), CropItems.Groups(added)))
        end
        target.ItemName = itemName
        target.Amount = target.Amount + amount
    end

    return data, nil, removed
end

function InventoryService.CanExchangeItems(player, inputs, outputs)
    local data, reason = planExchange(player, inputs, outputs)

    return data ~= nil, reason
end

function InventoryService.ExchangeItems(player, inputs, outputs, variants)
    local data, reason, removed = planExchange(player, inputs, outputs, variants)

    if not data then
        return false, reason
    end

    writeInventory(player, data)

    return true, nil, removed
end

function InventoryService.GetRemoval(player, inputs)
    local data, reason, removed = planExchange(player, inputs, {})
    return data and removed, reason
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

function InventoryService.AddItem(player, itemName, amount)
    if not isValidItemName(itemName) or not isValidAmount(amount) then
        return false, "InvalidItemOrAmount"
    end
    return InventoryService.ExchangeItems(player, {}, {[itemName] = amount})
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
            ObjectData = slot:GetAttribute("ObjectData"),
            Variants = CropItems.Read(slot)
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
        from:GetAttribute("ObjectData") ~= expectedFrom.ObjectData or to:GetAttribute("ObjectData") ~= expectedTo.ObjectData or
        from:GetAttribute("Variants") ~= expectedFrom.Variants or to:GetAttribute("Variants") ~= expectedTo.Variants then
        return false, "InventoryChanged"
    end

    if fromName.Value == "" or not isValidAmount(fromAmount.Value) then
        return false, "SourceSlotEmpty"
    end

    if not InventoryService.IsValidObjectRow({ItemName = fromName.Value, Amount = fromAmount.Value,
        ObjectData = from:GetAttribute("ObjectData"), Variants = CropItems.Read(from)}) or
        not InventoryService.IsValidObjectRow({ItemName = toName.Value, Amount = toAmount.Value,
            ObjectData = to:GetAttribute("ObjectData"), Variants = CropItems.Read(to)}) then
        return false, "InvalidSlot"
    end

    if from == to then
        return true
    end

    local aName, aAmount = fromName.Value, fromAmount.Value
    local bName, bAmount = toName.Value, toAmount.Value
    local aData, bData = from:GetAttribute("ObjectData"), to:GetAttribute("ObjectData")
    local aVariants, bVariants = CropItems.Read(from), CropItems.Read(to)

    if aName == bName and not aData and not bData then
        if bAmount > MAX_INTEGER - aAmount then return false, "AmountTooLarge" end
        local groups = CropItems.Merge(CropItems.Groups({Amount = aAmount, Variants = aVariants}), CropItems.Groups({Amount = bAmount, Variants = bVariants}))
        local row = {}
        CropItems.SetGroups(row, groups)
        aVariants, bVariants = nil, row.Variants
        aName, aAmount, bAmount = "", 0, bAmount + aAmount
    else
        aName, aAmount, bName, bAmount = bName, bAmount, aName, aAmount
        aData, bData = bData, aData
        aVariants, bVariants = bVariants, aVariants
    end

    CropItems.Write(from, aVariants)
    CropItems.Write(to, bVariants)
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
