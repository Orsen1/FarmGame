local ItemDefinitions = {
    Carrot = {
        DisplayName = "Морковь",
        Type = "Product",
        SellPriceCents = 5,
        Icon = "🥕"
    },
    CarrotSeed = {
        DisplayName = "Семена моркови",
        Type = "Seed",
        BuyPriceCents = 2,
        PlantId = "Carrot",
        Icon = "🌱",
        ShopCategory = "Seeds"
    },
    Potato = {
        DisplayName = "Картофель",
        Type = "Product",
        SellPriceCents = 8,
        Icon = "🥔"
    },
    PotatoSeed = {
        DisplayName = "Семена картофеля",
        Type = "Seed",
        BuyPriceCents = 4,
        PlantId = "Potato",
        Icon = "🌱",
        ShopCategory = "Seeds"
    },
    GardenBed = {
        DisplayName = "Грядка",
        Type = "GardenBed",
        BuyPriceCents = 30,
        Icon = "🪴",
        Placeable = true,
        Plantable = true,
        ShopCategory = "Equipment"
    },
    FieldBed10 = {
        DisplayName = "Грядка 10 мест",
        Type = "GardenBed",
        BuyPriceCents = 100,
        Icon = "🪴",
        Placeable = true,
        Plantable = true,
        ShopCategory = "Equipment"
    },
    Shovel = {
        DisplayName = "Shovel",
        Type = "Tool",
        BuyPriceCents = 1,
        Icon = "🛠",
        ShopCategory = "Equipment"
    }
}

return ItemDefinitions
