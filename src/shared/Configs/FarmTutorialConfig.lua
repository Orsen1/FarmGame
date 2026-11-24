local Config = {
    Version = 1,
    StartingMoneyCents = 250,
    CompletionRewardCents = 50,
    StarterBed = "FieldBed3",
    FirstCropSeconds = 30,
    GrowthBoostSeconds = 300,
    GrowthBoostMultiplier = 2,
    Steps = {
        BuyBed = {Order = 1, Title = "Your first garden bed", Icon = "FieldBed3", Action = "Open shop",
            Text = "Buy a three-spot garden bed. You can plant one seed or fill the whole row."},
        BuySeeds = {Order = 2, Title = "Choose your first crop", Icon = "CarrotSeed", Action = "Choose seeds",
            Text = "Buy {capacity} seeds of any one crop. The shop selects the right amount for your bed."},
        Place = {Order = 3, Title = "Make room to grow", Icon = "GardenBed", Action = "Select garden bed",
            Text = "Place your bed on your own farm. Rotate it if you like; look for the green preview."},
        Plant = {Order = 4, Title = "Plant your seeds", Icon = "CarrotSeed", Action = "Select seeds",
            Text = "Select your {seed} and use Plant at the bed. Planting uses as many seeds from that slot as will fit."},
        Grow = {Order = 7, Title = "Let it grow", Icon = "WateringCan", Action = "Open equipment",
            Text = "Your crops grow on their own. Water the bed once to speed up three harvests."},
        Farm = {Order = 5, Title = "A farm with a future", Icon = "StarterHouse", Action = "See farm levels",
            ShortText = "Your seeds are growing. Open My Farm to see what level 2 unlocks.",
            Text = "Your seeds are growing. Open My Farm to see the ten-spot bed you can unlock at farm level 2."},
        Journal = {Order = 6, Title = "Your farm journal", Icon = "CarrotSeed", Action = "Open journal",
            ShortText = "Explore Main chapters and Side stories. Close the journal to continue.",
            Text = "Main chapters unlock farm levels; side stories are optional. Open the journal, then close it when you are ready."},
        Harvest = {Order = 8, Title = "Your first harvest is ready", Icon = "Carrot", Action = "Find your garden bed",
            Text = "Use Harvest at the highlighted bed. Your plants will grow back automatically."},
        Sell = {Order = 9, Title = "Open for business", Icon = "Carrot", Action = "Find your stand",
            ShortText = "Stock {remaining} crops at your gate. Buyers will stop by on their own.",
            Text = "Stock the remaining {remaining} crops from your first harvest at your farm stand. Buyers will stop by while you farm."},
    },
}

function Config.PurchaseAmount(step, itemName, definition, capacity, canBought)
    if not step or step == "Complete" then return nil end
    if step == "BuyBed" then return itemName == Config.StarterBed and 1 or 0 end
    if step == "BuySeeds" then return definition and definition.Type == "Seed" and capacity or 0 end
    if itemName == "WateringCan" and not canBought then return 1 end
    return 0
end

function Config.Step(data, bed)
    if data.Completed then return "Complete" end
    if not data.BedItem then return "BuyBed" end
    if not data.SeedItem then return "BuySeeds" end
    if data.Harvested > data.Sold then return "Sell" end
    if not bed then return "Place" end
    if not data.Planted then return "Plant" end
    if not data.FarmSeen then return "Farm" end
    if not data.JournalSeen then return "Journal" end
    if bed.Ready then return "Harvest" end
    return "Grow"
end

return Config
