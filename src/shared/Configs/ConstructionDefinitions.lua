local ConstructionDefinitions = {
    ChickenCoopBlueprint = {
        Stages = {{
            DisplayName = "Foundation",
            Model = "Stage1_Foundation",
            Inputs = {Wood = 5}
        }, {
            DisplayName = "Frame",
            Model = "Stage2_Frame",
            Inputs = {Wood = 10}
        }, {
            DisplayName = "Walls",
            Model = "Stage3_Walls",
            Inputs = {Plank = 12}
        }, {
            DisplayName = "Roof & Finishing",
            Inputs = {Plank = 8}
        }}
    },
    WarehouseBlueprint = {
        Stages = {{
            DisplayName = "Foundation",
            Model = "Stage1_Foundation",

            Inputs = {
                Stone = 20
            }
        }, {
            DisplayName = "Frame",
            Model = "Stage2_Frame",

            Inputs = {
                Wood = 20
            }
        }, {
            DisplayName = "Walls & Roof",
            Model = "Stage3_Walls",

            Inputs = {
                Wood = 15
            }
        }, {
            DisplayName = "Finishing",

            Inputs = {
                Wood = 10,
                Stone = 5
            }
        }}
    }
}

return ConstructionDefinitions
