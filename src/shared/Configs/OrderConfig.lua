return {
    BonusPercent = 30,
    InteractionDistance = 12,
    RequestInterval = 0.25,
    MaxItemsPerOrder = 5,
    Effects = {Particles = 16, Duration = 0.75},
    Boards = {
        Market = {
            ModelName = "MarketBoard",
            DisplayName = "Market Orders",
            Description = "Fresh produce for the village market",
            Amounts = {15, 20, 25, 30},
            Items = {"Carrot", "Potato", "Wheat", "Corn", "Pumpkin", "BellPepper"},
        },
        Kitchen = {
            ModelName = "KitchenBoard",
            DisplayName = "Kitchen Orders",
            Description = "Ingredients for the village kitchen",
            Amounts = {10, 15, 20},
            Items = {"Flour", "Pumpkin", "BellPepper", "Potato", "Wheat", "Corn"},
        },
        Orchard = {
            ModelName = "OrchardBoard",
            DisplayName = "Orchard Orders",
            Description = "Berries for jams and sweet treats",
            Amounts = {10, 15, 20, 25},
            Items = {"Strawberry", "Blueberry", "Flour", "Wheat", "Pumpkin"},
        },
    },
}
