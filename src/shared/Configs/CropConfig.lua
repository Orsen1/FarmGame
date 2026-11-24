local Config = {
    WateringCycles = 3,
    SeedPriceStepCents = 1,
    SeedPriceCapCents = 500,
    WateringCanPriceCents = 100,
    WateringGrowthMultiplier = 1.5,
    VisualDistance = 140,
    Crops = {
        Carrot = {YieldMin = 1, YieldMax = 3, YieldWeights = {65, 28, 7}, GrowthSeconds = 60,
            VisualScale = 1.65, GrowthShape = {0.23, 0.61, 1}, MatureLift = 0.14},
        Potato = {YieldMin = 2, YieldMax = 5, YieldWeights = {25, 45, 25, 5}, GrowthSeconds = 90,
            VisualScale = 1.15, GrowthShape = {0.23, 0.41, 0.61, 0.82, 1}, MatureLift = 0.28},
        Wheat = {YieldMin = 1, YieldMax = 3, YieldWeights = {55, 35, 10}, GrowthSeconds = 60,
            VisualScale = 1.65, GrowthShape = {0.12, 0.27, 0.51, 0.85, 1}},
        Strawberry = {YieldMin = 2, YieldMax = 5, YieldWeights = {30, 40, 25, 5}, GrowthSeconds = 120,
            VisualScale = 1.65},
        Blueberry = {YieldMin = 3, YieldMax = 7, YieldWeights = {20, 35, 30, 12, 3}, GrowthSeconds = 125,
            VisualScale = 1.46},
        Corn = {YieldMin = 1, YieldMax = 3, YieldWeights = {35, 55, 10}, GrowthSeconds = 110,
            VisualScale = 1.4},
        Pumpkin = {YieldMin = 1, YieldMax = 1, YieldWeights = {100}, GrowthSeconds = 150,
            VisualScale = 1.17},
        BellPepper = {YieldMin = 1, YieldMax = 4, YieldWeights = {25, 45, 25, 5}, GrowthSeconds = 120,
            VisualScale = 1.7},
    },
}

function Config.SeedPurchaseAttribute(crop)
    return "SeedPurchases_" .. crop
end

function Config.SeedPrice(basePrice, purchased)
    return math.min(Config.SeedPriceCapCents, basePrice + Config.SeedPriceStepCents * purchased)
end

function Config.SeedTotal(basePrice, purchased, amount)
    local price = Config.SeedPrice(basePrice, purchased)
    local step = Config.SeedPriceStepCents
    local rising = math.min(amount, math.ceil((Config.SeedPriceCapCents - price) / step))
    return rising * price + step * rising * (rising - 1) / 2 + (amount - rising) * Config.SeedPriceCapCents
end

function Config.AffordableSeeds(basePrice, purchased, funds)
    local low, high = 0, math.floor(funds / Config.SeedPrice(basePrice, purchased))
    while low < high do
        local size = low + math.ceil((high - low) / 2)
        if Config.SeedTotal(basePrice, purchased, size) <= funds then
            low = size
        else
            high = size - 1
        end
    end
    return low
end

return Config
