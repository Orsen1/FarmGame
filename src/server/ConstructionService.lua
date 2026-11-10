local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local configs = ReplicatedStorage:WaitForChild("Configs")

local ItemDefinitions = require(configs:WaitForChild("ItemDefinitions"))
local ConstructionDefinitions = require(configs:WaitForChild("ConstructionDefinitions"))
local InventoryService = require(ServerScriptService:WaitForChild("InventoryService"))
local PlacementModels = require(ReplicatedStorage:WaitForChild("PlacementScripts"):WaitForChild("PlacementModels"))

local ConstructionService = {}
local DEPOSIT_PREFIX = "ConstructionDeposited_"

local function getStage(object)
    local itemName = object:GetAttribute("ItemName") or object.Name
    local construction = ConstructionDefinitions[itemName]
    local stage = object:GetAttribute("ConstructionStage")
    if stage == nil then
        stage = 0
    end

    if not construction or typeof(stage) ~= "number" or stage < 0 or stage % 1 ~= 0 then
        return nil
    end

    return construction.Stages[stage + 1], stage, construction
end

local function validAmount(amount)
    return typeof(amount) == "number" and amount >= 0 and amount % 1 == 0
end

function ConstructionService.getData(object)
    local step = getStage(object)
    if not step then
        return nil, "Invalid construction stage"
    end

    local deposits = {}
    for itemName, required in pairs(step.Inputs) do
        local amount = object:GetAttribute(DEPOSIT_PREFIX .. itemName)
        if amount ~= nil then
            if not validAmount(amount) or amount > required then
                return nil, "Invalid construction deposit: " .. itemName
            end
            if amount > 0 then
                deposits[itemName] = amount
            end
        end
    end
    return deposits
end

function ConstructionService.loadData(object, savedDeposits)
    if savedDeposits == nil then
        return true
    end

    local step = getStage(object)
    if not step or typeof(savedDeposits) ~= "table" then
        return false, "Invalid saved construction deposits"
    end

    for itemName, amount in pairs(savedDeposits) do
        if typeof(itemName) ~= "string" or not validAmount(amount) then
            return false, "Invalid saved construction deposit"
        end
    end

    for itemName, required in pairs(step.Inputs) do
        local amount = savedDeposits[itemName]
        if amount and amount > 0 then
            object:SetAttribute(DEPOSIT_PREFIX .. itemName, math.min(amount, required))
        end
    end
    return true
end

local function planDeposit(player, inputs, deposits)
    local inventory = InventoryService.GetInventory(player)
    if not inventory then
        return nil, "Inventory is not ready"
    end

    local available = {}
    for _, slot in ipairs(inventory) do
        if inputs[slot.ItemName] then
            available[slot.ItemName] = (available[slot.ItemName] or 0) + slot.Amount
        end
    end

    local payment = {}
    local complete = true
    for itemName, required in pairs(inputs) do
        local current = deposits[itemName] or 0
        local amount = math.min(required - current, available[itemName] or 0)
        if amount > 0 then
            payment[itemName] = amount
            deposits[itemName] = current + amount
        end
        if current + amount < required then
            complete = false
        end
    end
    return payment, complete
end

local function getNextTemplate(itemName, definition, nextStage, final)
    local nextItemName = final and definition.BuildsInto or itemName
    local nextDefinition = ItemDefinitions[nextItemName]
    if not nextDefinition or nextDefinition.Placeable ~= true or (final and nextDefinition.BuildsInto) then
        return nil, "Invalid construction result"
    end

    local template = PlacementModels.getTemplate(nextItemName, not final and nextStage or nil)
    local prompt = template and template:FindFirstChild("ActionPrompt", true)
    if not prompt or not prompt:IsA("ProximityPrompt") then
        return nil, "Next construction model or prompt is missing"
    end
    return template, nextItemName
end

local function prepareNextObject(template, itemName, stage, player, oldObject)
    local object = template:Clone()
    object.Name = itemName
    object:SetAttribute("ItemName", itemName)
    object:SetAttribute("OwnerUserId", player.UserId)
    object:SetAttribute("ConstructionStage", stage)
    for _, part in ipairs(object:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanQuery = true
        end
    end
    object:PivotTo(oldObject:GetPivot())
    return object
end

function ConstructionService.Build(player, object)
    if player:GetAttribute("DataLoaded") ~= true or object:GetAttribute("OwnerUserId") ~= player.UserId or
        not object:IsDescendantOf(workspace) then
        return false, "Construction is not available"
    end

    local itemName = object:GetAttribute("ItemName") or object.Name
    local definition = ItemDefinitions[itemName]
    local step, stage, construction = getStage(object)
    if not definition or not definition.BuildsInto or not step then
        return false, "Invalid construction stage"
    end

    local deposits, reason = ConstructionService.getData(object)
    if not deposits then
        return false, reason
    end
    local payment, complete = planDeposit(player, step.Inputs, deposits)
    if not payment then
        return false, complete
    end
    if not complete and not next(payment) then
        return false, "No required materials to add"
    end

    local nextStage = stage + 1
    local final = nextStage == #construction.Stages
    local template, nextItemName = getNextTemplate(itemName, definition, nextStage, final)
    if not template then
        return false, nextItemName
    end

    local nextObject
    if complete then
        nextObject = prepareNextObject(template, nextItemName, not final and nextStage or nil, player, object)
    end

    if next(payment) then
        local removed, exchangeError = InventoryService.ExchangeItems(player, payment, {})
        if not removed then
            if nextObject then
                nextObject:Destroy()
            end
            return false, exchangeError
        end
    end

    if not nextObject then
        for material in pairs(payment) do
            object:SetAttribute(DEPOSIT_PREFIX .. material, deposits[material])
        end
        return true, "Materials added"
    end

    nextObject.Parent = object.Parent
    object:Destroy()
    return true, final and "Construction completed" or step.DisplayName
end

return ConstructionService
