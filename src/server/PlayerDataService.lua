local DataStoreService = game:GetService("DataStoreService")
local dataStore = DataStoreService:GetDataStore("FarmGame_MoneyInventory")
local houseConfig = require(game.ReplicatedStorage.Configs.StarterHouseConfig)
local tutorialConfig = require(game.ReplicatedStorage.Configs.FarmTutorialConfig)

local function sameData(left, right)
    if left == right then return true end
    if typeof(left) ~= "table" or typeof(right) ~= "table" then return false end
    for key, value in pairs(left) do
        if not sameData(value, right[key]) then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end

local function saveData(userId, value, previous)
    local encoded = game:GetService("HttpService"):JSONEncode(value)
    if #encoded > 3500000 then warn("[SAVE ERROR] Player data exceeds safe size", userId);return false end
    local success, result = pcall(function()
        local key = tostring(userId)
        if previous or value.WarehouseMigrationVersion == nil then
            return dataStore:UpdateAsync(key, function(current, info)
                if previous and not sameData(current, previous) then return nil end
                if current and (current.WarehouseMigrationVersion or 0) > (value.WarehouseMigrationVersion or 0) then
                    return nil
                end
                if info then return value, info:GetUserIds(), info:GetMetadata() end
                return value
            end)
        end
        dataStore:SetAsync(key, value)
        return true
    end)
    if not success then
        warn("[SAVE ERROR] Could not save gold for", userId, ":", result)
    end

    return success and result ~= nil
end

local function loadData(userId)
    local success, value = pcall(function()
        return dataStore:GetAsync(tostring(userId))
    end)

    if not success then
        warn("[LOAD ERROR] Could not load player data for", userId, ":", value)
        return nil
    end

    if value == nil then
        return {
            StarterHouseMigrationVersion = houseConfig.MigrationVersion,
            House = {Level = -1},
            Money = tutorialConfig.StartingMoneyCents,

            Inventory = {{
                ItemName = "CarrotSeed",
                Amount = 5
            }}
        }, true
    end

    return value
end

return {
    saveData = saveData,
    loadData = loadData
}
