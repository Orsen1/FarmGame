return {
    UpdateInterval = 0.2,
    VisualDistance = 150,
    SeparationGap = 0.08,
    Coops = {
        ChickenCoop = {
            ItemName = "Chicken",
            Capacity = 5,
            SpawnAttempts = 40,
            AreaMin = Vector2.new(-4.5, 5.8),
            AreaMax = Vector2.new(4.5, 13),
        }
    },
    Animals = {
        Chicken = {
            Radius = 1.06,
            WalkSpeed = 1.8,
            WalkChance = 0.6,
            SitChance = 0.25,
            TurnAngle = 0.6,
            WalkDistance = Vector2.new(1.2, 3.6),
            StepRate = 9,
            TargetAttempts = 8,
            IdleTime = Vector2.new(1.5, 3.5),
            SitTime = Vector2.new(4, 8),
            LookTime = Vector2.new(2, 4),
        }
    }
}
