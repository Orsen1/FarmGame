local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local config = require(ReplicatedStorage.Configs.OrderConfig)
local definitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local InventoryService = require(script.Parent.InventoryService)
local MoneyService = require(script.Parent.MoneyService)
local Journal = require(script.Parent.FarmJournalService)
local crops = require(ReplicatedStorage.Configs.CropConfig).Crops

local OrderService = {}
local orders = {}
local firstDeliveries = {}
local random = Random.new()
local MAX_INTEGER = 9007199254740991
local MAX_ITEMS = 5

local function integer(value, minimum)
    return typeof(value) == "number" and value >= minimum and value <= MAX_INTEGER and value % 1 == 0
end

local function copyOrder(order)
    local copy = table.clone(order)
    copy.Items = {}
    for index, item in ipairs(order.Items) do
        copy.Items[index] = table.clone(item)
    end
    return copy
end

local function newOrder(boardId)
    local board = config.Boards[boardId]
    local candidates = {}
    for _, itemName in ipairs(board.Items) do
        local item = definitions[itemName]
        if item and integer(item.SellPriceCents, 1) and not table.find(candidates, itemName) then
            table.insert(candidates, itemName)
        end
    end
    local count = random:NextInteger(1, math.min(config.MaxItemsPerOrder, MAX_ITEMS, #candidates))
    local items = {}
    local basePrice = 0
    for index = 1, count do
        local position = random:NextInteger(1, #candidates)
        local itemName = table.remove(candidates, position)
        local amount = board.Amounts[random:NextInteger(1, #board.Amounts)]
        items[index] = {ItemName = itemName, Amount = amount, Delivered = 0}
        basePrice += definitions[itemName].SellPriceCents * amount
    end
    return {
        Id = HttpService:GenerateGUID(false),
        Items = items,
        RewardCents = math.floor(basePrice * (100 + config.BonusPercent) / 100 + 0.5),
        BonusPercent = config.BonusPercent,
    }
end

local function loadOrder(saved)
    if typeof(saved) ~= "table" or typeof(saved.Id) ~= "string" or #saved.Id == 0 or #saved.Id > 64
        or not integer(saved.RewardCents, 1) or not integer(saved.BonusPercent, 0) then
        return nil
    end
    local items = saved.Items
    if items == nil and saved.ItemName ~= nil then
        items = {{ItemName = saved.ItemName, Amount = saved.Amount, Delivered = saved.Delivered}}
    end
    if typeof(items) ~= "table" or #items < 1 or #items > MAX_ITEMS then
        return nil
    end
    local seen = {}
    local remaining = 0
    for _, item in ipairs(items) do
        if typeof(item) ~= "table" or typeof(item.ItemName) ~= "string" or not definitions[item.ItemName]
            or seen[item.ItemName] or not integer(item.Amount, 1) or not integer(item.Delivered, 0)
            or item.Delivered > item.Amount then
            return nil
        end
        seen[item.ItemName] = true
        remaining += item.Amount - item.Delivered
    end
    if remaining == 0 then
        return nil
    end
    return copyOrder({
        Id = saved.Id, Items = items, RewardCents = saved.RewardCents, BonusPercent = saved.BonusPercent,
    })
end

function OrderService.LoadData(player, saved)
    if saved ~= nil and typeof(saved) ~= "table" then
        return false, "Invalid order data"
    end
    local data = {}
    for boardId in pairs(config.Boards) do
        local savedOrder = saved and saved[boardId]
        local order = savedOrder and loadOrder(savedOrder)
        if savedOrder ~= nil and not order then
            return false, "Invalid order: " .. boardId
        end
        data[boardId] = order or newOrder(boardId)
    end
    local first = saved and saved.FarmStand
    if first ~= nil and (typeof(first) ~= "table" or not crops[first.Crop] or
        not integer(first.Goal, 1) or not integer(first.Delivered, 0) or first.Delivered > first.Goal) then
        return false, "Invalid first farm delivery"
    end
    firstDeliveries[player] = first and table.clone(first)
    orders[player] = data
    return true
end

function OrderService.GetData(player)
    local data = orders[player]
    if not data then
        return nil
    end
    local saved = {}
    for boardId, order in pairs(data) do
        saved[boardId] = copyOrder(order)
    end
    if firstDeliveries[player] then saved.FarmStand = table.clone(firstDeliveries[player]) end
    return saved
end

function OrderService.Clear(player)
    orders[player] = nil
    firstDeliveries[player] = nil
end

function OrderService.FirstDelivery(player)
    if not orders[player] or not Journal.TutorialComplete(player) then return end
    if not firstDeliveries[player] then
        local crop = player:GetAttribute("TutorialCropItem")
        firstDeliveries[player] = {Crop = crops[crop] and crop or "Carrot", Goal = config.FirstDeliveryAmount, Delivered = 0}
    end
    return firstDeliveries[player]
end

function OrderService.CanUseMarket(player, market)
    local plot = workspace.Plots:FindFirstChild(player:GetAttribute("PlotName") or "")
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return player:GetAttribute("DataLoaded") == true and not player:GetAttribute("Teleporting") and
        plot and plot:GetAttribute("OwnerUserId") == player.UserId and market and market == plot:FindFirstChild("FarmMarket") and
        market.PrimaryPart and root and humanoid and humanoid.Health > 0 and
        (root.Position - market.PrimaryPart.Position).Magnitude <= config.InteractionDistance
end

function OrderService.LoadWagon(player, wagon)
    local order = firstDeliveries[player]
    if not order or order.Delivered >= order.Goal or not OrderService.CanUseMarket(player, wagon) or
        wagon:GetAttribute("MarketKind") ~= "Wagon" then return false end
    local rows = InventoryService.GetInventory(player)
    if not rows then return false end
    local available = 0
    for _, slot in ipairs(rows) do
        if slot.ItemName == order.Crop then available += slot.Amount end
    end
    local amount = math.min(available, order.Goal - order.Delivered)
    if amount == 0 or not InventoryService.RemoveItem(player, order.Crop, amount) then return false end
    order.Delivered += amount
    return true
end

local function checkAccess(player, boardId)
    if player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true
        or player:GetAttribute("Teleporting") == true or not orders[player] then
        return false, "DataNotReady"
    end
    local definition = typeof(boardId) == "string" and config.Boards[boardId]
    local boards = workspace:FindFirstChild("OrderBoards")
    local board = definition and boards and boards:FindFirstChild(definition.ModelName)
    local root = board and board:FindFirstChild("InteractionRoot")
    if not root or not root:IsA("BasePart") or board:GetAttribute("BoardId") ~= boardId then
        return false, "BoardUnavailable"
    end
    local character = player.Character
    local characterRoot = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not characterRoot or not humanoid or humanoid.Health <= 0
        or (characterRoot.Position - root.Position).Magnitude > config.InteractionDistance then
        return false, "TooFarAway"
    end
    return true
end

function OrderService.Open(player, boardId)
    local allowed, reason = checkAccess(player, boardId)
    if not allowed then
        return nil, reason
    end
    return {BoardId = boardId, Order = copyOrder(orders[player][boardId])}
end

function OrderService.Deliver(player, boardId, orderId)
    if not Journal.TutorialComplete(player) then return false, "Sell your first harvest before delivering Town orders." end
    local allowed, reason = checkAccess(player, boardId)
    if not allowed then
        return false, reason
    end
    local order = orders[player][boardId]
    if typeof(orderId) ~= "string" or order.Id ~= orderId then
        return false, "OrderChanged"
    end
    local inventory = InventoryService.GetInventory(player)
    if not inventory then
        return false, "DataNotReady"
    end
    local available = {}
    for _, slot in ipairs(inventory) do
        available[slot.ItemName] = (available[slot.ItemName] or 0) + slot.Amount
    end
    local inputs = {}
    local total = 0
    local complete = true
    for _, item in ipairs(order.Items) do
        local amount = math.min(available[item.ItemName] or 0, item.Amount - item.Delivered)
        if amount > 0 then
            inputs[item.ItemName] = amount
            total += amount
        end
        if item.Delivered + amount < item.Amount then
            complete = false
        end
    end
    if total == 0 then
        return false, "NoItems"
    end
    if complete and not MoneyService.CanAddMoney(player, order.RewardCents) then
        return false, "BalanceLimit"
    end
    local nextOrder = complete and newOrder(boardId)
    local removed, removeReason, variants = InventoryService.ExchangeItems(player, inputs, {})
    if not removed then
        return false, removeReason
    end
    if complete then
        if not MoneyService.AddMoney(player, order.RewardCents) then
            InventoryService.ExchangeItems(player, {}, inputs, variants)
            return false, "BalanceLimit"
        end
        orders[player][boardId] = nextOrder
        Journal.Record(player, "Order")
        return true, "Completed", order.RewardCents
    end
    for _, item in ipairs(order.Items) do
        item.Delivered += inputs[item.ItemName] or 0
    end
    return true, "Delivered", total
end

return OrderService
