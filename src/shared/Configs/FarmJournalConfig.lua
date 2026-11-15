return {
    Title = "Farm Journal",
    Introduction = "This old farm has been quiet for years. One small step at a time, I can bring it back to life.",
    Chapters = {
        {
            Id = "NewBeginning",
            Title = "A New Beginning",
            Description = "The first seeds are a promise. Give them a little care and bring home the first harvest.",
            Entry = "My first harvest is in. There is still plenty to do, but this place already feels a little more alive.",
            Reward = {MoneyCents = 100, Items = {WheatSeed = 5}},
            Objectives = {
                {Id = "Plant", Text = "Plant your first seeds", Goal = 1, Kind = "Action", Icon = "CarrotSeed", Hint = "Select seeds in your hotbar and use a garden bed."},
                {Id = "Water", Text = "Water a thirsty garden bed", Goal = 1, Kind = "Action", Icon = "WateringCan", Hint = "Buy a Watering Can in Equipment. Use it when the bed needs water."},
                {Id = "Harvest", Text = "Harvest 10 crops", Goal = 10, Kind = "Action", Icon = "Carrot", Hint = "Collect ripe crops from your garden beds. Every fruit counts."},
                {Id = "Sell", Text = "Make your first sale", Goal = 1, Kind = "Action", Icon = "Carrot", Hint = "Bring something to the farm's selling stand."},
            },
        },
        {
            Id = "FirstBuildings",
            Title = "Room to Grow",
            Description = "A farm needs more than fields. Explore the resource world and build a home for tools and supplies.",
            Entry = "The warehouse is finished. I finally have somewhere to keep the things this farm will need.",
            Reward = {MoneyCents = 300, Items = {CarrotSeed = 5}},
            Objectives = {
                {Id = "VisitResources", Text = "Visit the resource world", Goal = 1, Kind = "Action", Icon = "Pickaxe", Hint = "Use the resource world portal. Your journal travels with you."},
                {Id = "GatherWood", Text = "Gather 20 wood", Goal = 20, Kind = "Action", Icon = "Wood", Hint = "Chop oak or birch trees, or collect logs in the resource world."},
                {Id = "GatherStone", Text = "Gather 10 stone", Goal = 10, Kind = "Action", Icon = "Stone", Hint = "Mine rocks or pick up small stones in the resource world."},
                {Id = "Warehouse", Text = "Finish a warehouse", Goal = 1, Kind = "Building", Item = "Warehouse", Icon = "WarehouseBlueprint", Hint = "Buy a Warehouse blueprint in Buildings. Add materials a little at a time."},
            },
        },
        {
            Id = "GrowingFarm",
            Title = "A Place of My Own",
            Description = "The farm is taking shape. Open more land, make space for crops and try a little local trade.",
            Entry = "More land, working tools and a first order delivered. This old farm is becoming my own.",
            Reward = {MoneyCents = 500, Items = {CornSeed = 5}},
            Objectives = {
                {Id = "Expand", Text = "Open another plot section", Goal = 1, Kind = "Sections", Icon = "GardenBed", Hint = "Buy a closed section next to your open land."},
                {Id = "Beds", Text = "Place 3 garden beds", Goal = 3, Kind = "GardenBeds", Icon = "GardenBed", Hint = "Place Garden Beds or FieldBed10s on your own land."},
                {Id = "Order", Text = "Complete a market order", Goal = 1, Kind = "Action", Icon = "Strawberry", Hint = "Visit an order board. You can deliver its ingredients in small batches."},
                {Id = "Sawmill", Text = "Place a sawmill", Goal = 1, Kind = "Building", Item = "Sawmill", Icon = "Sawmill", Hint = "Buy a Sawmill in Buildings and place it on your farm."},
            },
        },
    },
}
