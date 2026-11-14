local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local config = require(game.ReplicatedStorage.Configs.CropConfig)
local ids = {"Carrot", "Potato", "Wheat", "Strawberry", "Blueberry", "Corn", "Pumpkin", "BellPepper"}
local store = DataStoreService:GetOrderedDataStore("FarmGame_CropRecords_v1")
local records, pending, names = {}, {}, {}
local global, updated, unavailable = {}, 0, true
local Records = {}

function Records.Load(player, saved)
    if saved ~= nil and (typeof(saved) ~= "table" or not config.Crops[saved.Crop] or
        typeof(saved.Size) ~= "number" or saved.Size % 1 ~= 0 or saved.Size < 1 or saved.Size > 10000 or
        saved.SubmittedSize ~= nil and (typeof(saved.SubmittedSize) ~= "number" or saved.SubmittedSize < 0 or
        saved.SubmittedSize % 1 ~= 0 or saved.SubmittedSize > saved.Size)) then return false end
    records[player] = saved and table.clone(saved) or {Size = 0, SubmittedSize = 0}
    local record = records[player]
    if record.Size > (record.SubmittedSize or 0) then pending[player.UserId] = record end
    return true
end

function Records.GetData(player)
    local record = records[player]
    return record and record.Size > 0 and table.clone(record) or nil
end

function Records.Observe(player, crop, sizes)
    local record = records[player]
    if not record or not config.Crops[crop] then return end
    local maximum = record.Size
    for _, size in ipairs(sizes) do maximum = math.max(maximum, size) end
    if maximum <= record.Size then return end
    record.Crop, record.Size = crop, maximum
    pending[player.UserId] = record
end

function Records.Flush()
    for userId, record in pairs(pending) do
        local size, crop = record.Size, record.Crop
        local score = size * 16 + table.find(ids, crop)
        local ok, err = pcall(function()
            store:UpdateAsync(tostring(userId), function(previous)
                if previous and math.floor(previous / 16) >= size then return previous end
                return score
            end)
        end)
        if ok then
            record.SubmittedSize = math.max(record.SubmittedSize or 0, size)
            if record.Size == size then pending[userId] = nil end
        else warn("[CROP RECORD SAVE]", err) end
    end
end

local function refreshGlobal()
    local ok, result = pcall(function()
        return store:GetSortedAsync(false, config.LeaderboardLimit):GetCurrentPage()
    end)
    if not ok then unavailable = true;warn("[CROP LEADERBOARD]", result);return end
    local rows = {}
    for _, entry in ipairs(result) do
        local userId = tonumber(entry.key)
        local crop = ids[entry.value % 16]
        if userId and crop then
            if not names[userId] then
                local found, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
                names[userId] = found and name or tostring(userId)
            end
            table.insert(rows, {UserId = userId, Name = names[userId], Crop = crop, Size = math.floor(entry.value / 16)})
        end
    end
    global, updated, unavailable = rows, os.time(), false
end

function Records.GetBoards()
    local rows = {}
    for player, record in pairs(records) do
        if player.Parent == Players and player:GetAttribute("DataLoaded") == true and record.Size > 0 then
            table.insert(rows, {UserId = player.UserId, Name = player.Name, Crop = record.Crop, Size = record.Size})
        end
    end
    table.sort(rows, function(a, b) return a.Size > b.Size or a.Size == b.Size and a.UserId < b.UserId end)
    return {Server = rows, Global = global, UpdatedAt = updated, Unavailable = unavailable}
end

function Records.Clear(player) records[player] = nil end
task.spawn(function()
    local elapsed = config.LeaderboardRefreshSeconds
    while true do
        Records.Flush()
        if elapsed >= config.LeaderboardRefreshSeconds then refreshGlobal();elapsed = 0 end
        task.wait(config.RecordFlushSeconds)
        elapsed += config.RecordFlushSeconds
    end
end)
game:BindToClose(Records.Flush)
return Records
