return {
    Environment = {
        ClockTime = 14.2, Brightness = 2.5,
        Ambient = Color3.fromRGB(125, 133, 140), OutdoorAmbient = Color3.fromRGB(145, 150, 135),
        FogStart = 420, FogEnd = 950
    },
    Spawn = {
        PlayerCap = 25,
        GrowthExponent = 0.6,
        MinimumInterval = 0.8,
        CellSpacing = 11,
        PreferredChance = 0.9,
        CellCooldown = 12,
        PlayerClearance = 10,
        Families = {
            Trees = {Zone = "Forest", Count = 20, Interval = 8, Variants = {
                {Id = "Oak", Weight = 65}, {Id = "Birch", Weight = 35}
            }},
            Rocks = {Zone = "Quarry", Count = 24, Interval = 4, Variants = {
                {Id = "Pebble", Weight = 30}, {Id = "Stone", Weight = 35},
                {Id = "LargeBoulder", Weight = 20}, {Id = "IronVein", Weight = 15, Zone = "Mine"}
            }},
            Lumber = {Zone = "LumberYard", Count = 3, Interval = 35, Variants = {
                {Id = "LogBundle", Weight = 60}, {Id = "BirchBundle", Weight = 25}, {Id = "PlankBundle", Weight = 15}
            }}
        }
    },
    Birch = {
        DisplayName = "Birch", ActionText = "Chop", Tool = "Axe",
        RewardItem = "BirchWood", RewardAmount = 3, HoldDuration = 3, MaxDistance = 7,
        Swing = "Chop", SwingInterval = 1, StandDistance = 1.95
    },
    IronVein = {
        DisplayName = "Iron Ore", ActionText = "Mine", Tool = "Pickaxe",
        RewardItem = "IronOre", RewardAmount = 2, HoldDuration = 4, MaxDistance = 7,
        Swing = "Mine", SwingInterval = 1, StandDistance = 2.1
    },
    LogBundle = {DisplayName = "Logs", ActionText = "Collect", RewardItem = "Wood", RewardAmount = 3, HoldDuration = 0, MaxDistance = 5},
    BirchBundle = {DisplayName = "Birch Logs", ActionText = "Collect", RewardItem = "BirchWood", RewardAmount = 2, HoldDuration = 0, MaxDistance = 5},
    PlankBundle = {DisplayName = "Planks", ActionText = "Collect", RewardItem = "Plank", RewardAmount = 2, HoldDuration = 0, MaxDistance = 5},
    Oak = {
        DisplayName = "Oak",
        ActionText = "Chop",
        Tool = "Axe",
        RewardItem = "Wood",
        RewardAmount = 3,
        HoldDuration = 3,
        MaxDistance = 7,
        Swing = "Chop",
        SwingInterval = 1,
        StandDistance = 1.95,
    },
    Stone = {
        DisplayName = "Stone",
        ActionText = "Mine",
        Tool = "Pickaxe",
        RewardItem = "Stone",
        RewardAmount = 3,
        HoldDuration = 3,
        MaxDistance = 7,
        Swing = "Mine",
        SwingInterval = 1,
        StandDistance = 2.10,
    },
    LargeBoulder = {
        DisplayName = "Large Boulder",
        ActionText = "Mine",
        Tool = "Pickaxe",
        RewardItem = "Stone",
        RewardAmount = 5,
        HoldDuration = 3,
        MaxDistance = 8,
        Swing = "Mine",
        SwingInterval = 1,
        StandDistance = 2.28,
    },
    Pebble = {
        DisplayName = "Pebble",
        ActionText = "Pick Up",
        RewardItem = "Stone",
        RewardAmount = 1,
        HoldDuration = 0,
        MaxDistance = 5,
    },
}
