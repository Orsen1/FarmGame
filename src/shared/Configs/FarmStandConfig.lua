local Config = {
    StockLimit = 10000,
    MaxDistance = 12,
    PromptDistance = 8,
    VisitInterval = {8, 12},
    PausedVisitRetry = 1,
    ArrivalBonusPerLevel = .01,
    Requests = {
        Carrot = {Level = 1, Weight = 1},
        Potato = {Level = 1, Weight = 1},
        Wheat = {Level = 1, Weight = 1},
        Pumpkin = {Level = 5, Weight = 1},
    },
    ReputationLevels = {
        {Sold = 0, OrderWeights = {40, 36, 24}},
        {Sold = 10, OrderWeights = {38, 35, 23, 4}},
        {Sold = 50, OrderWeights = {35, 34, 23, 8}},
        {Sold = 100, OrderWeights = {33, 33, 23, 9, 2}},
        {Sold = 150, OrderWeights = {30, 32, 24, 10, 4}},
    },
    FinalSoldGoal = 200,
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
    local interval = Config.VisitInterval
    return random:NextNumber(interval[1], interval[2]) / (1 + (level - 1) * Config.ArrivalBonusPerLevel)
end

function Config.OrderAmount(level, random)
    local weights = Config.ReputationLevels[level].OrderWeights
    local roll = random:NextInteger(1, 100)
    for amount, weight in ipairs(weights) do
        roll -= weight
        if roll <= 0 then return amount end
    end
    return #weights
end

return Config
