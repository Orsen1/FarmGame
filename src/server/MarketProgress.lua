local Config = require(game.ReplicatedStorage.Configs.FarmStandConfig)
local Progress = {}
local itemIds = {}
for item in pairs(Config.Requests) do table.insert(itemIds, item) end
table.sort(itemIds)

local function integer(value)
    return typeof(value) == "number" and value >= 0 and value % 1 == 0
end

function Progress.Load(total, saved, now)
    local level = Config.ReputationLevel(total)
    if saved ~= nil then
        if typeof(saved) ~= "table" or not integer(saved.Level) or saved.Level < level or saved.Level > Config.MaxLevel
            or not integer(saved.Revenue) or typeof(saved.Counts) ~= "table" or typeof(saved.Earnings) ~= "table" then return end
        if saved.Path and (not table.find(Config.Directions, saved.Path) or not (Config.Goals[saved.Level + 1] or {}).Paths) then return end
        for item, amount in pairs(saved.Counts) do
            if not Config.Requests[item] or not integer(amount) then return end
        end
        for item, cents in pairs(saved.Earnings) do
            if not Config.Requests[item] or not integer(cents) then return end
        end
        level = saved.Level
    end
    return {Level = level, Counts = saved and table.clone(saved.Counts) or {}, Revenue = saved and saved.Revenue or 0,
        Earnings = saved and table.clone(saved.Earnings) or {}, Path = saved and saved.Path, Events = {}, Held = {}, Started = now}
end

function Progress.Save(p)
    return {Level = p.Level, Counts = table.clone(p.Counts), Earnings = table.clone(p.Earnings), Revenue = p.Revenue, Path = p.Path}
end

local function restart(p, now)
    p.Counts, p.Earnings, p.Held, p.Events, p.Started = {}, {}, {}, {}, now
end

function Progress.Choose(p, direction, now)
    p.Path = direction
    restart(p, now)
end

local timed = {}
local function usesWindow(spec)
    if timed[spec] ~= nil then return timed[spec] end
    local result = spec.Metric == "Rate" or spec.Metric == "SustainedRate"
    for _, child in ipairs(spec.Children or {}) do
        if usesWindow(child) then result = true; break end
    end
    timed[spec] = result
    return result
end

function Progress.Record(p, item, amount, cents, now)
    p.Revenue += cents
    if p.Level == Config.MaxLevel then return end
    local nextGoal = Config.Goals[p.Level + 1]
    if not nextGoal or nextGoal.Paths and not p.Path then return end
    p.Counts[item] = (p.Counts[item] or 0) + amount
    p.Earnings[item] = (p.Earnings[item] or 0) + cents
    if usesWindow(nextGoal.Paths and nextGoal.Paths[p.Path] or nextGoal) then
        table.insert(p.Events, {Time = now, Item = item, Amount = amount})
    end
end

function Progress.Prune(p, now)
    while p.Events[1] and p.Events[1].Time <= now - Config.WindowSeconds do table.remove(p.Events, 1) end
end

local function scopeInfo(scope)
    if scope == "All" then return {Kind = "All"} end
    return {Kind = Config.Requests[scope] and "Item" or "Category", Id = scope}
end

local function evaluate(spec, p, now, key, preview)
    if spec.Children then
        local all = spec.Kind == "All"
        local result = {Id = key, Kind = spec.Kind, Children = {}, Complete = all}
        for i, sub in ipairs(spec.Children) do
            local child = evaluate(sub, p, now, key .. "." .. i, preview)
            table.insert(result.Children, child)
            if child.Complete ~= all then result.Complete = not all end
        end
        return result
    end
    local metric = spec.Metric
    local value = 0
    local row = {Id = key, Metric = metric, Scope = scopeInfo(spec.Scope), Target = spec.Target}
    if metric == "Rate" or metric == "SustainedRate" then
        row.WindowSeconds = Config.WindowSeconds
        if not preview then
            for _, event in ipairs(p.Events) do
                if Config.Matches(spec.Scope, event.Item) then value += event.Amount end
            end
        end
        row.Complete = not preview and now - p.Started >= row.WindowSeconds and value >= spec.Target
        if spec.Seconds then
            local since = row.Complete and (p.Held[key] or now) or nil
            if not preview then p.Held[key] = since end
            local duration = since and math.min(spec.Seconds, math.floor(now - since)) or 0
            row.Duration = {Value = duration, Target = spec.Seconds}
            row.Complete = duration >= spec.Seconds
        end
    else
        if spec.PerItemTarget then row.PerItemTarget, row.Breakdown = spec.PerItemTarget, {} end
        for _, item in ipairs(itemIds) do
            if not Config.Matches(spec.Scope, item) then continue end
            local n = not preview and p.Counts[item] or 0
            if spec.PerItemTarget then
                if n >= spec.PerItemTarget then value += 1 end
                if n > 0 then table.insert(row.Breakdown, {Item = item, Value = n, Target = spec.PerItemTarget, Complete = n >= spec.PerItemTarget}) end
            elseif metric == "Revenue" then
                value += not preview and (p.Earnings[item] or 0) or 0
            else
                value += n
            end
        end
        if spec.Lifetime then value = p.Revenue end
        row.Complete = value >= spec.Target
    end
    row.Value = value
    return row
end

function Progress.Goal(p, total, now, allowed)
    local nextLevel = p.Level + 1
    local base = Config.ReputationLevels[nextLevel]
    if base then
        return {Id = "units_sold", Metric = "Units", Scope = {Kind = "All"}, Value = total, Target = base.Sold, Complete = total >= base.Sold}
    end
    local spec = Config.Goals[nextLevel]
    if not spec then return end
    if not spec.Paths then return evaluate(spec, p, now, tostring(nextLevel), false) end
    local goal = {Id = "directions", Kind = "Paths", ActiveId = p.Path, Options = {}, Complete = false}
    for _, direction in ipairs(Config.Directions) do
        if direction == p.Path or allowed[direction] then
            local category = Config.RequirementCategories[direction]
            local active = direction == p.Path
            local row = evaluate(spec.Paths[direction], p, now, direction, not active)
            table.insert(goal.Options, {Id = direction, Label = category.Name, IconItem = category.IconItem,
                Goal = row, Available = allowed[direction] == true})
            if active then goal.Complete = row.Complete end
        end
    end
    return goal
end

function Progress.Advance(p, now)
    p.Level += 1
    if p.Level >= Config.FirstChoice and (p.Level - Config.FirstChoice) % Config.ChapterLength == 0 then p.Path = nil end
    restart(p, now)
end

function Progress.Focus(row, item)
    if not row or row.Complete then return false end
    if row.Options then
        for _, opt in ipairs(row.Options) do
            if opt.Id == row.ActiveId then return Progress.Focus(opt.Goal, item) end
        end
        return false
    end
    if row.Children then
        for _, child in ipairs(row.Children) do
            if Progress.Focus(child, item) then return true end
        end
        return false
    end
    return Config.Matches(row.Scope.Id or "All", item)
end

return Progress
