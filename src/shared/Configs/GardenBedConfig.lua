local Config = {
    Limits = {3, 5, 7, 10, 15},
    Types = {
        GardenBed = {RowWidth = 5, SpotsPerRow = 1, UpgradePrices = {20, 35}},
        FieldBed3 = {RowWidth = 3.6, SpotsPerRow = 3, UpgradePrices = {45, 70}},
        FieldBed5 = {RowWidth = 3.6, SpotsPerRow = 5, UpgradePrices = {75, 110}},
        FieldBed10 = {RowWidth = 3.6, SpotsPerRow = 10, UpgradePrices = {125, 180}},
    },
}

function Config.Limit(level)
    return Config.Limits[level] or Config.Limits[#Config.Limits]
end

function Config.NextLevel(level, owned)
    for index = level + 1, #Config.Limits do
        if Config.Limits[index] > owned then return index end
    end
end

function Config.ValidLevel(item, level)
    local definition = Config.Types[item]
    return definition ~= nil and typeof(level) == "number" and level % 1 == 0 and
        level >= 1 and level <= #definition.UpgradePrices + 1
end

return Config
