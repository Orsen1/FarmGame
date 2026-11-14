local ProductionRecipes = {
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
    WoodToPlank = {
        Inputs = {Wood = 1},
        Outputs = {Plank = 3},
        Duration = 5
    }
}

return ProductionRecipes
