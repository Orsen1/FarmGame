local ReplicatedStorage = game:GetService("ReplicatedStorage")
local config = require(ReplicatedStorage.Configs.FarmJournalConfig)
local definitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local crops = require(ReplicatedStorage.Configs.CropConfig).Crops
local InventoryService = require(script.Parent.InventoryService)
local MoneyService = require(script.Parent.MoneyService)
local remote = ReplicatedStorage.RemoteEvents:WaitForChild("FarmJournal")
local Journal = {}
local journals = {}
local objectives = {}

for _, chapter in ipairs(config.Chapters) do
    for _, objective in ipairs(chapter.Objectives) do objectives[objective.Id] = objective end
end

local function copy(data)
    return {Counts = table.clone(data.Counts), Claimed = table.clone(data.Claimed), Tracked = data.Tracked}
end

local function send(player, message)
    local data = journals[player]
    if data and player.Parent == game.Players then remote:FireClient(player, copy(data), message) end
end

local function raise(data, id, amount)
    local goal = objectives[id].Goal
    data.Counts[id] = math.min(goal, math.max(data.Counts[id] or 0, amount))
end

function Journal.Refresh(player)
    local data = journals[player]
    if not data then return end
    local plots = workspace:FindFirstChild("Plots")
    local plot = plots and plots:FindFirstChild(player:GetAttribute("PlotName") or "")
    if not plot or plot:GetAttribute("OwnerUserId") ~= player.UserId then return end
    local objects = plot:FindFirstChild("PlacedObjects")
    local counts = {}
    for _, object in ipairs(objects and objects:GetChildren() or {}) do
        local item = object:GetAttribute("ItemName") or object.Name
        counts[item] = (counts[item] or 0) + 1
        if object:GetAttribute("Occupied") then raise(data, "Plant", 1) end
        if object:GetAttribute("WateredAt") then raise(data, "Water", 1) end
    end
    local beds = 0
    for item, count in pairs(counts) do
        if definitions[item] and definitions[item].Plantable then beds += count end
    end
    raise(data, "Beds", beds)
    for id, objective in pairs(objectives) do
        if objective.Kind == "Building" then raise(data, id, counts[objective.Item] or 0) end
    end
    local sections = plot:FindFirstChild("Sections")
    local unlocked = 0
    for _, section in ipairs(sections and sections:GetChildren() or {}) do
        if section.Name ~= "Starter" and section:GetAttribute("Unlocked") then unlocked += 1 end
    end
    raise(data, "Expand", unlocked)
end

function Journal.Load(player, saved, playerData)
    if saved ~= nil and (typeof(saved) ~= "table" or typeof(saved.Counts) ~= "table" or typeof(saved.Claimed) ~= "table") then return false end
    local data = {Counts = {}, Claimed = {}}
    for id, objective in pairs(objectives) do
        local count = saved and saved.Counts[id] or 0
        if typeof(count) ~= "number" or count < 0 or count % 1 ~= 0 or count == math.huge then return false end
        data.Counts[id] = math.min(count, objective.Goal)
    end
    for _, chapter in ipairs(config.Chapters) do
        local claimed = saved and saved.Claimed[chapter.Id]
        if claimed ~= nil and typeof(claimed) ~= "boolean" then return false end
        data.Claimed[chapter.Id] = claimed == true
    end
    if saved and saved.Tracked ~= nil then
        if not objectives[saved.Tracked] then return false end
        data.Tracked = saved.Tracked
    end
    if not saved then
        local harvested = 0
        for _, slot in ipairs(playerData.Inventory or {}) do
            local item = definitions[slot.ItemName]
            if item and crops[slot.ItemName] then harvested += slot.Amount end
            if slot.ItemName == "Wood" or slot.ItemName == "BirchWood" then raise(data, "GatherWood", (data.Counts.GatherWood or 0) + slot.Amount) end
            if slot.ItemName == "Stone" then raise(data, "GatherStone", slot.Amount) end
        end
        if harvested > 0 or playerData.CropRecord then
            raise(data, "Plant", 1)
            raise(data, "Water", 1)
            raise(data, "Harvest", math.max(1, harvested))
        end
    end
    journals[player] = data
    Journal.Refresh(player)
    return true
end

function Journal.GetData(player)
    local data = journals[player]
    return data and copy(data)
end

function Journal.Update(player)
    Journal.Refresh(player)
    send(player)
end

function Journal.Record(player, id, amount)
    local data = journals[player]
    if not data or player:GetAttribute("DataLoaded") ~= true or not objectives[id] then return end
    local previous = data.Counts[id] or 0
    raise(data, id, previous + (amount or 1))
    if data.Counts[id] ~= previous then send(player) end
end

function Journal.GetState(player)
    if player:GetAttribute("DataLoaded") ~= true then return end
    Journal.Refresh(player)
    return Journal.GetData(player)
end

function Journal.Track(player, id)
    local data = journals[player]
    if not data or player:GetAttribute("DataLoaded") ~= true or (id ~= nil and (typeof(id) ~= "string" or not objectives[id])) then return false end
    data.Tracked = id
    send(player)
    return true
end

function Journal.Claim(player, chapterId)
    local data = journals[player]
    if not data or player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("Teleporting") then return false, "DataNotReady" end
    local chapter
    for _, entry in ipairs(config.Chapters) do
        if not data.Claimed[entry.Id] then chapter = entry;break end
    end
    if not chapter or chapter.Id ~= chapterId then return false, "ChapterLocked" end
    Journal.Refresh(player)
    for _, objective in ipairs(chapter.Objectives) do
        if (data.Counts[objective.Id] or 0) < objective.Goal then return false, "NotComplete" end
    end
    local reward = chapter.Reward
    if not MoneyService.CanAddMoney(player, reward.MoneyCents) then return false, "BalanceLimit" end
    local added, reason = InventoryService.ExchangeItems(player, {}, reward.Items)
    if not added then return false, reason end
    MoneyService.AddMoney(player, reward.MoneyCents)
    data.Claimed[chapter.Id] = true
    if data.Tracked then
        for _, objective in ipairs(chapter.Objectives) do
            if objective.Id == data.Tracked then data.Tracked = nil end
        end
    end
    send(player, "RewardClaimed")
    return true
end

function Journal.Clear(player)
    journals[player] = nil
end

return Journal
