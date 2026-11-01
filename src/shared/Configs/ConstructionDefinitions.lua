local ConstructionDefinitions = {
    WarehouseBlueprint = {
        Stages = {{
            DisplayName = "Фундамент",
            Model = "Stage1_Foundation",

            Inputs = {
                Stone = 20
            }
        }, {
            DisplayName = "Каркас",
            Model = "Stage2_Frame",

            Inputs = {
                Wood = 20
            }
        }, {
            DisplayName = "Стены и крыша",
            Model = "Stage3_Walls",

            Inputs = {
                Wood = 15
            }
        }, {
            DisplayName = "Завершение строительства",

            Inputs = {
                Wood = 10,
                Stone = 5
            }
        }}
    }
}

return ConstructionDefinitions
