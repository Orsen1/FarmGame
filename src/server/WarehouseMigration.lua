local configs = game:GetService("ReplicatedStorage").Configs
local stages = require(configs.ConstructionDefinitions).WarehouseBlueprint.Stages
local capacity = require(configs.ItemDefinitions).Warehouse.StorageSlots
local InventoryService = require(script.Parent.InventoryService)
local StorageService = require(script.Parent.StorageService)

local WarehouseMigration = {}
local version = 1
local oldBlueprintPrice = 500
local maxInteger = 9007199254740991

local function addRow(rows, row, limit)
    if not row.ObjectData and not row.PaidLots then
        for _, existing in ipairs(rows) do
            if existing.ItemName == row.ItemName and not existing.ObjectData and not existing.PaidLots and
                existing.Amount <= maxInteger - row.Amount then
                existing.Amount += row.Amount
                return true
            end
        end
    end
    if #rows >= limit then return false end
    table.insert(rows, table.clone(row))
    return true
end

local function warehouseState(object)
    local ready = object.ItemName == "Warehouse"
    local stage = ready and #stages or object.ConstructionStage
    if stage == nil then stage = 0 end
    if typeof(stage) ~= "number" or stage % 1 ~= 0 or stage < 0 or stage > #stages or
        (not ready and stage == #stages) then return nil end
    local deposits = object.ConstructionDeposits
    if deposits == nil then deposits = {} end
    if typeof(deposits) ~= "table" then return nil end
    local nextStep = stages[stage + 1]
    local total = 0
    for material, amount in pairs(deposits) do
        local required = nextStep and nextStep.Inputs[material]
        if not required or typeof(amount) ~= "number" or amount % 1 ~= 0 or amount < 0 or amount > required then
            return nil
        end
        total += amount
    end

    local rows = object.StorageInventory
    if rows == nil then rows = {} end
    if not StorageService.ValidRows(rows, capacity) then return nil end
    return {Stage = stage, Deposits = deposits, Total = total, Rows = rows}
end

function WarehouseMigration.Apply(data)
    local previous = data.WarehouseMigrationVersion
    if previous == version then return data, false end
    if previous ~= nil and previous ~= 0 then return nil, false, "Unknown warehouse migration version" end
    if data.Warehouse ~= nil or data.StorageReturns ~= nil then return nil, false, "Incomplete warehouse migration" end

    local objects = data.PlacedObjects
    if objects == nil then objects = {} end
    if typeof(objects) ~= "table" or not StorageService.ValidRows(data.Inventory, 6) then
        return nil, false, "Invalid legacy farm data"
    end
    local placed, warehouses, best = {}, {}, nil
    for index in pairs(objects) do
        if typeof(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #objects then
            return nil, false, "Invalid legacy placement list"
        end
    end
    for index = 1, #objects do
        local object = objects[index]
        if typeof(object) ~= "table" then return nil, false, "Invalid legacy placement" end
        if object.ItemName == "Warehouse" or object.ItemName == "WarehouseBlueprint" then
            local state = warehouseState(object)
            if not state then return nil, false, "Invalid legacy warehouse contents or deposits" end
            table.insert(warehouses, state)
            if not best or state.Stage > best.Stage or (state.Stage == best.Stage and state.Total > best.Total) then
                best = state
            end
        else
            table.insert(placed, object)
        end
    end

    local main, overflow = {}, {}
    local function retain(row)
        if row.ItemName ~= "" and not (best and best.Stage == #stages and addRow(main, row, capacity)) then
            addRow(overflow, row, math.huge)
        end
    end
    local obsolete = 0
    local function migrateRow(row)
        if row.ItemName == "WarehouseBlueprint" or row.ItemName == "Warehouse" then
            if row.Amount > math.floor(maxInteger / oldBlueprintPrice) - obsolete then return false end
            obsolete += row.Amount
        else
            retain(row)
        end
        return true
    end

    for _, warehouse in ipairs(warehouses) do
        for index = 1, capacity do
            local row = warehouse.Rows[index]
            if row and not migrateRow(row) then return nil, false, "Invalid legacy blueprint balance" end
        end
    end
    for _, warehouse in ipairs(warehouses) do
        if warehouse == best then continue end
        obsolete += 1
        for stage = 1, warehouse.Stage do
            for material, amount in pairs(stages[stage].Inputs) do
                retain({ItemName = material, Amount = amount})
            end
        end
        for material, amount in pairs(warehouse.Deposits) do
            if amount > 0 then retain({ItemName = material, Amount = amount}) end
        end
    end

    local inventory = table.clone(data.Inventory)
    for index, row in pairs(inventory) do
        if row.ItemName == "WarehouseBlueprint" or row.ItemName == "Warehouse" then
            if not migrateRow(row) then return nil, false, "Invalid legacy blueprint balance" end
            inventory[index] = {ItemName = "", Amount = 0}
        end
    end
    local money = data.Money
    if typeof(money) ~= "number" or money % 1 ~= 0 or money < 0 or money > maxInteger or
        obsolete > math.floor((maxInteger - money) / oldBlueprintPrice) then
        return nil, false, "Invalid legacy warehouse compensation"
    end

    local migrated = table.clone(data)
    migrated.WarehouseMigrationVersion = version
    migrated.PlacedObjects = placed
    migrated.Warehouse = {Stage = best and best.Stage or -1, ConstructionDeposits = best and best.Deposits,
        Purchased = best and best.Stage == 0 or nil}
    if best and best.Stage == #stages then migrated.Warehouse.StorageInventory = main end
    migrated.StorageReturns = overflow
    migrated.Inventory = inventory
    migrated.Money = money + obsolete * oldBlueprintPrice
    return migrated, true
end

return WarehouseMigration
