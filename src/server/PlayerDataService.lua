local DataStoreService = game:GetService("DataStoreService")
local dataStore = DataStoreService:GetDataStore("FarmGame_MoneyInventory")

local function saveData(userId, value)
    local success, err = pcall(function()
        dataStore:SetAsync(tostring(userId), value)
    end)
    if not success then
        warn("[SAVE ERROR] Could not save gold for", userId, ":", err)
    end

    return success
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
            Money = 250,

            Inventory = {{
                ItemName = "CarrotSeed",
                Amount = 5
            }}
        }
    end

    return value
end

return {
    saveData = saveData,
    loadData = loadData
}

