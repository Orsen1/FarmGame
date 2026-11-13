local Config = {
    UpdateInterval = 0.2,
    VisualDistance = 150,
    SeparationGap = 0.08,
    Coops = {
        ChickenCoop = {
            ItemName = "Chicken",
            PluralName = "Chickens",
            Capacity = 5,
            SpawnAttempts = 40,
            AreaMin = Vector2.new(-4.5, 5.8),
            AreaMax = Vector2.new(4.5, 13),
            DoorLaneWidth = 1.8,
            DoorLaneLength = 2,
            IndoorRadius = 0.65,
            VisitChance = 0.28,
            RestTime = Vector2.new(50, 70),
            OutsideTime = Vector2.new(25, 45),
            Entrance = {Vector3.new(0, 0, 6), Vector3.new(0, 0.04, 4.7),
                Vector3.new(0, 1.28, 1.9), Vector3.new(0, 1.28, 1), Vector3.new(0, 1.28, -0.4)},
            IndoorSpots = {Vector3.new(-1.9, 1.28, -2.2), Vector3.new(1.9, 1.28, -2.2),
                Vector3.new(0, 1.28, -2.45), Vector3.new(-1.9, 1.28, 0.2), Vector3.new(1.9, 1.28, 0.2)},
            FeedItem = "Wheat",
            EatingTime = 1.5,
            EggItem = "Egg",
            EggCapacity = 5,
            EggDuration = 300,
            FedDuration = 180,
            FeedCapacity = 0,
            IndoorMin = Vector2.new(-2.7, -2.8),
            IndoorMax = Vector2.new(2.7, 0.7),
            IndoorWaypoints = {},
        }
    },
    Animals = {
        Cow = {
            Rig = "Quadruped",
            Radius = 3.25,
            WalkSpeed = 1.5,
            WalkChance = 0.65,
            SitChance = 0.18,
            TurnAngle = 0.35,
            WalkDistance = Vector2.new(1.5, 3.8),
            StepRate = 4.2,
            TargetAttempts = 16,
            IdleTime = Vector2.new(3, 6),
            SitTime = Vector2.new(12, 22),
            LookTime = Vector2.new(3, 6),
        },
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

local upgraded = table.clone(Config.Coops.ChickenCoop)
upgraded.Capacity = 10
upgraded.EggCapacity = 10
upgraded.FeedCapacity = 25
upgraded.AreaMin = Vector2.new(-7.2, 8.7)
upgraded.AreaMax = Vector2.new(7.2, 15.2)
upgraded.DoorLaneWidth = 2.4
upgraded.DoorLaneLength = 3.5
upgraded.IndoorMin = Vector2.new(-4, -4.6)
upgraded.IndoorMax = Vector2.new(4, 1)
upgraded.IndoorWaypoints = {Vector3.new(0, 1.92, 0.5), Vector3.new(0, 1.92, -2.85),
    Vector3.new(-3.8, 1.92, -2.85), Vector3.new(3.8, 1.92, -2.85)}
upgraded.Entrance = {Vector3.new(0, 0, 8.7), Vector3.new(0, 0.06, 7.05),
    Vector3.new(0, 1.92, 2.85), Vector3.new(0, 1.92, 1.5), Vector3.new(0, 1.92, 0.5)}
upgraded.IndoorSpots = {}
for _, z in ipairs({-4.3, -1.4}) do
    for _, x in ipairs({-3.8, 3.8, -1.6, 1.6}) do table.insert(upgraded.IndoorSpots, Vector3.new(x, 1.92, z)) end
end
table.insert(upgraded.IndoorSpots, Vector3.new(-3.8, 1.92, 0.9))
table.insert(upgraded.IndoorSpots, Vector3.new(3.8, 1.92, 0.9))
Config.Coops.ChickenCoop2 = upgraded
Config.Coops.ChickenCoop2Blueprint = Config.Coops.ChickenCoop

local cows = table.clone(Config.Coops.ChickenCoop)
cows.ItemName = "Cow"
cows.PluralName = "Cows"
cows.Capacity = 3
cows.SpawnAttempts = 120
cows.SpawnPoints = {Vector3.new(-7, 0, 6), Vector3.new(0, 0, 6), Vector3.new(7, 0, 6)}
cows.AreaMin = Vector2.new(-7.5, 1.5)
cows.AreaMax = Vector2.new(7.5, 8.4)
cows.DoorLaneWidth = 0
cows.DoorLaneLength = 0
cows.IndoorRadius = 3.25
cows.IndoorMin = Vector2.new(-7, -7.5)
cows.IndoorMax = Vector2.new(7, -2.8)
cows.IndoorSpots = {Vector3.new(-6.8, 0.49, -7.2), Vector3.new(0, 0.49, -7.2), Vector3.new(6.8, 0.49, -7.2)}
cows.IndoorWaypoints = {Vector3.new(-6.8, 0.49, -3), Vector3.new(0, 0.49, -3), Vector3.new(6.8, 0.49, -3)}
cows.Entrance = {Vector3.new(6.8, 0, 1.5), Vector3.new(6.8, 0, -1.5), Vector3.new(6.8, 0.49, -3)}
cows.RestYaw = math.pi
cows.FeedItem = "Wheat"
cows.FedDuration = 180
cows.EggItem = nil
cows.EggCapacity = 0
cows.EggDuration = 0
cows.EatingTime = 3
cows.Milking = {
    ProductionDuration = 300,
    Duration = 4,
    AnimationId = "rbxassetid://137284698258607",
    BucketItem = "Bucket",
    OutputItem = "MilkBucket",
    MaxDistance = 10,
    WorkOffset = Vector3.new(2.7, 0, 0.9),
    BucketOffset = Vector3.new(1.6, 0.05, -0.65),
    BucketScale = 0.7,
    HandOffset = Vector3.new(0, 1.1, 0.92),
    CameraOffset = Vector3.new(6, 9, -2),
    CameraTarget = Vector3.new(1, 1.4, -0.4),
    FieldOfView = 50,
}
Config.Coops.CowPen = cows

for _, settings in ipairs({Config.Coops.ChickenCoop, upgraded, cows}) do
    settings.OutdoorWaypoints = {}
    for _, x in ipairs({-1, -0.5, 0, 0.5, 1}) do
        for _, z in ipairs({0, 0.5, 1}) do
            table.insert(settings.OutdoorWaypoints, Vector3.new(settings.AreaMax.X * x, 0,
                settings.AreaMin.Y + (settings.AreaMax.Y - settings.AreaMin.Y) * z))
        end
    end
    table.insert(settings.OutdoorWaypoints, Vector3.new(0, 0, settings.AreaMin.Y - 1.2))
end
table.insert(upgraded.OutdoorWaypoints, Vector3.new(-3, 0, upgraded.AreaMin.Y - 1.2))
table.insert(upgraded.OutdoorWaypoints, Vector3.new(3, 0, upgraded.AreaMin.Y - 1.2))

return Config
