local HttpService = game:GetService("HttpService")
local config = require(script.Parent.Configs.CropConfig)
local Items = {}

function Items.Valid(row)
    if row.Variants == nil then return true end
    if not config.Crops[row.ItemName] or typeof(row.Variants) ~= "table" or #row.Variants > 10000 then return false end
    local total, previous = 0, 0
    for index in pairs(row.Variants) do
        if typeof(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #row.Variants then return false end
    end
    for index, group in ipairs(row.Variants) do
        if typeof(group) ~= "table" or typeof(group.Size) ~= "number" or group.Size % 1 ~= 0 or
            group.Size <= previous or group.Size > 10000 or typeof(group.Amount) ~= "number" or
            group.Amount < 1 or group.Amount % 1 ~= 0 or group.Amount > row.Amount then return false end
        previous = group.Size
        total += group.Amount
    end
    return total == row.Amount
end

function Items.Groups(row)
    if row.Variants then
        local copy = {}
        for _, group in ipairs(row.Variants) do table.insert(copy, table.clone(group)) end
        return copy
    end
    return row.Amount > 0 and {{Size = 100, Amount = row.Amount}} or {}
end

function Items.Merge(a, b)
    local counts, result = {}, {}
    for _, list in ipairs({a, b}) do
        for _, group in ipairs(list) do counts[group.Size] = (counts[group.Size] or 0) + group.Amount end
    end
    for size, amount in pairs(counts) do if amount > 0 then table.insert(result, {Size = size, Amount = amount}) end end
    table.sort(result, function(x, y) return x.Size < y.Size end)
    return result
end

function Items.SetGroups(row, groups)
    row.Variants = groups
    if #groups == 0 or #groups == 1 and groups[1].Size == 100 then row.Variants = nil end
end

function Items.Read(slot)
    local encoded = slot:GetAttribute("Variants")
    if encoded == nil then return nil end
    local ok, groups = pcall(HttpService.JSONDecode, HttpService, encoded)
    return ok and groups or false
end

function Items.Write(slot, groups)
    slot:SetAttribute("Variants", groups and HttpService:JSONEncode(groups) or nil)
end

function Items.UnitPrice(base, size)
    if base == 0 then return 0 end
    return math.max(1, math.floor(base * (size / 100) ^ config.PriceExponent + 0.5))
end

function Items.Value(itemName, groups, definitions)
    local base, total = definitions[itemName].SellPriceCents, 0
    for _, group in ipairs(groups) do
        total += (config.Crops[itemName] and Items.UnitPrice(base, group.Size) or base) * group.Amount
    end
    return total
end

function Items.Take(rows, itemName, amount)
    local choices, removed = {}, {}
    for index, row in ipairs(rows) do
        if row.ItemName == itemName then
            if row.ObjectData then return nil, "UseSelectedBuilding" end
            for _, group in ipairs(Items.Groups(row)) do
                table.insert(choices, {Index = index, Size = group.Size, Amount = group.Amount})
            end
        end
    end
    table.sort(choices, function(a, b) return a.Size < b.Size or a.Size == b.Size and a.Index < b.Index end)
    for _, choice in ipairs(choices) do
        if amount <= 0 then break end
        local taken = math.min(amount, choice.Amount)
        local row = rows[choice.Index]
        local groups = Items.Groups(row)
        for _, group in ipairs(groups) do if group.Size == choice.Size then group.Amount -= taken;break end end
        groups = Items.Merge(groups, {})
        row.Amount -= taken
        Items.SetGroups(row, groups)
        if row.Amount == 0 then row.ItemName = "" end
        removed = Items.Merge(removed, {{Size = choice.Size, Amount = taken}})
        amount -= taken
    end
    if amount > 0 then return nil, "NotEnoughItems: " .. itemName end
    return removed
end

return Items
