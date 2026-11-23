local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local config = require(ReplicatedStorage.Configs.FarmJournalConfig)
local levels = require(ReplicatedStorage.Configs.FarmLevelConfig)
local definitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local tutorialConfig = require(ReplicatedStorage.Configs.FarmTutorialConfig)
local InventoryService = require(script.Parent.InventoryService)
local MoneyService = require(script.Parent.MoneyService)
local remote = ReplicatedStorage.RemoteEvents:WaitForChild("FarmJournal")
local Journal = {}
local legacyGoals = {
    Water = {Id = "Ripen"},
    WaterTwenty = {Id = "PlantTwenty"},
    BigFruit = {Id = "PlantTwenty", Goal = 140},
    RecordSide = {Id = "SellTwentyFive", Goal = 175},
}
local journals, objectives, chapters = {}, {}, {}

for _, chapter in ipairs(config.Chapters) do
    chapters[chapter.Id] = chapter
    for _, objective in ipairs(chapter.Objectives) do objectives[objective.Id] = objective end
end

local function integer(value, minimum)
    return typeof(value) == "number" and value >= minimum and value % 1 == 0 and value < math.huge
end

local function tutorialBed(player, tutorial)
    local plots = workspace:FindFirstChild("Plots")
    local plot = plots and plots:FindFirstChild(player:GetAttribute("PlotName") or "")
    local objects = plot and plot:GetAttribute("OwnerUserId") == player.UserId and plot:FindFirstChild("PlacedObjects")
    for _, object in ipairs(objects and objects:GetChildren() or {}) do
        if (object:GetAttribute("ItemName") or object.Name) == tutorial.BedItem then return object end
    end
end

local function tutorialView(player, data)
    local tutorial = table.clone(data.Tutorial)
    local bed = tutorialBed(player, tutorial)
    tutorial.Step = tutorialConfig.Step(tutorial, bed and {Ready = bed:GetAttribute("ReadyToHarvest")})
    tutorial.Capacity = tutorial.BedItem and definitions[tutorial.BedItem].PlantingCapacity or 1
    tutorial.Bed = bed
    return tutorial
end

local function loadTutorial(saved, data, playerData)
    if saved == nil then
        local fresh = data.FarmLevel == 1 and playerData.Money == tutorialConfig.StartingMoneyCents and
            #(playerData.PlacedObjects or {}) == 0 and #(playerData.UnlockedPlotSections or {}) == 0 and
            not playerData.CropRecord and (not playerData.House or playerData.House.Level == -1)
        for _, row in ipairs(playerData.Inventory or {}) do
            if row.ItemName ~= "" and (row.ItemName ~= "CarrotSeed" or row.Amount > 5) then fresh = false end
        end
        for _, count in pairs(data.Counts) do if count > 0 then fresh = false end end
        for _, claimed in pairs(data.Claimed) do if claimed then fresh = false end end
        return {Version = tutorialConfig.Version, Completed = not fresh, RewardClaimed = not fresh, Harvested = 0, Sold = 0}
    end
    if typeof(saved) ~= "table" or saved.Version ~= tutorialConfig.Version then return end
    local result = {Version = saved.Version}
    for _, key in ipairs({"Completed", "RewardClaimed", "CanBought", "Planted", "Watered", "FarmSeen", "JournalSeen"}) do
        if saved[key] ~= nil and typeof(saved[key]) ~= "boolean" then return end
        result[key] = saved[key] == true
    end
    for _, key in ipairs({"Harvested", "Sold"}) do
        local count = saved[key] == nil and 0 or saved[key]
        if not integer(count, 0) then return end
        result[key] = count
    end
    if result.Sold > result.Harvested then return end
    if saved.BedItem ~= nil then
        local bed = typeof(saved.BedItem) == "string" and definitions[saved.BedItem]
        if not bed or not bed.Plantable then return end
        result.BedItem = saved.BedItem
    end
    if saved.SeedItem ~= nil then
        local definition = typeof(saved.SeedItem) == "string" and definitions[saved.SeedItem]
        if not result.BedItem or not definition or definition.Type ~= "Seed" then return end
        result.SeedItem, result.CropItem = saved.SeedItem, definition.PlantId
    end
    if (result.CanBought or result.Planted) and not result.SeedItem or
        result.Harvested > 0 and not result.Planted then return end
    return result
end

local function copy(data)
    return {Version = 2, FarmLevel = data.FarmLevel, Counts = table.clone(data.Counts),
        Completed = table.clone(data.Completed), Claimed = table.clone(data.Claimed),
        LegacyAccess = table.clone(data.LegacyAccess), NotifiedLevel = data.NotifiedLevel, Tracked = data.Tracked,
        Tutorial = table.clone(data.Tutorial)}
end

local function raise(data, id, amount)
    local objective = objectives[id]
    if objective then data.Counts[id] = math.max(data.Counts[id] or 0, math.min(objective.Goal, amount)) end
end

local function updateFarm(data, counts, beds, buildings, animals, sections, house)
    for id, objective in pairs(objectives) do
        if objective.Kind == "Building" then raise(data, id, counts[objective.Item] or 0)
        elseif objective.Kind == "GardenBeds" then raise(data, id, beds)
        elseif objective.Kind == "Buildings" then raise(data, id, buildings)
        elseif objective.Kind == "Animals" then raise(data, id, animals)
        elseif objective.Kind == "Sections" then raise(data, id, sections)
        elseif objective.Kind == "House" and house then raise(data, id, 1) end
    end
end

local function currentChapter(data)
    return chapters[levels.Levels[data.FarmLevel].Chapter]
end

local function ready(data)
    return data.FarmLevel < levels.MaxLevel and data.Completed[currentChapter(data).Id] == true
end

local function reward(player, chapter, data)
    if data.Claimed[chapter.Id] then return false, "AlreadyClaimed" end
    local value = chapter.Reward
    if not MoneyService.CanAddMoney(player, value.MoneyCents) then return false, "BalanceLimit" end
    local added, reason = InventoryService.ExchangeItems(player, {}, value.Items)
    if not added then return false, reason end
    if not MoneyService.AddMoney(player, value.MoneyCents) then
        InventoryService.ExchangeItems(player, value.Items, {})
        return false, "BalanceLimit"
    end
    data.Claimed[chapter.Id] = true
    return true
end

local function snapshot(player, notify)
    local data = journals[player]
    if not data then return end
    local result = copy(data)
    result.Ready = ready(data)
    result.Tutorial = tutorialView(player, data)
    if notify and result.Ready and data.NotifiedLevel < data.FarmLevel then
        data.NotifiedLevel = data.FarmLevel
        result.NotifiedLevel = data.NotifiedLevel
        result.Notice = "LevelReady"
    end
    return result
end

local function send(player, message)
    if player.Parent == Players and player:GetAttribute("DataLoaded") == true then
        remote:FireClient(player, snapshot(player, true), message)
    end
end

function Journal.GetLevel(player)
    local data = journals[player]
    return data and data.FarmLevel or 1
end

function Journal.CanBuy(player, item)
    return journals[player] ~= nil and levels.HasAccess(Journal.GetLevel(player), item)
end

function Journal.CheckPurchase(player, item, amount)
    local data = journals[player]
    if not data then return false, "DataNotReady" end
    local tutorial = tutorialView(player, data)
    local required = tutorialConfig.PurchaseAmount(tutorial.Step, item, definitions[item], tutorial.Capacity, tutorial.CanBought)
    if required ~= nil and (required == 0 or amount ~= required) then return false, "TutorialPurchaseRequired" end
    return true
end

function Journal.CanDiscard(player, item)
    local data = journals[player]
    local tutorial = data and data.Tutorial
    return tutorial and (tutorial.Completed or item ~= tutorial.BedItem and item ~= tutorial.SeedItem and
        item ~= tutorial.CropItem and item ~= "WateringCan")
end

function Journal.CanSell(player, item, amount)
    local data = journals[player]
    if not data then return false end
    local tutorial = data.Tutorial
    return tutorial.Completed or
        tutorial.Harvested > tutorial.Sold and item == tutorial.CropItem and amount <= tutorial.Harvested - tutorial.Sold
end

function Journal.TutorialComplete(player)
    local data = journals[player]
    return data and data.Tutorial.Completed == true
end

function Journal.CanPlant(player, object, seed)
    local data = journals[player]
    if not data then return false end
    return data.Tutorial.Completed or not data.Tutorial.Planted and
        seed == data.Tutorial.SeedItem and object == tutorialBed(player, data.Tutorial)
end

function Journal.CanHarvest(player, object)
    local data = journals[player]
    if not data then return false end
    return data.Tutorial.Completed or tutorialView(player, data).Step == "Harvest" and object == tutorialBed(player, data.Tutorial)
end

function Journal.CanBuild(player, item)
    local data = journals[player]
    return data ~= nil and (levels.HasAccess(data.FarmLevel, item) or data.LegacyAccess[item] == true)
end

function Journal.Refresh(player)
    local data = journals[player]
    if not data then return end
    local plots = workspace:FindFirstChild("Plots")
    local plot = plots and plots:FindFirstChild(player:GetAttribute("PlotName") or "")
    if plot and plot:GetAttribute("OwnerUserId") == player.UserId then
        local counts, beds, buildings, animals = {}, 0, 0, 0
        local objects = plot:FindFirstChild("PlacedObjects")
        for _, object in ipairs(objects and objects:GetChildren() or {}) do
            local item = object:GetAttribute("ItemName") or object.Name
            local definition = definitions[item]
            counts[item] = (counts[item] or 0) + 1
            if definition and definition.Plantable then beds += 1
            elseif definition and definition.Placeable and not definition.BuildsInto then buildings += 1 end
            animals += object:GetAttribute("AnimalCount") or 0
            if object:GetAttribute("Occupied") then raise(data, "Plant", 1) end
            if object:GetAttribute("ReadyToHarvest") then raise(data, "Ripen", 1) end
        end
        local unlocked = 0
        for _, section in ipairs(plot.Sections:GetChildren()) do
            if section.Name ~= "Starter" and section:GetAttribute("Unlocked") then unlocked += 1 end
        end
        local house = plot:FindFirstChild("StarterHouse")
        updateFarm(data, counts, beds, buildings, animals, unlocked, house and (house:GetAttribute("HouseLevel") or -1) >= 0)
    end
    for _, chapter in ipairs(config.Chapters) do
        local complete = true
        for _, objective in ipairs(chapter.Objectives) do
            if (data.Counts[objective.Id] or 0) < objective.Goal then complete = false;break end
        end
        if complete or data.Claimed[chapter.Id] then data.Completed[chapter.Id] = true end
        if chapter.Category == "Main" and chapter.Level <= data.FarmLevel and data.Completed[chapter.Id] and
            not data.Claimed[chapter.Id] and player:GetAttribute("DataLoaded") == true then reward(player, chapter, data) end
    end
    if data.Tutorial.Completed and not data.Tutorial.RewardClaimed and player:GetAttribute("DataLoaded") == true then
        if MoneyService.AddMoney(player, tutorialConfig.CompletionRewardCents) then data.Tutorial.RewardClaimed = true end
    end
    local tutorial = tutorialView(player, data)
    player:SetAttribute("TutorialStep", tutorial.Step)
    player:SetAttribute("TutorialCapacity", tutorial.Capacity)
    player:SetAttribute("TutorialCanBought", tutorial.CanBought == true)
    player:SetAttribute("TutorialBedItem", tutorial.BedItem)
    player:SetAttribute("TutorialSeedItem", tutorial.SeedItem)
    player:SetAttribute("TutorialCropItem", tutorial.CropItem)
    player:SetAttribute("TutorialRemaining", tutorial.Harvested - tutorial.Sold)
    player:SetAttribute("FarmLevelReady", ready(data))
end

local function readFlags(saved)
    if saved == nil then return {} end
    if typeof(saved) ~= "table" then return end
    local result = {}
    for id, value in pairs(saved) do
        if typeof(id) ~= "string" or #id > 60 or typeof(value) ~= "boolean" then return end
        result[id] = value
    end
    return result
end

function Journal.Load(player, saved, playerData)
    if saved ~= nil and (typeof(saved) ~= "table" or typeof(saved.Counts) ~= "table" or typeof(saved.Claimed) ~= "table") then return false end
    if saved and saved.Version ~= nil and saved.Version ~= 2 then return false end
    playerData = playerData or {}
    local data = {Counts = {}, Claimed = readFlags(saved and saved.Claimed), Completed = readFlags(saved and saved.Completed),
        LegacyAccess = readFlags(saved and saved.LegacyAccess), FarmLevel = saved and saved.FarmLevel,
        NotifiedLevel = saved and saved.NotifiedLevel}
    if data.FarmLevel == nil then data.FarmLevel = 1 end
    if data.NotifiedLevel == nil then data.NotifiedLevel = 0 end
    if not data.Claimed or not data.Completed or not data.LegacyAccess or not integer(data.FarmLevel, 1) or
        data.FarmLevel > levels.MaxLevel or not integer(data.NotifiedLevel, 0) or data.NotifiedLevel > levels.MaxLevel then return false end
    for id, count in pairs(saved and saved.Counts or {}) do
        if typeof(id) ~= "string" or #id > 60 or not integer(count, 0) then return false end
        data.Counts[id] = count
    end
    if saved and saved.Tracked ~= nil then
        if typeof(saved.Tracked) ~= "string" then return false end
        local legacy = legacyGoals[saved.Tracked]
        local tracked = legacy and legacy.Id or saved.Tracked
        if objectives[tracked] then data.Tracked = tracked end
    end
    if not saved or saved.Version == nil then
        if saved then
            for index = 1, 3 do
                if data.Claimed[levels.Levels[index].Chapter] then data.FarmLevel = index + 1 else break end
            end
        end
        raise(data, "FirstBed", data.Counts.Beds or 0)
        local produced = 0
        local counts, beds, buildings, animals = {}, 0, 0, 0
        for _, row in ipairs(playerData.Inventory or {}) do levels.GrantLegacy(data.LegacyAccess, row.ItemName) end
        for _, object in ipairs(playerData.PlacedObjects or {}) do
            for _, row in ipairs(object.StorageInventory or {}) do levels.GrantLegacy(data.LegacyAccess, row.ItemName) end
            levels.GrantLegacy(data.LegacyAccess, object.ItemName)
            local item = object.ItemName
            local definition = definitions[item]
            counts[item] = (counts[item] or 0) + 1
            if definition and definition.Plantable then beds += 1
            elseif definition and definition.Placeable and not definition.BuildsInto then buildings += 1 end
            animals += #(object.Animals or {})
            local plant = object.Plant
            if plant then
                raise(data, "Plant", 1)
                if plant.Segment and plant.Segment > 1 then raise(data, "Water", 1) end
            end
            if definitions[object.ItemName] and definitions[object.ItemName].Recipes then
                for name, amount in pairs(object.OutputInventory or {}) do
                    if name ~= "Bucket" then produced += amount end
                end
            end
        end
        updateFarm(data, counts, beds, buildings, animals, #(playerData.UnlockedPlotSections or {}),
            playerData.House and (playerData.House.Level or -1) >= 0)
        for _, station in pairs(playerData.House and playerData.House.Stations or {}) do
            for name, amount in pairs(station.OutputInventory or {}) do if name ~= "Bucket" then produced += amount end end
        end
        for id, objective in pairs(objectives) do
            if objective.Kind == "Action" and objective.Event == "Produce" then raise(data, id, produced) end
        end
        local research = 0
        for _, value in pairs(playerData.Laboratory or {}) do
            if integer(value, 0) then research += value end
        end
        raise(data, "Research", research)
        local oldRecord = playerData.CropRecord
        if typeof(oldRecord) == "table" and integer(oldRecord.Size, 1) then raise(data, "Harvest", 1) end
    end
    local oldRecord = playerData.CropRecord
    local size = typeof(oldRecord) == "table" and integer(oldRecord.Size, 1) and oldRecord.Size or 0
    for oldId, legacy in pairs(legacyGoals) do
        local count = data.Counts[oldId] or 0
        if legacy.Goal then
            local progress = math.clamp(math.max(count, size) / legacy.Goal, 0, 1)
            count = math.floor(progress * objectives[legacy.Id].Goal)
        end
        raise(data, legacy.Id, count)
        data.Counts[oldId] = nil
    end
    for id, objective in pairs(objectives) do raise(data, id, data.Counts[objective.Event or id] or 0) end
    if saved and saved.Tutorial == nil then
        for _, row in ipairs(playerData.Inventory or {}) do
            if row.ItemName == "FieldBed10" then levels.GrantLegacy(data.LegacyAccess, row.ItemName) end
        end
        for _, object in ipairs(playerData.PlacedObjects or {}) do
            if object.ItemName == "FieldBed10" then levels.GrantLegacy(data.LegacyAccess, object.ItemName) end
            for _, row in ipairs(object.StorageInventory or {}) do
                if row.ItemName == "FieldBed10" then levels.GrantLegacy(data.LegacyAccess, row.ItemName) end
            end
        end
    end
    data.Tutorial = loadTutorial(saved and saved.Tutorial, data, playerData)
    if not data.Tutorial then return false end
    local remaining = saved and saved.GrowthBoostRemaining
    if remaining == nil and data.Tutorial.Planted and not data.Tutorial.Completed then
        remaining = tutorialConfig.GrowthBoostSeconds
    end
    if remaining ~= nil and not integer(remaining, 0) then return false end
    local boostEnd = nil
    if remaining and remaining > 0 then
        boostEnd = workspace:GetServerTimeNow() + math.min(remaining, tutorialConfig.GrowthBoostSeconds)
    end
    player:SetAttribute("GrowthBoostEndsAt", boostEnd)
    journals[player] = data
    player:SetAttribute("FarmLevel", data.FarmLevel)
    Journal.Refresh(player)
    return true
end

function Journal.GetData(player)
    local data = journals[player]
    if not data then return end
    local result = copy(data)
    local deadline = player:GetAttribute("GrowthBoostEndsAt") or 0
    if data.Tutorial.Planted or data.Tutorial.Completed then
        result.GrowthBoostRemaining = math.max(0, math.floor(deadline - workspace:GetServerTimeNow()))
    end
    return result
end

function Journal.Update(player)
    Journal.Refresh(player)
    send(player)
end

function Journal.Record(player, event, amount, item, object)
    local data = journals[player]
    if not data or player:GetAttribute("DataLoaded") ~= true then return end
    local changed = false
    local tutorial = data.Tutorial
    if not tutorial.Completed then
        local view = tutorialView(player, data)
        if event == "Buy" then
            if view.Step == "BuyBed" then tutorial.BedItem = item;changed = true
            elseif view.Step == "BuySeeds" then tutorial.SeedItem = item;tutorial.CropItem = definitions[item].PlantId;changed = true
            elseif item == "WateringCan" then tutorial.CanBought = true;changed = true end
        elseif object == view.Bed and object ~= nil then
            if event == "Plant" then
                tutorial.Planted = true
                player:SetAttribute("GrowthBoostEndsAt", workspace:GetServerTimeNow() + tutorialConfig.GrowthBoostSeconds)
                changed = true
            elseif event == "Ripen" then changed = true
            elseif event == "Harvest" then tutorial.Harvested = amount;changed = true end
        elseif event == "Sell" and item == tutorial.CropItem and tutorial.Harvested > tutorial.Sold then
            tutorial.Sold += amount
            tutorial.Completed = tutorial.Sold >= tutorial.Harvested
            changed = true
        end
    end
    for id, objective in pairs(objectives) do
        if objective.Kind == "Action" and (objective.Event or id) == event then
            local previous = data.Counts[id] or 0
            raise(data, id, previous + (amount or 1))
            if data.Counts[id] ~= previous then changed = true end
        end
    end
    if changed or event == "Harvest" then Journal.Update(player) end
end

function Journal.GetState(player)
    if player:GetAttribute("DataLoaded") ~= true then return end
    Journal.Refresh(player)
    return snapshot(player, true)
end

function Journal.TutorialViewed(player, menu)
    local data = journals[player]
    if not data or player:GetAttribute("DataLoaded") ~= true then return false end
    local tutorial = data.Tutorial
    if tutorial.Completed or not tutorial.Planted then return false end
    if menu == "Farm" and not tutorial.FarmSeen then tutorial.FarmSeen = true
    elseif menu == "Journal" and tutorial.FarmSeen and not tutorial.JournalSeen then tutorial.JournalSeen = true
    else return false end
    Journal.Update(player)
    return true
end

function Journal.Track(player, id)
    local data = journals[player]
    if not data or player:GetAttribute("DataLoaded") ~= true or
        (id ~= nil and (typeof(id) ~= "string" or not objectives[id])) then return false end
    data.Tracked = id
    send(player)
    return true
end

function Journal.Claim(player, chapterId)
    local data = journals[player]
    if not data or player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("Teleporting") then return false, "DataNotReady" end
    local chapter = chapters[chapterId]
    if not chapter or chapter.Category == "Main" and chapter.Level > data.FarmLevel then return false, "ChapterLocked" end
    local claimed = data.Claimed[chapterId]
    Journal.Refresh(player)
    if not claimed and data.Claimed[chapterId] then send(player, "RewardClaimed");return true end
    if not data.Completed[chapterId] then return false, "NotComplete" end
    local success, reason = reward(player, chapter, data)
    send(player, success and "RewardClaimed" or reason)
    return success, reason
end

function Journal.LevelUp(player, expected)
    local data = journals[player]
    if not data or player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("Teleporting") then return false, "DataNotReady" end
    if tostring(data.FarmLevel) ~= expected or data.FarmLevel >= levels.MaxLevel then return false, "LevelChanged" end
    Journal.Refresh(player)
    if not ready(data) then return false, "NotComplete" end
    local previous = data.FarmLevel
    data.FarmLevel += 1
    player:SetAttribute("FarmLevel", data.FarmLevel)
    Journal.Refresh(player)
    send(player, {Kind = "LevelUp", Previous = previous, Level = data.FarmLevel})
    return true
end

function Journal.Clear(player)
    journals[player] = nil
end

return Journal
