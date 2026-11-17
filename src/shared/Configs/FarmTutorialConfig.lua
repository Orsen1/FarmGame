local Config = {
    Version = 1,
    StartingMoneyCents = 250,
    CompletionRewardCents = 50,
    StarterBeds = {GardenBed = true, FieldBed3 = true},
    Steps = {
        BuyBed = {Order = 1, Title = "Your first garden bed", Icon = "GardenBed", Action = "Open shop",
            Text = "Buy one Garden Bed or Garden Bed (3). Other purchases unlock after your first harvest."},
        BuySeeds = {Order = 2, Title = "Choose your first crop", Icon = "CarrotSeed", Action = "Choose seeds",
            Text = "Buy {capacity} seeds of any one crop. The shop selects the right amount for your bed."},
        BuyCan = {Order = 3, Title = "A little water goes a long way", Icon = "WateringCan", Action = "Buy watering can",
            Text = "Buy one Watering Can. It is reusable and never needs a refill."},
        Place = {Order = 4, Title = "Make room to grow", Icon = "GardenBed", Action = "Select garden bed",
            Text = "Place your bed on your own farm. Rotate it if you like; look for the green preview."},
        Plant = {Order = 5, Title = "Plant your seeds", Icon = "CarrotSeed", Action = "Select seeds",
            Text = "Select your {seed}, walk close to the bed and use Plant. One action fills every spot."},
        Grow = {Order = 6, Title = "Let it grow", Icon = "WateringCan", Action = "Select watering can",
            ShortText = "Wait for the blue drop, then water your bed. Dry crops pause safely.",
            Text = "Wait for the blue water drop over your bed. Growth pauses safely when the plants need water."},
        Water = {Order = 6, Title = "Your crops are thirsty", Icon = "WateringCan", Action = "Select watering can",
            ShortText = "Equip the Watering Can and use Water crops at your bed. One action waters every spot.",
            Text = "Select the Watering Can, approach your bed and use Water crops. One action waters the whole bed."},
        Farm = {Order = 7, Title = "A farm with a future", Icon = "StarterHouse", Action = "See farm levels",
            ShortText = "Explore free farm levels in My Farm. Close the menu to continue.",
            Text = "Finish main journal chapters to level up for free. Open My Farm, explore the unlocks, then close it to continue."},
        Journal = {Order = 8, Title = "Your farm journal", Icon = "CarrotSeed", Action = "Open journal",
            ShortText = "Explore Main chapters and Side stories. Close the journal to continue.",
            Text = "Main chapters unlock farm levels; side stories are optional. Open the journal, then close it when you are ready."},
        Harvest = {Order = 9, Title = "Your first harvest is ready", Icon = "Carrot", Action = "Find your garden bed",
            Text = "Approach the highlighted bed and use Harvest. Different plants can give different amounts and sizes."},
        Sell = {Order = 10, Title = "Turn your harvest into coins", Icon = "Carrot", Action = "Sell your harvest",
            ShortText = "Sell all {remaining} crops first. Town orders unlock after your first sale.",
            Text = "Sell the {remaining} crops from your first harvest. Later, Town order boards pay extra and accept partial deliveries."},
    },
}

function Config.PurchaseAmount(step, itemName, definition, capacity)
    if not step or step == "Complete" then return nil end
    if step == "BuyBed" then return Config.StarterBeds[itemName] and 1 or 0 end
    if step == "BuySeeds" then return definition and definition.Type == "Seed" and capacity or 0 end
    if step == "BuyCan" then return itemName == "WateringCan" and 1 or 0 end
    return 0
end

function Config.Step(data, bed)
    if data.Completed then return "Complete" end
    if not data.BedItem then return "BuyBed" end
    if not data.SeedItem then return "BuySeeds" end
    if not data.CanBought then return "BuyCan" end
    if data.Harvested > data.Sold then return "Sell" end
    if not bed then return "Place" end
    if not data.Planted then return "Plant" end
    if bed.NeedsWater then return "Water" end
    if data.Watered and not data.FarmSeen then return "Farm" end
    if data.Watered and not data.JournalSeen then return "Journal" end
    if bed.Ready then return "Harvest" end
    return "Grow"
end

return Config
