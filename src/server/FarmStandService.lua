local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Configs.FarmStandConfig)
local crops = require(ReplicatedStorage.Configs.CropConfig).Crops
local items = require(ReplicatedStorage.Configs.ItemDefinitions)
local CropItems = require(ReplicatedStorage.CropItems)
local Inventory = require(script.Parent.InventoryService)
local Money = require(script.Parent.MoneyService)
local Journal = require(script.Parent.FarmJournalService)
local Sell = require(script.Parent.SellService)

local Stand = {}
local states = {}
local random = Random.new()

function Stand.IsOpen(player, model)
    local plot = model.Parent
    return player.Parent == Players and player:GetAttribute("DataLoaded") == true and not player:GetAttribute("Teleporting") and
        plot and plot.Parent == workspace.Plots and plot.Name == player:GetAttribute("PlotName") and
        plot:GetAttribute("OwnerUserId") == player.UserId and model:GetAttribute("OwnerUserId") == player.UserId
end

function Stand.CanReach(player, model)
    if not Stand.IsOpen(player, model) then return false end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return root and humanoid and humanoid.Health > 0 and (root.Position - model.PrimaryPart.Position).Magnitude <= Config.MaxDistance
end

function Stand.Load(player, saved)
    local stock = {}
    if saved ~= nil then
        if typeof(saved) ~= "table" then return false end
        for item, row in pairs(saved) do
            if not crops[item] or not items[item].SellPriceCents or not Inventory.IsValidObjectRow(row) or
                row.ItemName ~= item or row.Amount > Config.StockLimit then return false end
            stock[item] = row
        end
    end
    states[player] = {Stock = stock, Tickets = {}, Reserved = {}}
    return true
end

function Stand.GetData(player)
    local state = states[player]
    return state and table.clone(state.Stock)
end

function Stand.Clear(player)
    states[player] = nil
end

function Stand.Snapshot(player)
    local state = states[player]
    local result = {}
    for item, row in pairs(state.Stock) do result[item] = {Amount = row.Amount} end
    for item, amount in pairs(state.Reserved) do result[item].Reserved = amount end
    return result
end

local function take(row, amount)
    local copy = table.clone(row)
    local groups = CropItems.Take({copy}, row.ItemName, amount)
    return copy.Amount > 0 and copy or nil, groups
end

function Stand.Transfer(player, model, action, item, amount)
    local state = states[player]
    if not state or not Stand.CanReach(player, model) then return false, "Step closer to your stand." end
    if typeof(item) ~= "string" or not crops[item] or not items[item].SellPriceCents or
        typeof(amount) ~= "number" or amount % 1 ~= 0 or amount < 1 or amount > Config.StockLimit then
        return false, "Choose a crop and a valid amount."
    end
    local stock = state.Stock
    local row = stock[item]
    if action == "Stock" then
        local total = (row and row.Amount or 0) + amount
        if total > Config.StockLimit then return false, "The stand is full for this crop." end
        if not Journal.CanSell(player, item, total) then return false, "Stock the rest of your first harvest." end
        local ok, _, removed = Inventory.ExchangeItems(player, {[item] = amount}, {})
        if not ok then return false, "You don't have that many crops." end
        local added = {ItemName = item, Amount = total}
        CropItems.SetGroups(added, CropItems.Merge(row and CropItems.Groups(row) or {}, removed[item]))
        stock[item] = added
        return true, "Stocked " .. amount .. "."
    end
    local reserved = state.Reserved[item] or 0
    if not row or amount > row.Amount - reserved then return false, "That amount is already reserved or sold." end
    local remaining, groups = take(row, amount)
    local ok = Inventory.ExchangeItems(player, {}, {[item] = amount}, {[item] = groups})
    if not ok then return false, "Make room in your inventory first." end
    stock[item] = remaining
    return true, "Returned " .. amount .. "."
end

function Stand.Reserve(player, model)
    local state = states[player]
    if not state or not Stand.IsOpen(player, model) then return end
    local available = {}
    for item, row in pairs(state.Stock) do
        if row.Amount > (state.Reserved[item] or 0) and Journal.CanSell(player, item, 1) then
            table.insert(available, row)
        end
    end
    if #available == 0 then return end
    local row = available[random:NextInteger(1, #available)]
    local batch = row.Amount >= Config.BulkThreshold and Config.BulkBatchSize or Config.BatchSize
    local reserved = state.Reserved[row.ItemName] or 0
    local amount = math.min(row.Amount - reserved, random:NextInteger(batch[1], batch[2]))
    if not Journal.TutorialComplete(player) then
        amount = math.min(amount, (player:GetAttribute("TutorialRemaining") or 0) - reserved)
    end
    if amount <= 0 then return end
    local ticket = {Item = row.ItemName, Amount = amount}
    state.Tickets[ticket] = true
    state.Reserved[ticket.Item] = reserved + amount
    return ticket
end

function Stand.Cancel(player, ticket)
    local state = states[player]
    if not state or not state.Tickets[ticket] then return end
    state.Tickets[ticket] = nil
    local reserved = state.Reserved[ticket.Item] - ticket.Amount
    state.Reserved[ticket.Item] = reserved > 0 and reserved or nil
    return state
end

function Stand.Finish(player, model, ticket)
    local state = Stand.Cancel(player, ticket)
    if not state or not Stand.IsOpen(player, model) or not Journal.CanSell(player, ticket.Item, ticket.Amount) then return end
    local remaining, groups = take(state.Stock[ticket.Item], ticket.Amount)
    local cents = Sell.Price(ticket.Item, groups)
    if not Money.AddMoney(player, cents) then return end
    state.Stock[ticket.Item] = remaining
    Sell.RecordSale(player, ticket.Item, ticket.Amount, cents)
    return cents
end

return Stand
