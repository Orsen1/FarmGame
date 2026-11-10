local ItemDefinitions = {
    Carrot = {
        DisplayName = "Морковь",
        Type = "Product",
        SellPriceCents = 5,
        Icon = "rbxassetid://76765094849929"
    },
    CarrotSeed = {
        DisplayName = "Carrot Seeds",
        Type = "Seed",
        BuyPriceCents = 2,
        PlantId = "Carrot",
        Icon = "rbxassetid://85530631371345",
        ShopCategory = "Seeds"
    },
    Potato = {
        DisplayName = "Картофель",
        Type = "Product",
        SellPriceCents = 8,
        Icon = "rbxassetid://120795864424521"
    },
    PotatoSeed = {
        DisplayName = "Potato Seeds",
        Type = "Seed",
        BuyPriceCents = 4,
        PlantId = "Potato",
        Icon = "rbxassetid://116900701663231",
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
        DisplayName = "Wheat Seeds",
        Type = "Seed",
        BuyPriceCents = 1,
        PlantId = "Wheat",
        Icon = "rbxassetid://126196049850469",
        ShopCategory = "Seeds"
    },
    Strawberry = {
        DisplayName = "Strawberry",
        Type = "Product",
        SellPriceCents = 15,
        ShowShopIcon = true,
        Icon = "rbxassetid://127742627411355"
    },
    StrawberrySeed = {
        DisplayName = "Strawberry Seeds",
        Type = "Seed",
        BuyPriceCents = 6,
        PlantId = "Strawberry",
        ShowShopIcon = true,
        Icon = "rbxassetid://105364460528767",
        ShopCategory = "Seeds"
    },
    Blueberry = {
        DisplayName = "Blueberry",
        Type = "Product",
        SellPriceCents = 18,
        ShowShopIcon = true,
        Icon = "rbxassetid://119358528005529"
    },
    BlueberrySeed = {
        DisplayName = "Blueberry Seeds",
        Type = "Seed",
        BuyPriceCents = 7,
        PlantId = "Blueberry",
        ShowShopIcon = true,
        Icon = "rbxassetid://70470989949497",
        ShopCategory = "Seeds"
    },
    Corn = {
        DisplayName = "Corn",
        Type = "Product",
        SellPriceCents = 12,
        ShowShopIcon = true,
        Icon = "rbxassetid://99812472423694"
    },
    CornSeed = {
        DisplayName = "Corn Seeds",
        Type = "Seed",
        BuyPriceCents = 5,
        PlantId = "Corn",
        ShowShopIcon = true,
        Icon = "rbxassetid://73295381241741",
        ShopCategory = "Seeds"
    },
    Pumpkin = {
        DisplayName = "Pumpkin",
        Type = "Product",
        SellPriceCents = 24,
        ShowShopIcon = true,
        Icon = "rbxassetid://136316914578267"
    },
    PumpkinSeed = {
        DisplayName = "Pumpkin Seeds",
        Type = "Seed",
        BuyPriceCents = 9,
        PlantId = "Pumpkin",
        ShowShopIcon = true,
        Icon = "rbxassetid://94872052486573",
        ShopCategory = "Seeds"
    },
    BellPepper = {
        DisplayName = "Bell Pepper",
        Type = "Product",
        SellPriceCents = 20,
        ShowShopIcon = true,
        Icon = "rbxassetid://76085404412347"
    },
    BellPepperSeed = {
        DisplayName = "Bell Pepper Seeds",
        Type = "Seed",
        BuyPriceCents = 8,
        PlantId = "BellPepper",
        ShowShopIcon = true,
        Icon = "rbxassetid://94224988595274",
        ShopCategory = "Seeds"
    },
    GardenBed = {
        DisplayName = "Грядка",
        Type = "GardenBed",
        BuyPriceCents = 30,
        Icon = "rbxassetid://114628718599456",
        Placeable = true,
        PlacementSnapGroup = "GardenBed",
        Plantable = true,
        ShopCategory = "Equipment"
    },
    FieldBed10 = {
        DisplayName = "Грядка 10 мест",
        Type = "GardenBed",
        BuyPriceCents = 100,
        Icon = "rbxassetid://132158221134383",
        Placeable = true,
        PlacementSnapGroup = "GardenBed",
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
        Recipes = {"WheatToFlour"}
    },
    Shovel = {
        DisplayName = "Лопата",
        Type = "Tool",
        BuyPriceCents = 1,
        Icon = "rbxassetid://103783030397569",
        ShopCategory = "Equipment"
    },
    Axe = {
        DisplayName = "Axe",
        Type = "Tool",
        BuyPriceCents = 50,
        Icon = "rbxassetid://122173156042257",
        ShopCategory = "Equipment"
    },
    Pickaxe = {
        DisplayName = "Pickaxe",
        Type = "Tool",
        BuyPriceCents = 50,
        Icon = "rbxassetid://119718856891391",
        ShopCategory = "Equipment"
    },
    WarehouseBlueprint = {
        DisplayName = "Warehouse",
        Type = "Blueprint",
        BuyPriceCents = 500,
        Icon = "rbxassetid://90973533858262",
        Placeable = true,
        BuildsInto = "Warehouse",
        ModelFolder = "WarehouseStages",
        ShopCategory = "Equipment"
    },
    Warehouse = {
        DisplayName = "Склад",
        Type = "Building",
        Icon = "",
        Placeable = true,
        StorageSlots = 24
    },
    Wood = {
        DisplayName = "Wood",
        Type = "Material",
        Icon = "rbxassetid://127192346292041"
    },

    Stone = {
        DisplayName = "Stone",
        Type = "Material",
        Icon = "rbxassetid://70839780443591"
    }
}

return ItemDefinitions
