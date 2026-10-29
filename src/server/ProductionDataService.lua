local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))

local ProductionDataService = {}
local MAX_INTEGER = 9007199254740991

local function isValidEntry(itemName, amount)
    return
        typeof(itemName) == "string" and ItemDefinitions[itemName] ~= nil and typeof(amount) == "number" and amount >= 0 and
            amount <= MAX_INTEGER and amount % 1 == 0
end

function ProductionDataService.getData(object)
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

    return data
end

function ProductionDataService.loadData(object, savedObject)
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
    object:SetAttribute("ActiveRecipe", nil)
    object:SetAttribute("OperatorUserId", nil)
    object:SetAttribute("ProductionStartedAt", nil)
    object:SetAttribute("ProductionDuration", nil)
    object:SetAttribute("ProductionAngle", 0)

    return true
end

return ProductionDataService
