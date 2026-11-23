local levels = require(script.Parent.FarmLevelConfig)
return {
    Title = "Farm Journal",
    Introduction = "A little care, a growing farm. Every chapter is another step.",
    Chapters = {
        {
            Id = "NewBeginning", Category = "Main", Level = 1, Title = "A New Beginning",
            Description = "Plant, care for your crops and bring home the first harvest.",
            Entry = "The first harvest is in. This farm is waking up.",
            Reward = levels.Levels[1].Reward,
            Objectives = {
                {Id = "Plant", Text = "Plant your first seeds", Goal = 1, Kind = "Action", Icon = "CarrotSeed", Hint = "Select seeds and use a garden bed."},
                {Id = "Ripen", Text = "Grow a garden bed", Goal = 1, Kind = "Action", Icon = "WateringCan", Hint = "Let your crops ripen. Watering speeds up growth."},
                {Id = "Harvest", Text = "Harvest 10 crops", Goal = 10, Kind = "Action", Icon = "Carrot", Hint = "Collect ripe crops. Every fruit counts."},
                {Id = "Sell", Text = "Make your first sale", Goal = 1, Kind = "Action", Icon = "Carrot", Hint = "Stock crops at the stand by your farm gate."},
                {Id = "FirstBed", Text = "Place a garden bed", Goal = 1, Kind = "GardenBeds", Icon = "GardenBed", Hint = "Buy a five-spot Garden Bed and place it on your farm."},
            },
        },
        {
            Id = "FirstBuildings", Category = "Main", Level = 2, Title = "Room to Grow",
            Description = "Give your supplies a home, meet an animal and open a little more land.",
            Entry = "There is room here for more than crops.",
            Reward = levels.Levels[2].Reward,
            Objectives = {
                {Id = "Warehouse", Text = "Finish a warehouse", Goal = 1, Kind = "Building", Item = "Warehouse", Icon = "WarehouseBlueprint", Hint = "Build a Warehouse, adding materials in small batches."},
                {Id = "FirstAnimal", Text = "House your first animal", Goal = 1, Kind = "Animals", Icon = "Chicken", Hint = "Add a bought animal to its finished home."},
                {Id = "Expand", Text = "Open another plot section", Goal = 1, Kind = "Sections", Icon = "GardenBed", Hint = "Buy a closed section next to open land."},
                {Id = "Sawmill", Text = "Place a sawmill", Goal = 1, Kind = "Building", Item = "Sawmill", Icon = "Sawmill", Hint = "Buy a Sawmill in Buildings."},
            },
        },
        {
            Id = "GrowingFarm", Category = "Main", Level = 3, Title = "A Place of My Own",
            Description = "Restore the house, grow your animal family and try local trade.",
            Entry = "My farm has a rhythm of its own.",
            Reward = levels.Levels[3].Reward,
            Objectives = {
                {Id = "ProduceFirst", Event = "Produce", Text = "Collect 6 crafted products", Goal = 6, Kind = "Action", Icon = "Plank", Hint = "Collect finished goods from a mill, sawmill, kitchen or dairy."},
                {Id = "Order", Text = "Complete an order", Goal = 1, Kind = "Action", Icon = "Strawberry", Hint = "Visit the Town order boards. Partial deliveries count."},
                {Id = "AnimalFamily", Text = "House 3 animals", Goal = 3, Kind = "Animals", Icon = "Chicken", Hint = "Chickens and cows both count."},
                {Id = "RestoredHome", Text = "Restore the farmhouse", Goal = 1, Kind = "House", Icon = "StarterHouse", Hint = "Bring the materials requested in the home menu."},
            },
        },
        {
            Id = "ProductionFarm", Category = "Main", Level = 4, Title = "Made on the Farm",
            Description = "Turn your harvests into products and build a working dairy.",
            Entry = "Things made here are finding their way to the village.",
            Reward = levels.Levels[4].Reward,
            Objectives = {
                {Id = "DairyHome", Text = "Finish a dairy workshop", Goal = 1, Kind = "Building", Item = "Dairy", Icon = "DairyBlueprint", Hint = "Build a Dairy from its blueprint."},
                {Id = "ProduceBatch", Event = "Produce", Text = "Collect 20 crafted products", Goal = 20, Kind = "Action", Icon = "Butter", Hint = "Collect finished goods from any production station."},
                {Id = "OrdersThree", Event = "Order", Text = "Complete 3 orders", Goal = 3, Kind = "Action", Icon = "Strawberry", Hint = "Any Town order board counts."},
                {Id = "ExpandMore", Text = "Open 3 extra sections", Goal = 3, Kind = "Sections", Icon = "GardenBed", Hint = "Develop the sections available at farm level 3."},
            },
        },
        {
            Id = "ScienceFarm", Category = "Main", Level = 5, Title = "Growing Tomorrow",
            Description = "Explore crop research and celebrate a thriving farm.",
            Entry = "There is always something new to grow.",
            Reward = levels.Levels[5].Reward,
            Objectives = {
                {Id = "LaboratoryHome", Text = "Finish a crop laboratory", Goal = 1, Kind = "Building", Item = "Laboratory", Icon = "LaboratoryBlueprint", Hint = "Build the Crop Laboratory."},
                {Id = "Research", Text = "Complete a successful research", Goal = 1, Kind = "Action", Icon = "LaboratoryBlueprint", Hint = "Upgrade any laboratory research once."},
                {Id = "PlantTwenty", Event = "Plant", Text = "Sow 20 garden beds", Goal = 20, Kind = "Action", Icon = "CarrotSeed", Hint = "Every planted garden bed counts."},
                {Id = "HarvestHundred", Event = "Harvest", Text = "Harvest 100 crops", Goal = 100, Kind = "Action", Icon = "Carrot", Hint = "Keep growing. Every harvested fruit counts."},
            },
        },
        {
            Id = "HarvestSide", Category = "Side", Title = "A Generous Harvest",
            Description = "A little extra care goes a long way.", Entry = "The fields are full of promise.",
            Reward = {MoneyCents = 100, Items = {CarrotSeed = 5}},
            Objectives = {
                {Id = "HarvestFifty", Event = "Harvest", Text = "Harvest 50 crops", Goal = 50, Kind = "Action", Icon = "Carrot", Hint = "Any crop counts."},
                {Id = "Sales", Text = "Earn $10 from sales", Goal = 1000, Kind = "Action", Format = "Money", Icon = "Corn", Hint = "Stock crops at your farm stand for visiting buyers."},
            },
        },
        {
            Id = "ResourceSide", Category = "Side", Title = "Hands at Work",
            Description = "Gather the supplies that make a farm.", Entry = "Every beam and stone has a story.",
            Reward = {MoneyCents = 200, Items = {WheatSeed = 5}},
            Objectives = {
                {Id = "GatherWood", Text = "Gather 50 wood", Goal = 50, Kind = "Action", Icon = "Wood", Hint = "Chop oak or birch trees in the Forest."},
                {Id = "GatherStone", Text = "Gather 50 stone", Goal = 50, Kind = "Action", Icon = "Stone", Hint = "Mine rocks in the Quarry."},
                {Id = "BuildingsThree", Text = "Finish 3 buildings", Goal = 3, Kind = "Buildings", Icon = "WarehouseBlueprint", Hint = "Finished buildings and production stations count."},
            },
        },
        {
            Id = "TradeSide", Category = "Side", Title = "Village Favorite",
            Description = "Good harvests deserve good company.", Entry = "The village knows this farm by name.",
            Reward = {MoneyCents = 300, Items = {CornSeed = 5}},
            Objectives = {
                {Id = "OrdersFive", Event = "Order", Text = "Complete 5 orders", Goal = 5, Kind = "Action", Icon = "Strawberry", Hint = "Any Town board counts."},
                {Id = "SellTwentyFive", Event = "Sell", Text = "Sell 25 crops", Goal = 25, Kind = "Action", Icon = "Carrot", Hint = "Stock crops at your farm stand for visiting buyers."},
            },
        },
    },
}
