return {
    MigrationVersion = 1,
    BoundaryGap = 4,
    Objects = {
        {Id = "Oven", DisplayName = "Oven", MinimumLevel = 0},
        {Id = "Worktable", DisplayName = "Kitchen table", MinimumLevel = 0},
    },
    Levels = {
        [0] = {
            DisplayName = "Restore farmhouse",
            Model = "StarterHouseRestored",
            Stages = {{Inputs = {Wood = 30, Plank = 40, Stone = 15}}},
        },
    },
    ExteriorDistance = 36,
    ExteriorPortraitDistance = 56,
    OrbitSensitivity = 0.006,
    BoundsMin = Vector3.new(-9.6, 0, -7.5),
    BoundsMax = Vector3.new(14.8, 17, 13.7),
    Footprints = {
        {Center = Vector3.new(0, 0, 0), Size = Vector3.new(18.5, 17, 14.2)},
        {Center = Vector3.new(10.9, 0, -0.4), Size = Vector3.new(7.8, 10, 12.8)},
        {Center = Vector3.new(-1.9, 0, 8.65), Size = Vector3.new(9.6, 9, 5.8)},
        {Center = Vector3.new(-2, 0, 12.4), Size = Vector3.new(4.1, 2, 2.7)},
        {Center = Vector3.new(4.2, 0, 9), Size = Vector3.new(1.8, 2, 1.8)},
        {Center = Vector3.new(12.4, 0, 6.1), Size = Vector3.new(1.7, 2, 1.7)},
    },
}
