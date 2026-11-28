local Config = {
    StockLimit = 10000,
    MaxDistance = 12,
    PromptDistance = 8,
    PausedVisitRetry = 1,
    Goals = require(script.Parent.MarketGoals),
    WindowSeconds = 60,
    ChapterLength = 5,
    FirstChoice = 20,
    FocusChance = .70,
    StockChance = .15,
    DoubleRareChance = .30,
    IntervalStep = {.01, .02},
    PartyBonusStep = .05,
    Directions = {"Crops", "Livestock", "Dairy", "Bakery", "Mixed"},
    Requests = {
        Carrot = {Level = 1, Weight = 1, Group = "Vegetables"},
        Potato = {Level = 1, Weight = 1, Group = "Vegetables"},
        Wheat = {Level = 1, Weight = 1, Group = "Grains"},
        Pumpkin = {Level = 5, Weight = 1, Group = "Vegetables"},
        Egg = {Level = 6, Weight = 1, Group = "Livestock", Max = 2},
        Flour = {Level = 7, Weight = 1, Group = "Bakery", Max = 3},
        Strawberry = {Level = 10, Weight = 1, Group = "Berries"},
        Corn = {Level = 10, Weight = 1, Group = "Grains"},
        BellPepper = {Level = 15, Weight = 1, Group = "Vegetables"},
        Cream = {Level = 15, Weight = 1, Group = "Dairy", Max = 2},
        Bread = {Level = 15, Weight = 1, Group = "Bakery", Max = 2},
        Butter = {Level = 20, Weight = 1, Group = "Dairy", Max = 2},
        Blueberry = {Level = 20, Weight = 1, Group = "Berries"},
    },
    ReputationLevels = {
        {Sold = 0, VisitInterval = {6, 9}, MinOrder = 2, OrderWeights = {30, 45, 25}},
        {Sold = 10, VisitInterval = {5.75, 8.5}, MinOrder = 2, OrderWeights = {17, 32, 34, 17}},
        {Sold = 20, VisitInterval = {5.5, 8}, MinOrder = 3, OrderWeights = {23, 32, 31, 14}},
        {Sold = 30, VisitInterval = {5.25, 7.5}, MinOrder = 3, OrderWeights = {12, 18, 23, 23, 16, 8}},
        {Sold = 40, VisitInterval = {5, 7}, MinOrder = 4, OrderWeights = {13, 17, 19, 18, 16, 14, 3}},
    },
    RequirementCategories = {
        Crops = {Name = "Crops", IconItem = "Carrot"},
        Berries = {Name = "Berries", IconItem = "Blueberry"},
        Processed = {Name = "Processed goods", IconItem = "Flour"},
        Mixed = {Name = "Mixed trade", IconItem = "Wheat"},
        Vegetables = {Name = "Vegetables", IconItem = "Carrot"},
        Grains = {Name = "Grains", IconItem = "Wheat"},
        Livestock = {Name = "Animal products", IconItem = "Egg"},
        Dairy = {Name = "Dairy products", IconItem = "MilkBucket"},
        Bakery = {Name = "Baked goods", IconItem = "Bread"},
    },
    QueueLimit = 3,
    QueueSpacing = 4,
    WaitWarning = 7,
    WaitLate = 13,
    Patience = 19,
    MoodTweenDuration = .25,
    RefusalSeconds = .68,
    WalkSpeed = 3.2,
    WalkAnimationSpeed = 6.6,
    TurnSpeed = 5.5,
    FadeDuration = 0.45,
    ServiceSeconds = 2.8,
    IdleAnimation = "rbxassetid://507766666",
    WalkAnimation = "rbxassetid://507777826",
    CoinSound = "rbxasset://sounds/volume_slider.ogg",
    OrderColors = {
        Ready = {Background = Color3.fromRGB(231, 241, 188), Accent = Color3.fromRGB(92, 127, 55), MouthTilt = 25},
        Waiting = {Background = Color3.fromRGB(255, 230, 157), Accent = Color3.fromRGB(166, 109, 35), MouthTilt = 0},
        Late = {Background = Color3.fromRGB(248, 202, 179), Accent = Color3.fromRGB(165, 70, 51), MouthTilt = -25},
        Paid = {Background = Color3.fromRGB(255, 227, 146), Accent = Color3.fromRGB(158, 106, 43)},
    },
}

function Config.ReputationLevel(total)
    for level = #Config.ReputationLevels, 2, -1 do
        if total >= Config.ReputationLevels[level].Sold then return level end
    end
    return 1
end

Config.MaxLevel = #Config.ReputationLevels
while Config.Goals[Config.MaxLevel + 1] do Config.MaxLevel += 1 end

function Config.Matches(scope, item)
    local group = Config.Requests[item].Group
    if scope == "Crops" then return group == "Vegetables" or group == "Grains" or group == "Berries" end
    if scope == "Processed" then return group == "Dairy" or group == "Bakery" end
    return scope == "All" or scope == group or scope == item
end

function Config.Interval(level)
    local base = Config.ReputationLevels[math.min(level, #Config.ReputationLevels)].VisitInterval
    local steps = math.max(0, level - #Config.ReputationLevels)
    return base[1] - steps * Config.IntervalStep[1], base[2] - steps * Config.IntervalStep[2]
end

function Config.VisitDelay(level, random)
    local low, high = Config.Interval(level)
    return random:NextNumber(low, high)
end

function Config.PartyBonus(level)
    return math.max(0, math.floor(level / 5) - 1) * Config.PartyBonusStep
end

function Config.OrderAmount(level, random, item)
    local cap = item and Config.Requests[item].Max
    if cap == 2 then return random:NextNumber() < Config.DoubleRareChance and 2 or 1 end
    if cap then return random:NextInteger(1, cap) end
    local reputation = Config.ReputationLevels[math.min(level, #Config.ReputationLevels)]
    local weights = reputation.OrderWeights
    local roll = random:NextInteger(1, 100)
    for index, weight in ipairs(weights) do
        roll -= weight
        if roll <= 0 then
            local extra = level > 5 and random:NextNumber() < Config.PartyBonus(level) and 1 or 0
            return reputation.MinOrder + math.min(#weights, index + extra) - 1
        end
    end
    return reputation.MinOrder + #weights - 1
end

return Config
