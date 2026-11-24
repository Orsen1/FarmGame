local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))
local recipes = require(ReplicatedStorage.Configs.ProductionRecipes)
local Jobs = require(script.Parent.ProductionJobs)

local ProductionDataService = {}
local MAX_INTEGER = 9007199254740991

local function isValidEntry(itemName, amount)
    return
        typeof(itemName) == "string" and ItemDefinitions[itemName] ~= nil and typeof(amount) == "number" and amount >= 0 and
            amount <= MAX_INTEGER and amount % 1 == 0
end

function ProductionDataService.getData(object)
    local production, reason = Jobs.GetData(object)
    if reason then return nil, reason end
    local outputInventory = object:FindFirstChild("OutputInventory")

    if not outputInventory or not outputInventory:IsA("Folder") then
        return nil, "OutputInventory is missing in " .. object.Name
    end

    local data = {}

    for _, storedItem in ipairs(outputInventory:GetChildren()) do
        if not storedItem:IsA("IntValue") or not isValidEntry(storedItem.Name, storedItem.Value) or
            data[storedItem.Name] ~= nil then
            return nil, "Invalid output inventory in " .. object.Name
        end

        data[storedItem.Name] = storedItem.Value
    end

    return data, nil, production
end

function ProductionDataService.GetReturns(object)
    local output, reason, production = ProductionDataService.getData(object)
    if not output then return nil, reason end
    local rows = {}
    local function add(item, amount)
        if amount > 0 then table.insert(rows, {ItemName = item, Amount = amount}) end
    end
    for item, amount in pairs(output) do add(item, amount) end

    local definition = ItemDefinitions[object:GetAttribute("ItemName") or object.Name]
    local tank = definition.MilkTank
    if tank then add(tank.RecoveredItem, production.MilkStock) end
    if production and production.Job then
        for item, amount in pairs(recipes[production.Job.RecipeId].Inputs) do
            add(tank and item == tank.Item and tank.RecoveredItem or item, amount)
        end
    end
    return rows
end

function ProductionDataService.loadData(object, savedObject)
    if not Jobs.Validate(object, savedObject.Production) then return false, "Invalid saved production" end
    local outputInventory = object:FindFirstChild("OutputInventory")

    if not outputInventory or not outputInventory:IsA("Folder") then
        return false, "OutputInventory is missing in " .. object.Name
    end

    local data = savedObject.OutputInventory

    if data == nil then
        data = {}
    end

    if typeof(data) ~= "table" then
        return false, "Invalid saved output inventory"
    end

    for itemName, amount in pairs(data) do
        if not isValidEntry(itemName, amount) then
            return false, "Invalid saved output item: " .. tostring(itemName)
        end
    end

    for _, storedItem in ipairs(outputInventory:GetChildren()) do
        storedItem:Destroy()
    end

    for itemName, amount in pairs(data) do
        local storedItem = Instance.new("IntValue")
        storedItem.Name = itemName
        storedItem.Value = amount
        storedItem.Parent = outputInventory
    end

    object:SetAttribute("Busy", false)
    object:SetAttribute("ProductionPhase", nil)
    object:SetAttribute("ActiveRecipe", nil)
    object:SetAttribute("OperatorUserId", nil)
    object:SetAttribute("ProductionStartedAt", nil)
    object:SetAttribute("ProductionDuration", nil)
    object:SetAttribute("ProductionAngle", 0)
    Jobs.Load(object, savedObject.Production)

    return true
end

return ProductionDataService
