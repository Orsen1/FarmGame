local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Configs.FarmStandConfig)
local Progress = require(script.Parent.MarketProgress)
local items = require(ReplicatedStorage.Configs.ItemDefinitions)
local Inventory = require(script.Parent.InventoryService)
local Money = require(script.Parent.MoneyService)
local Journal = require(script.Parent.FarmJournalService)
local Sell = require(script.Parent.SellService)

local Stand = {}
local states = {}
local random = Random.new()

local function availability(player, state)
    local plot = workspace.Plots:FindFirstChild(player:GetAttribute("PlotName") or "")
    local objects = plot and plot:FindFirstChild("PlacedObjects")
    local buildings, animals = {}, {}
    for _, object in ipairs(objects and objects:GetChildren() or {}) do
        local id = object:GetAttribute("ItemName") or object.Name
        buildings[id] = true
        if (object:GetAttribute("AnimalCount") or 0) > 0 then animals[id] = true end
    end
    local house = plot and plot:FindFirstChild("StarterHouse")
    local eggs = animals.ChickenCoop or animals.ChickenCoop2 or animals.ChickenCoop2Blueprint
    local sources = {
        Egg = eggs, Flour = buildings.HandMill, Cream = buildings.Dairy and animals.CowPen,
        Butter = buildings.Dairy and animals.CowPen,
        Bread = house and (house:GetAttribute("HouseLevel") or -1) >= 0 and buildings.HandMill and eggs and animals.CowPen,
    }
    local available = {}
    for item, request in pairs(Config.Requests) do
        if request.Level <= state.Progress.Level then
            available[item] = state.Stock[item] ~= nil or sources[item] == true or
                Config.Matches("Crops", item) and (request.Level <= 5 or Journal.CanBuy(player, item .. "Seed"))
        end
    end
    local directions = {Crops = true, Livestock = available.Egg, Dairy = available.Cream and available.Butter,
        Bakery = available.Flour and available.Bread, Mixed = available.Egg or available.Flour or available.Cream or available.Butter}
    return available, directions
end

local bonuses = {}
for level = 2, Config.MaxLevel do
    local low, high = Config.Interval(level)
    local rewards = {{Kind = "VisitInterval", Min = low, Max = high}}
    local base = Config.ReputationLevels[level]
    if base then
        table.insert(rewards, {Kind = "OrderSize", Min = base.MinOrder, Max = base.MinOrder + #base.OrderWeights - 1})
    elseif Config.PartyBonus(level) > Config.PartyBonus(level - 1) then
        table.insert(rewards, {Label = string.format("%d%% chance of a larger crop order", math.round(Config.PartyBonus(level) * 100))})
    end
    for item, request in pairs(Config.Requests) do
        if request.Level == level then table.insert(rewards, {Kind = "BuyerRequest", Item = item}) end
    end
    bonuses[level] = rewards
end

local function refresh(player, state, now, advance)
    local p = state.Progress
    Progress.Prune(p, now)
    local goal = Progress.Goal(p, state.TotalUnitsSold, now, state.Directions)
    if advance and goal and goal.Complete then
        Progress.Advance(p, now)
        state.Available, state.Directions = availability(player, state)
        goal = Progress.Goal(p, state.TotalUnitsSold, now, state.Directions)
    end
    state.Goal = goal
    local nextLevel = p.Level < Config.MaxLevel and p.Level + 1 or nil
    local raw = HttpService:JSONEncode({Level = p.Level, MaxLevel = Config.MaxLevel, NextLevel = nextLevel,
        Goal = goal, Bonuses = bonuses[nextLevel]})
    if raw ~= state.LastHUD then
        state.LastHUD = raw
        player:SetAttribute("MarketReputationState", raw)
    end
    player:SetAttribute("MarketReputationLevel", p.Level)
    player:SetAttribute("MarketUnitsSold", state.TotalUnitsSold)
end

function Stand.Choose(player, direction, expectedLevel, previous)
    local state = states[player]
    if not state or not player:GetAttribute("DataLoaded") or player:GetAttribute("Teleporting") or typeof(direction) ~= "string" then return end
    local p = state.Progress
    local spec = Config.Goals[p.Level + 1]
    if not spec or not spec.Paths or p.Level ~= expectedLevel or previous ~= p.Path or direction == p.Path then return end
    state.Available, state.Directions = availability(player, state)
    if state.Directions[direction] ~= true or not spec.Paths[direction] then return end
    local now = os.clock()
    Progress.Choose(p, direction, now)
    refresh(player, state, now, false)
end

function Stand.Tick()
    local now = os.clock()
    for player, state in pairs(states) do
        if player:GetAttribute("DataLoaded") and (#state.Progress.Events > 0 or next(state.Progress.Held)) then
            refresh(player, state, now, true)
        end
    end
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

function Stand.Load(player, saved, totalSold, reputation)
    if totalSold == nil then totalSold = 0 end
    if typeof(totalSold) ~= "number" or totalSold < 0 or totalSold % 1 ~= 0 then return false end
    local stock = {}
    if saved ~= nil then
        if typeof(saved) ~= "table" then return false end
        for item, row in pairs(saved) do
            if not Config.Requests[item] or not items[item].SellPriceCents or not Inventory.IsValidObjectRow(row) or
                row.ItemName ~= item or row.Amount > Config.StockLimit then return false end
            stock[item] = {ItemName = item, Amount = row.Amount}
        end
    end
    local now = os.clock()
    local p = Progress.Load(totalSold, reputation, now)
    if not p then return false end
    local state = {Stock = stock, Tickets = {}, Reserved = {}, TotalUnitsSold = totalSold, Progress = p}
    states[player] = state
    state.Available, state.Directions = availability(player, state)
    refresh(player, state, now, false)
    return true
end

function Stand.GetData(player)
    local state = states[player]
    if state then return table.clone(state.Stock), state.TotalUnitsSold, Progress.Save(state.Progress) end
end

function Stand.VisitDelay(player)
    return Config.VisitDelay(states[player].Progress.Level, random)
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
    if typeof(item) ~= "string" or not Config.Requests[item] or not items[item].SellPriceCents or
        typeof(amount) ~= "number" or amount % 1 ~= 0 or amount < 1 or amount > Config.StockLimit then
        return false, "Choose a product and a valid amount."
    end
    local stock = state.Stock
    local row = stock[item]
    if action == "Stock" then
        local total = (row and row.Amount or 0) + amount
        if total > Config.StockLimit then return false, "The stand is full for this product." end
        if not Journal.CanSell(player, item, total) then return false, "Stock the rest of your first harvest." end
        if Journal.TutorialComplete(player) then
            local request = Config.Requests[item]
            if not request or request.Weight <= 0 then return false, "Buyers do not request this product." end
            if state.Progress.Level < request.Level then
                return false, "Buyers request this product at market level " .. request.Level .. "."
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

function Stand.CreateOrder(player, model)
    local state = states[player]
    if not state or not Stand.IsOpen(player, model) then return end
    local level = state.Progress.Level
    local tutorial = not Journal.TutorialComplete(player)
    local amount, item
    if tutorial then
        item = player:GetAttribute("TutorialCropItem")
        local remaining = player:GetAttribute("TutorialRemaining") or 0
        for ticket in pairs(state.Tickets) do
            if ticket.Tutorial then remaining -= ticket.Amount end
        end
        amount = math.min(Config.OrderAmount(level, random), remaining)
        if amount <= 0 or not Journal.CanSell(player, item, amount) then return end
    else
        if level > 5 then state.Available, state.Directions = availability(player, state) end
        if level >= Config.FirstChoice then refresh(player, state, os.clock(), false) end
        local choices, stocked, focused = {}, {}, {}
        for id, enabled in pairs(state.Available) do
            if not enabled then continue end
            table.insert(choices, id)
            local free = (state.Stock[id] and state.Stock[id].Amount or 0) - (state.Reserved[id] or 0)
            if free >= (Config.Requests[id].Max and 1 or 4) then
                table.insert(stocked, id)
                if Progress.Focus(state.Goal, id) then table.insert(focused, id) end
            end
        end
        if #choices == 0 then return end
        local roll = random:NextNumber()
        local fromStock = false
        if level > 5 and roll < Config.FocusChance and #focused > 0 then
            choices, fromStock = focused, true
            if state.Progress.Path == "Mixed" then
                local produce, other = {}, {}
                for _, id in ipairs(focused) do
                    table.insert(Config.Matches("Crops", id) and produce or other, id)
                end
                if #produce > 0 and #other > 0 then choices = random:NextNumber() < .5 and produce or other end
            end
        elseif level > 5 and roll < Config.FocusChance + Config.StockChance and #stocked > 0 then
            choices, fromStock = stocked, true
        end
        item = choices[random:NextInteger(1, #choices)]
        amount = Config.OrderAmount(level, random, item)
        if fromStock then amount = math.min(amount, state.Stock[item].Amount - (state.Reserved[item] or 0)) end
    end
    local ticket = {Item = item, Amount = amount, Model = model, Tutorial = tutorial}
    state.Tickets[ticket] = false
    return ticket
end

function Stand.TryReserve(player, model, ticket)
    local state = states[player]
    if not state or state.Tickets[ticket] ~= false or ticket.Model ~= model or not Stand.IsOpen(player, model) or
        not Journal.CanSell(player, ticket.Item, ticket.Amount) then return false end
    local item = ticket.Item
    local row = state.Stock[item]
    local reserved = state.Reserved[item] or 0
    if not row or row.Amount - reserved < ticket.Amount then return false end
    state.Tickets[ticket] = true
    state.Reserved[item] = reserved + ticket.Amount
    return true
end

function Stand.Cancel(player, ticket)
    local state = states[player]
    if not state or state.Tickets[ticket] == nil then return end
    local locked = state.Tickets[ticket]
    state.Tickets[ticket] = nil
    if locked then
        local reserved = state.Reserved[ticket.Item] - ticket.Amount
        state.Reserved[ticket.Item] = reserved > 0 and reserved or nil
    end
    return state, locked
end

function Stand.Finish(player, model, ticket)
    if ticket.Model ~= model then return end
    local state, locked = Stand.Cancel(player, ticket)
    if not locked or not Stand.IsOpen(player, model) or not Journal.CanSell(player, ticket.Item, ticket.Amount) then return end
    local cents = Sell.Price(ticket.Item, ticket.Amount)
    if not Money.AddMoney(player, cents) then return end
    debit(state.Stock, ticket.Item, ticket.Amount)
    state.TotalUnitsSold += ticket.Amount
    local now = os.clock()
    Progress.Prune(state.Progress, now)
    if next(state.Progress.Held) then
        Progress.Goal(state.Progress, state.TotalUnitsSold - ticket.Amount, now, state.Directions)
    end
    Progress.Record(state.Progress, ticket.Item, ticket.Amount, cents, now)
    refresh(player, state, now, true)
    Sell.RecordSale(player, ticket.Item, ticket.Amount, cents)
    return cents
end

return Stand
