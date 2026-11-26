local Config = {
    StockLimit = 10000,
    MaxDistance = 12,
    PromptDistance = 8,
    PausedVisitRetry = 1,
    Requests = {
        Carrot = {Level = 1, Weight = 1},
        Potato = {Level = 1, Weight = 1},
        Wheat = {Level = 1, Weight = 1},
        Pumpkin = {Level = 5, Weight = 1},
    },
    ReputationLevels = {
        {Sold = 0, VisitInterval = {6, 9}, MinOrder = 2, OrderWeights = {30, 45, 25}},
        {Sold = 10, VisitInterval = {5.75, 8.5}, MinOrder = 2, OrderWeights = {17, 32, 34, 17}},
        {Sold = 20, VisitInterval = {5.5, 8}, MinOrder = 3, OrderWeights = {23, 32, 31, 14}},
        {Sold = 30, VisitInterval = {5.25, 7.5}, MinOrder = 3, OrderWeights = {12, 18, 23, 23, 16, 8}},
        {Sold = 40, VisitInterval = {5, 7}, MinOrder = 4, OrderWeights = {13, 17, 19, 18, 16, 14, 3}},
    },
    FinalSoldGoal = 50,
    RequirementCategories = {
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

function Config.VisitDelay(level, random)
    local interval = Config.ReputationLevels[level].VisitInterval
    return random:NextNumber(interval[1], interval[2])
end

function Config.OrderAmount(level, random)
    local reputation = Config.ReputationLevels[level]
    local weights = reputation.OrderWeights
    local roll = random:NextInteger(1, 100)
    for index, weight in ipairs(weights) do
        roll -= weight
        if roll <= 0 then return reputation.MinOrder + index - 1 end
    end
    return reputation.MinOrder + #weights - 1
end

return Config
