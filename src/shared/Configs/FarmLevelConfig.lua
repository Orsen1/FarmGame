local Config = {
    MaxLevel = 5,
    Levels = {
        {Name = "First Steps", Chapter = "NewBeginning", SectionLimit = 0,
            Reward = {MoneyCents = 100, Items = {WheatSeed = 5}}, Unlocks = {}},
        {Name = "Smallholding", Chapter = "FirstBuildings", SectionLimit = 1,
            Reward = {MoneyCents = 300, Items = {CarrotSeed = 5}},
            Unlocks = {
                {Name = "Garden Bed (10)", Icon = "FieldBed10", Items = {"FieldBed10"}},
                {Name = "Cow Pen", Icon = "CowPenBlueprint", Items = {"CowPenBlueprint", "CowPen"}},
                {Name = "Chicken Coop II", Icon = "ChickenCoopUpgrade", Items = {"ChickenCoopUpgrade", "ChickenCoop2Blueprint", "ChickenCoop2"}},
                {Name = "First land expansion", Icon = "GardenBed"},
            }},
        {Name = "Growing Farm", Chapter = "GrowingFarm", SectionLimit = 3,
            Reward = {MoneyCents = 500, Items = {CornSeed = 5}},
            Unlocks = {
                {Name = "Dairy Workshop", Icon = "DairyBlueprint", Items = {"DairyBlueprint", "Dairy"}},
                {Name = "Two more land expansions", Icon = "GardenBed"},
            }},
        {Name = "Farm Production", Chapter = "ProductionFarm", SectionLimit = 4,
            Reward = {MoneyCents = 800, Items = {WheatSeed = 10}},
            Unlocks = {
                {Name = "Cow Tipper", Icon = "CowTipper", Items = {"CowTipper"}},
                {Name = "Another land expansion", Icon = "GardenBed"},
            }},
        {Name = "Thriving Farm", Chapter = "ScienceFarm", SectionLimit = 5,
            Reward = {MoneyCents = 1500, Items = {PumpkinSeed = 10}},
            Unlocks = {
                {Name = "Crop Laboratory", Icon = "LaboratoryBlueprint", Items = {"LaboratoryBlueprint", "Laboratory"}},
                {Name = "Final land expansion", Icon = "GardenBed"},
            }},
    },
}
local requirements = {}
for level, definition in ipairs(Config.Levels) do
    for _, unlock in ipairs(definition.Unlocks) do
        for _, item in ipairs(unlock.Items or {}) do requirements[item] = level end
    end
end

function Config.RequiredLevel(item)
    return requirements[item] or 1
end

function Config.SectionLevel(number)
    for level, definition in ipairs(Config.Levels) do
        if definition.SectionLimit >= number then return level end
    end
    return Config.MaxLevel
end

function Config.HasAccess(level, item)
    return (level or 1) >= Config.RequiredLevel(item)
end

function Config.GrantLegacy(access, item)
    for _, definition in ipairs(Config.Levels) do
        for _, unlock in ipairs(definition.Unlocks) do
            if unlock.Items and table.find(unlock.Items, item) then
                for _, name in ipairs(unlock.Items) do access[name] = true end
            end
        end
    end
end

return Config
