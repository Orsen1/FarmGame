local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Configs.FarmStandConfig)
local crops = require(ReplicatedStorage.Configs.CropConfig).Crops
local items = require(ReplicatedStorage.Configs.ItemDefinitions)
local Inventory = require(script.Parent.InventoryService)
local Money = require(script.Parent.MoneyService)
local Journal = require(script.Parent.FarmJournalService)
local Sell = require(script.Parent.SellService)

local Stand = {}
local states = {}
local random = Random.new()

local function requestLevel(item)
    return crops[item] and items[item].SellPriceCents and Config.RequestLevels[item]
end

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

function Stand.Load(player, saved, totalSold)
    if totalSold == nil then totalSold = 0 end
    if typeof(totalSold) ~= "number" or totalSold < 0 or totalSold % 1 ~= 0 then return false end
    local stock = {}
    if saved ~= nil then
        if typeof(saved) ~= "table" then return false end
        for item, row in pairs(saved) do
            if not crops[item] or not items[item].SellPriceCents or not Inventory.IsValidObjectRow(row) or
                row.ItemName ~= item or row.Amount > Config.StockLimit then return false end
            stock[item] = {ItemName = item, Amount = row.Amount}
        end
    end
    states[player] = {Stock = stock, Tickets = {}, Reserved = {}, TotalUnitsSold = totalSold}
    player:SetAttribute("MarketUnitsSold", totalSold)
    return true
end

function Stand.GetData(player)
    local state = states[player]
    if state then return table.clone(state.Stock), state.TotalUnitsSold end
end

function Stand.VisitDelay(player)
    return Config.VisitDelay(Config.ReputationLevel(states[player].TotalUnitsSold), random)
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

local function debit(stock, item, amount)
    local row = stock[item]
    row.Amount -= amount
    if row.Amount == 0 then stock[item] = nil end
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
        if Journal.TutorialComplete(player) then
            local required = requestLevel(item)
            if not required then return false, "Buyers do not request this crop." end
            if Config.ReputationLevel(state.TotalUnitsSold) < required then
                return false, "Buyers request this crop at market level " .. required .. "."
            end
        end
        local ok = Inventory.ExchangeItems(player, {[item] = amount}, {})
        if not ok then return false, "You don't have that many crops." end
        stock[item] = {ItemName = item, Amount = total}
        return true, "Stocked " .. amount .. "."
    end
    local reserved = state.Reserved[item] or 0
    if not row or amount > row.Amount - reserved then return false, "That amount is already reserved or sold." end
    local ok = Inventory.ExchangeItems(player, {}, {[item] = amount})
    if not ok then return false, "Make room in your inventory first." end
    debit(stock, item, amount)
    return true, "Returned " .. amount .. "."
end

function Stand.Reserve(player, model)
    local state = states[player]
    if not state or not Stand.IsOpen(player, model) then return end
    local level = Config.ReputationLevel(state.TotalUnitsSold)
    local tutorial = not Journal.TutorialComplete(player)
    local orderLimit = Config.OrderAmount(level, random)
    local available = {}
    for item, row in pairs(state.Stock) do
        local reserved = state.Reserved[item] or 0
        local amount = math.min(row.Amount - reserved, orderLimit)
        if tutorial then
            amount = math.min(amount, (player:GetAttribute("TutorialRemaining") or 0) - reserved)
        elseif (requestLevel(item) or math.huge) > level then
            continue
        end
        if amount > 0 and Journal.CanSell(player, item, amount) then
            table.insert(available, {Item = item, Amount = amount})
        end
    end
    if #available == 0 then return end
    local ticket = available[random:NextInteger(1, #available)]
    state.Tickets[ticket] = true
    state.Reserved[ticket.Item] = (state.Reserved[ticket.Item] or 0) + ticket.Amount
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
    local cents = Sell.Price(ticket.Item, ticket.Amount)
    if not Money.AddMoney(player, cents) then return end
    debit(state.Stock, ticket.Item, ticket.Amount)
    state.TotalUnitsSold += ticket.Amount
    player:SetAttribute("MarketUnitsSold", state.TotalUnitsSold)
    Sell.RecordSale(player, ticket.Item, ticket.Amount, cents)
    return cents
end

return Stand
