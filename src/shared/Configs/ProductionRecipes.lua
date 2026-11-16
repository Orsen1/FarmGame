local ProductionRecipes = {
    MakeDough = {
        Inputs = {Flour = 5, MilkBucket = 1, Egg = 2},
        InputOrder = {"Flour", "MilkBucket", "Egg"},
        OutputOrder = {"Dough", "Bucket"},
        Outputs = {Dough = 1, Bucket = 1},
        Duration = 20,
        Visual = "Knead"
    },
    BakeBread = {
        Inputs = {Dough = 1},
        Outputs = {Bread = 1},
        Duration = 60,
        Visual = "Bake"
    },
    MilkToCream = {
        Inputs = {MilkBucket = 1},
        Outputs = {Cream = 2},
        Duration = 30,
        Visual = "Separator"
    },
    CreamToButter = {
        Inputs = {Cream = 2},
        Outputs = {Butter = 1},
        Duration = 60,
        Visual = "Churn"
    },
    WheatToFlour = {
        Inputs = {
            Wheat = 1
        },
        Outputs = {
            Flour = 1
        },
        Duration = 5
    },
    BirchToPlank = {
        Inputs = {BirchWood = 1},
        Outputs = {BirchPlank = 3},
        Duration = 5,
        Visual = "SawBirch"
    },
    WoodToPlank = {
        Inputs = {Wood = 1},
        Outputs = {Plank = 3},
        Duration = 5,
        Visual = "SawOak"
    }
}

return ProductionRecipes
