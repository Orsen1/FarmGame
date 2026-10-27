local ItemDefinitions = {
    Carrot = {
        DisplayName = "Морковь",
        Type = "Product",
        SellPriceCents = 5,
        Icon = "rbxassetid://76765094849929"
    },
    CarrotSeed = {
        DisplayName = "Семена моркови",
        Type = "Seed",
        BuyPriceCents = 2,
        PlantId = "Carrot",
        Icon = "rbxassetid://130132495563432",
        ShopCategory = "Seeds"
    },
    Potato = {
        DisplayName = "Картофель",
        Type = "Product",
        SellPriceCents = 8,
        Icon = "rbxassetid://120795864424521"
    },
    PotatoSeed = {
        DisplayName = "Семена картофеля",
        Type = "Seed",
        BuyPriceCents = 4,
        PlantId = "Potato",
        Icon = "rbxassetid://90550923694140",
        ShopCategory = "Seeds"
    },
    Wheat = {
        DisplayName = "Пшеница",
        Type = "Product",
        SellPriceCents = 8,
        Icon = "rbxassetid://84204355593032"
    },
    Flour = {
        DisplayName = "Мука",
        Type = "Product",
        SellPriceCents = 12,
        Icon = "rbxassetid://106543136566763"
    },
    WheatSeed = {
        DisplayName = "Семена пшеницы",
        Type = "Seed",
        BuyPriceCents = 1,
        PlantId = "Wheat",
        Icon = "rbxassetid://86719338895075",
        ShopCategory = "Seeds"
    },
    GardenBed = {
        DisplayName = "Грядка",
        Type = "GardenBed",
        BuyPriceCents = 30,
        Icon = "rbxassetid://114628718599456",
        Placeable = true,
        Plantable = true,
        ShopCategory = "Equipment"
    },
    FieldBed10 = {
        DisplayName = "Грядка 10 мест",
        Type = "GardenBed",
        BuyPriceCents = 100,
        Icon = "rbxassetid://132158221134383",
        Placeable = true,
        Plantable = true,
        ShopCategory = "Equipment"
    },
    HandMill = {
        DisplayName = "Жернов",
        Type = "Tool",
        BuyPriceCents = 50,
        Icon = "rbxassetid://70965951401388",
        ShopCategory = "Equipment",
        Placeable = true,
        Recipes = {"WheatToFlour"},
    },
    Shovel = {
        DisplayName = "Shovel",
        Type = "Tool",
        BuyPriceCents = 1,
        Icon = "rbxassetid://103783030397569",
        ShopCategory = "Equipment"
    }
}

return ItemDefinitions
