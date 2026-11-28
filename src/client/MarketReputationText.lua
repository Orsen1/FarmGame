local ReplicatedStorage = game:GetService("ReplicatedStorage")
local configs = ReplicatedStorage:WaitForChild("Configs")
local items = require(configs:WaitForChild("ItemDefinitions"))
local market = require(configs:WaitForChild("FarmStandConfig"))
local categories = market.RequirementCategories

local Text = {}

local function integer(value)
    local digits = string.format("%.0f", value)
    return (digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function duration(seconds)
    local minutes, remainder = math.floor(seconds / 60), math.floor(seconds) % 60
    if minutes == 0 then return remainder .. "s" end
    if remainder == 0 then return minutes .. "m" end
    return string.format("%dm %02ds", minutes, remainder)
end

local abbreviations = {{1e15, "Q"}, {1e12, "T"}, {1e9, "B"}, {1e6, "M"}}
local function abbreviated(value)
    for _, range in ipairs(abbreviations) do
        if value >= range[1] then
            local rounded = string.format("%.1f", value / range[1]):gsub("%.0$", "")
            return rounded .. range[2]
        end
    end
end

local function valueText(value, unit, compact)
    if unit == "Seconds" then return duration(value) end
    if unit == "Cents" then
        local short = compact and abbreviated(value / 100)
        if short then return "$" .. short end
        return "$" .. integer(math.floor(value / 100)) .. string.format(".%02d", value % 100)
    end
    return (compact and abbreviated(value)) or integer(value)
end

local function progress(current, target, unit, compact)
    local suffix = unit == "ItemsPerMinute" and " per min" or unit == "Kinds" and " types" or ""
    return valueText(current, unit, compact) .. (compact and "/" or " / ") .. valueText(target, unit, compact) .. suffix
end

local function itemIcon(id)
    local item = items[id]
    return item and item.Icon
end

local function scopeInfo(scope)
    if not scope then return "goods" end
    local item = scope.Kind == "Item" and items[scope.Id]
    if item then return item.DisplayName, item.Icon end
    local category = scope.Kind == "Category" and categories[scope.Id]
    if category then return category.Name:lower(), itemIcon(category.IconItem) end
    return scope.Label or "goods", itemIcon(scope.IconItem)
end

local headings = {All = "Complete all", Any = "Complete any"}
local units = {Units = "Items", Rate = "ItemsPerMinute", SustainedRate = "ItemsPerMinute", Diversity = "Kinds", Revenue = "Cents"}

local function requirement(node, key, detailed, depth)
    local scope, icon = scopeInfo(node.Scope)
    local metric, unit = node.Metric, node.Unit or units[node.Metric]
    local action = "Sell " .. scope
    if metric == "Rate" then action = "Sell " .. scope .. " per minute"
    elseif metric == "SustainedRate" then action = "Keep up sales of " .. scope
    elseif metric == "Revenue" then action = "Earn from " .. scope
    elseif metric == "Diversity" then
        action = node.PerItemTarget and string.format("Sell %s of each kind", integer(node.PerItemTarget)) or "Sell different goods"
    end
    local detail
    if node.WindowSeconds and detailed then detail = "Measured over the last " .. duration(node.WindowSeconds) end
    if node.Duration then
        local time = "Time  " .. progress(node.Duration.Value, node.Duration.Target, "Seconds", not detailed)
        detail = detail and (detail .. "  ·  " .. time) or time
    end
    return {Key = key, Title = node.Label or action, Icon = icon, Complete = node.Complete, Depth = depth,
        Detail = detail, Value = progress(node.Value, node.Target, unit, not detailed),
        Ratio = node.Target > 0 and math.clamp(node.Value / node.Target, 0, 1) or nil}
end

local function heading(rows, key, title, icon, detail, depth)
    table.insert(rows, {Key = key, Title = title, Icon = icon, Detail = detail, Heading = true, Depth = depth})
end

local function preview(spec, id)
    if spec.Children then
        local node = {Id = id, Kind = spec.Kind, Children = {}}
        for index, child in ipairs(spec.Children) do table.insert(node.Children, preview(child, tostring(index))) end
        return node
    end
    local scope = spec.Scope
    return {Id = id, Metric = spec.Metric, Target = spec.Target, Value = 0, PerItemTarget = spec.PerItemTarget,
        Scope = {Kind = scope == "All" and "All" or market.Requests[scope] and "Item" or "Category", Id = scope},
        Duration = spec.Seconds and {Value = 0, Target = spec.Seconds}}
end

local function addNode(rows, node, parent, detailed, depth, selected, level)
    if not node then return end
    local key = parent .. "/" .. node.Id
    if node.Kind == "Paths" then
        for _, option in ipairs(node.Options) do
            local active = option.Id == node.ActiveId
            if detailed or active then
                local path = key .. "/" .. option.Id
                local hint = active and "Active direction" or "Preview and choose"
                if active and option.Available == false then hint = "Production unavailable. Choose another direction or restock." end
                if selected == option.Id then
                    hint = node.ActiveId and "Confirm switch · resets this level’s progress" or "Confirm this direction"
                end
                heading(rows, path, option.Label, itemIcon(option.IconItem), hint, depth)
                if detailed and not active and option.Available then rows[#rows].Direction = option.Id end
                addNode(rows, option.Goal, path, detailed, depth + 1)
                if detailed and selected == option.Id then
                    local last = level + market.ChapterLength - (level - market.FirstChoice) % market.ChapterLength
                    for n = level + 2, math.min(last, market.MaxLevel) do
                        heading(rows, path .. n, "Level " .. n)
                        addNode(rows, preview(market.Goals[n].Paths[option.Id], tostring(n)), path, true, depth + 1)
                    end
                end
            end
        end
    elseif node.Children then
        if detailed or parent ~= "" then
            heading(rows, key, node.Label or headings[node.Kind] or "Requirements", nil, nil, depth)
        end
        for _, child in ipairs(node.Children) do addNode(rows, child, key, detailed, depth + 1) end
    else
        table.insert(rows, requirement(node, key, detailed, depth))
        for _, part in ipairs(detailed and node.Breakdown or {}) do
            local item = items[part.Item]
            table.insert(rows, {Key = key .. "/" .. part.Item, Title = item and item.DisplayName or part.Item,
                Icon = itemIcon(part.Item), Complete = part.Complete, Depth = depth + 1,
                Value = progress(part.Value, part.Target, "Items", false)})
        end
    end
end

local function bonus(entry)
    if entry.Kind == "VisitInterval" then
        return string.format("Buyers arrive every %g–%g seconds", entry.Min, entry.Max)
    elseif entry.Kind == "OrderSize" then
        return string.format("Orders of %d–%d items", entry.Min, entry.Max)
    elseif entry.Kind == "BuyerRequest" then
        local item = items[entry.Item]
        return "Buyers can ask for " .. (item and item.DisplayName or entry.Item), itemIcon(entry.Item)
    end
    return entry.Label, itemIcon(entry.IconItem)
end

function Text.Rows(state, detailed, selected)
    local rows = {}
    if not state then return rows, "Loading reputation…" end
    local goal = state.Goal
    local caption = state.NextLevel and ("Next  Lv. " .. state.NextLevel)
        or goal and state.FinalGoal and not goal.Complete and "Max level · Final goal"
        or "Max level reached"
    if goal and goal.Kind == "Paths" and not goal.ActiveId then
        caption = "Choose a direction"
        if not detailed then heading(rows, goal.Id, string.format("%d paths available", #goal.Options)) end
    elseif goal and goal.Children and headings[goal.Kind] then
        caption = headings[goal.Kind]
        if goal.Kind == "All" then
            local complete = 0
            for _, child in ipairs(goal.Children) do if child.Complete then complete += 1 end end
            caption ..= string.format("  %d/%d", complete, #goal.Children)
        end
    end
    addNode(rows, goal, "", detailed, 0, selected, state.Level)
    if detailed and state.Bonuses and #state.Bonuses > 0 then
        heading(rows, "bonuses", "Next level bonuses")
        for index, entry in ipairs(state.Bonuses) do
            local label, icon = bonus(entry)
            if label then table.insert(rows, {Key = "bonus/" .. index, Title = label, Icon = icon}) end
        end
    end
    return rows, caption
end

return Text
