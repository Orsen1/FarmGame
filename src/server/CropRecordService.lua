local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local config = require(game.ReplicatedStorage.Configs.CropConfig)
local ids = {"Carrot", "Potato", "Wheat", "Strawberry", "Blueberry", "Corn", "Pumpkin", "BellPepper"}
local stores = {All = DataStoreService:GetOrderedDataStore("FarmGame_CropRecords_v1")}
local records, pending, names = {}, {}, {}
local caches = {}
local Records = {}

local function validRecord(saved)
    return typeof(saved) == "table" and typeof(saved.Size) == "number" and saved.Size % 1 == 0 and
        saved.Size >= 1 and saved.Size <= 10000 and not (
        saved.SubmittedSize ~= nil and (typeof(saved.SubmittedSize) ~= "number" or saved.SubmittedSize < 0 or
        saved.SubmittedSize % 1 ~= 0 or saved.SubmittedSize > saved.Size))
end

local function queue(player, crop, record)
    if record.Size <= (record.SubmittedSize or 0) then return end
    pending[player.UserId] = pending[player.UserId] or {}
    pending[player.UserId][crop] = record
end

local function getStore(crop)
    if not stores[crop] then stores[crop] = DataStoreService:GetOrderedDataStore("FarmGame_CropRecords_v1", crop) end
    return stores[crop]
end

function Records.Load(player, saved)
    if saved ~= nil and (not validRecord(saved) or not config.Crops[saved.Crop]) then return false end
    local record = saved and table.clone(saved) or {Size = 0, SubmittedSize = 0}
    record.ByCrop = {}
    if saved and saved.ByCrop ~= nil then
        if typeof(saved.ByCrop) ~= "table" then return false end
        for crop, best in pairs(saved.ByCrop) do
            if not config.Crops[crop] or not validRecord(best) then return false end
            record.ByCrop[crop] = table.clone(best)
        end
    end
    if saved and not record.ByCrop[saved.Crop] then record.ByCrop[saved.Crop] = {Size = saved.Size} end
    records[player] = record
    queue(player, "All", record)
    for crop, best in pairs(record.ByCrop) do queue(player, crop, best) end
    return true
end

function Records.GetData(player)
    local record = records[player]
    if not record or record.Size == 0 then return nil end
    local saved = table.clone(record)
    saved.ByCrop = {}
    for crop, best in pairs(record.ByCrop) do saved.ByCrop[crop] = table.clone(best) end
    return saved
end

function Records.Observe(player, crop, sizes)
    local record = records[player]
    if not record or not config.Crops[crop] then return end
    local best = record.ByCrop[crop] or {Size = 0, SubmittedSize = 0}
    local maximum = best.Size
    for _, size in ipairs(sizes) do maximum = math.max(maximum, size) end
    if maximum > best.Size then
        best.Size = maximum
        record.ByCrop[crop] = best
        queue(player, crop, best)
    end
    if maximum > record.Size then
        record.Crop, record.Size = crop, maximum
        queue(player, "All", record)
    end
end

function Records.Flush()
    for userId, work in pairs(pending) do
        for crop, record in pairs(work) do
            local size = record.Size
            local score = crop == "All" and size * 16 + table.find(ids, record.Crop) or size
            local ok, err = pcall(function()
                getStore(crop):UpdateAsync(tostring(userId), function(previous)
                    return math.max(previous or 0, score)
                end)
            end)
            if ok then
                record.SubmittedSize = math.max(record.SubmittedSize or 0, size)
                if work[crop] == record and record.Size == size then work[crop] = nil end
            else warn("[CROP RECORD SAVE]", crop, err) end
        end
        if not next(work) and pending[userId] == work then pending[userId] = nil end
    end
end

local function refreshGlobal(crop, cache)
    cache.Refreshing = true
    local ok, result = pcall(function()
        return getStore(crop):GetSortedAsync(false, config.LeaderboardLimit):GetCurrentPage()
    end)
    if not ok then cache.Unavailable = true;cache.Refreshing = false;warn("[CROP LEADERBOARD]", crop, result);return end
    local rows = {}
    for _, entry in ipairs(result) do
        local userId = tonumber(entry.key)
        local item = crop == "All" and ids[entry.value % 16] or crop
        if userId and item then
            if not names[userId] then
                local found, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
                names[userId] = found and name or tostring(userId)
            end
            table.insert(rows, {UserId = userId, Name = names[userId], Crop = item,
                Size = crop == "All" and math.floor(entry.value / 16) or entry.value})
        end
    end
    cache.Rows, cache.UpdatedAt, cache.Unavailable, cache.Refreshing = rows, os.time(), false, false
end

function Records.GetBoards(crop)
    crop = crop or "All"
    if crop ~= "All" and not config.Crops[crop] then return nil end
    local cache = caches[crop]
    if not cache then
        cache = {Rows = {}, UpdatedAt = 0, Unavailable = false, Refreshing = true}
        caches[crop] = cache
        task.spawn(refreshGlobal, crop, cache)
    end
    cache.RequestedAt = os.clock()
    local rows = {}
    for player, record in pairs(records) do
        local best = crop == "All" and record or record.ByCrop[crop]
        if player.Parent == Players and player:GetAttribute("DataLoaded") == true and best and best.Size > 0 then
            table.insert(rows, {UserId = player.UserId, Name = player.Name,
                Crop = crop == "All" and record.Crop or crop, Size = best.Size})
        end
    end
    table.sort(rows, function(a, b) return a.Size > b.Size or a.Size == b.Size and a.UserId < b.UserId end)
    return {Crop = crop, Server = rows, Global = cache.Rows, UpdatedAt = cache.UpdatedAt,
        Unavailable = cache.Unavailable, Loading = cache.UpdatedAt == 0 and cache.Refreshing}
end

function Records.Clear(player) records[player] = nil end
task.spawn(function()
    while true do
        Records.Flush()
        for crop, cache in pairs(caches) do
            if not cache.Refreshing and os.clock() - cache.RequestedAt <= config.LeaderboardRefreshSeconds * 2 and
                os.time() - cache.UpdatedAt >= config.LeaderboardRefreshSeconds then
                refreshGlobal(crop, cache)
            end
        end
        task.wait(config.RecordFlushSeconds)
    end
end)
game:BindToClose(Records.Flush)
return Records
