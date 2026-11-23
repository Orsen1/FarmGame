local Config = {
    MaxLevel = 15,
    AttemptCooldown = 0.9,
    InteractionDistance = 8,
    Tracks = {
        {Id = "Yield", Name = "Yield", Description = "Favor fuller harvests. Each crop keeps its natural yield limit.", Color = Color3.fromRGB(210, 152, 65)},
        {Id = "Growth", Name = "Growth", Description = "Shorter growing time, with the same watering checkpoints.", Color = Color3.fromRGB(87, 152, 161)},
    },
    Levels = {
        {PriceCents = 10000, Chance = 100, Yield = 8, Growth = 2},
        {PriceCents = 20000, Chance = 95, Yield = 16, Growth = 4},
        {PriceCents = 35000, Chance = 90, Yield = 24, Growth = 6},
        {PriceCents = 55000, Chance = 80, Yield = 32, Growth = 8},
        {PriceCents = 80000, Chance = 70, Yield = 40, Growth = 10},
        {PriceCents = 120000, Chance = 60, Yield = 48, Growth = 12},
        {PriceCents = 180000, Chance = 50, Yield = 56, Growth = 14},
        {PriceCents = 270000, Chance = 40, Yield = 64, Growth = 16},
        {PriceCents = 400000, Chance = 30, Yield = 72, Growth = 18},
        {PriceCents = 600000, Chance = 25, Yield = 80, Growth = 20},
        {PriceCents = 900000, Chance = 20, Yield = 88, Growth = 22},
        {PriceCents = 1400000, Chance = 15, Yield = 96, Growth = 24},
        {PriceCents = 2200000, Chance = 12, Yield = 104, Growth = 26},
        {PriceCents = 3500000, Chance = 10, Yield = 112, Growth = 28},
        {PriceCents = 5500000, Chance = 8, Yield = 120, Growth = 30},
    },
}

function Config.Bonus(track, level)
    local row = Config.Levels[level]
    return row and row[track] or 0
end

function Config.Weighted(weights, bonus)
    local result = {}
    for index, weight in ipairs(weights) do
        result[index] = weight * (1 + bonus / 100 * (index - 1) / math.max(1, #weights - 1))
    end
    return result
end

function Config.Describe(track, level)
    local bonus = Config.Bonus(track, level)
    if track == "Growth" then return string.format("%d%% less growing time", bonus) end
    return string.format("+%d%% high-yield weighting", bonus)
end

return Config
