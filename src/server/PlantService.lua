local PlantService = {}
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlantsFolder = ReplicatedStorage:WaitForChild("Plants")
local ServerScriptService = game:GetService("ServerScriptService")
local InventoryService = require(ServerScriptService:WaitForChild("InventoryService"))
local ItemDefinitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local Journal = require(ServerScriptService.FarmJournalService)
local plots = workspace:WaitForChild("Plots")

function PlantService.CanUse(player, gardenBed)
    if typeof(gardenBed) ~= "Instance" or not gardenBed:IsA("Model") or
        player:GetAttribute("DataLoaded") ~= true then return false end
    local definition = ItemDefinitions[gardenBed:GetAttribute("ItemName") or gardenBed.Name]
    local plot = plots:FindFirstChild(player:GetAttribute("PlotName") or "")
    if not definition or not definition.Plantable or not plot or gardenBed.Parent ~= plot:FindFirstChild("PlacedObjects") or
        plot:GetAttribute("OwnerUserId") ~= player.UserId or gardenBed:GetAttribute("OwnerUserId") ~= player.UserId then return false end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local prompt = gardenBed:FindFirstChild("ActionPrompt", true)
    local attachment = prompt and prompt.Parent
    return root and humanoid and humanoid.Health > 0 and attachment and attachment:IsA("Attachment") and
        (root.Position - attachment.WorldPosition).Magnitude <= prompt.MaxActivationDistance
end

local function getPositions(gardenBed)
    local spots = gardenBed:FindFirstChild("PlantingSpots")
    if not spots or not spots:IsA("Folder") then return end
    local positions = {}
    for _, spot in ipairs(spots:GetChildren()) do
        local position = spot:FindFirstChild("PlantPosition")
        if not position or not position:IsA("BasePart") then return end
        table.insert(positions, position)
    end
    table.sort(positions, function(a, b)
        local left, right = a.Parent.Name, b.Parent.Name
        local leftIndex, rightIndex = tonumber(left:match("%d+$")), tonumber(right:match("%d+$"))
        if leftIndex and rightIndex and leftIndex ~= rightIndex then return leftIndex < rightIndex end
        return left < right
    end)
    if #positions > 0 then return positions end
end

local RunService = game:GetService("RunService")
local config = require(ReplicatedStorage.Configs.CropConfig)
local tutorialConfig = require(ReplicatedStorage.Configs.FarmTutorialConfig)
local growing = {}
local random = Random.new()
local Laboratory = require(script.Parent.LaboratoryService)
local LaboratoryConfig = require(ReplicatedStorage.Configs.LaboratoryConfig)

local function choose(weights)
    local total = 0
    for _, weight in ipairs(weights) do total += weight end
    local roll = random:NextNumber() * total
    for index, weight in ipairs(weights) do
        roll -= weight
        if roll <= 0 then return index end
    end
    return #weights
end

local function growthRate(batch, baseRate)
    return baseRate * (batch.WaterCycles > 0 and config.WateringGrowthMultiplier or 1)
end

local function waterCycles(state)
    local remaining = 0
    for _, batch in ipairs(state.Batches) do remaining = math.max(remaining, batch.WaterCycles) end
    return remaining
end

local function cycleSettings(player, crop, firstHarvest)
    local settings = config.Crops[crop]
    local bonuses = Laboratory.GetBonuses(player)
    local weights = LaboratoryConfig.Weighted(settings.YieldWeights, bonuses.Yield)
    local duration = firstHarvest and tutorialConfig.FirstCropSeconds or
        settings.GrowthSeconds * (1 - bonuses.Growth / 100)
    return settings, weights, duration
end

local function startCycle(batch, settings, weights, duration)
    batch.Duration, batch.Remaining = duration, duration
    for _, slot in ipairs(batch.Slots) do
        slot.Yield = math.min(settings.YieldMax, settings.YieldMin + choose(weights) - 1)
    end
end

local function cloneSlots(source)
    local slots = {}
    for index, slot in ipairs(source) do slots[index] = table.clone(slot) end
    return slots
end

local function publish(object, state)
    local now = workspace:GetServerTimeNow()
    local clocks, count, ready, growingNow, nextHarvest = {}, 0, false, false, nil
    local cycles = waterCycles(state)
    for index, batch in ipairs(state.Batches) do
        local rate = growthRate(batch, state.BaseRate)
        local endsAt = now + batch.Remaining / rate
        local spots = {}
        for _, slot in ipairs(batch.Slots) do table.insert(spots, slot.Spot) end
        clocks[index] = {Spots = spots, EndsAt = endsAt, Rate = rate / batch.Duration}
        count += #spots
        ready = ready or batch.Remaining == 0
        growingNow = growingNow or batch.Remaining > 0
        nextHarvest = math.min(nextHarvest or endsAt, endsAt)
    end
    object:SetAttribute("PlantType", count > 0 and state.Type or "")
    object:SetAttribute("PlantedCount", count)
    object:SetAttribute("Occupied", count > 0)
    object:SetAttribute("ReadyToHarvest", ready)
    object:SetAttribute("WaterCycles", cycles)
    object:SetAttribute("CanWater", growingNow and cycles == 0)
    object:SetAttribute("GrowthEndsAt", nextHarvest)
    object:SetAttribute("CropGrowth", count > 0 and HttpService:JSONEncode(clocks) or nil)
end

function PlantService.Advance(object, dt, rate)
    local state = growing[object]
    if not state then return end
    rate = rate or 1
    local rateChanged = rate ~= state.BaseRate
    state.BaseRate = rate
    local ripened = false
    for _, batch in ipairs(state.Batches) do
        if batch.Remaining > 0 then
            batch.Remaining = math.max(0, batch.Remaining - dt * growthRate(batch, rate))
            if batch.Remaining == 0 then
                batch.WaterCycles = math.max(0, batch.WaterCycles - 1)
                ripened = true
            end
        end
    end
    if ripened or rateChanged then publish(object, state) end
    if ripened then
        local player = Players:GetPlayerByUserId(object:GetAttribute("OwnerUserId") or 0)
        if player then Journal.Record(player, "Ripen", 1, state.Type, object) end
    end
end

function PlantService.GetData(object)
    local state = growing[object]
    if not state then return nil end
    local batches = {}
    for index, batch in ipairs(state.Batches) do
        batches[index] = {Duration = batch.Duration, Remaining = batch.Remaining, WaterCycles = batch.WaterCycles,
            Slots = cloneSlots(batch.Slots)}
    end
    return {Version = 5, Type = state.Type, Batches = batches}
end

function PlantService.GetReturns(object)
    local state = growing[object]
    local rows = {}
    if not state then return rows end
    local grown, seeds = 0, 0
    for _, batch in ipairs(state.Batches) do
        seeds += #batch.Slots
        if batch.Remaining == 0 then
            for _, slot in ipairs(batch.Slots) do grown += slot.Yield end
        end
    end
    if grown > 0 then table.insert(rows, {ItemName = state.Type, Amount = grown}) end
    if seeds > 0 then
        for item, definition in pairs(ItemDefinitions) do
            if definition.Type == "Seed" and definition.PlantId == state.Type then
                table.insert(rows, {ItemName = item, Amount = seeds})
                return rows
            end
        end
        return nil, "Missing seed definition."
    end
    return rows
end

local function legacyBatch(saved, positions, settings, folder)
    local duration, remaining = 0, saved.Remaining
    local segment = saved.Segment or 1
    for index, seconds in ipairs(saved.Intervals or {settings.GrowthSeconds}) do
        duration += seconds
        if remaining and index > segment then remaining += seconds end
    end
    if saved.Version == nil then
        local stages = 0
        for _, model in ipairs(folder:GetChildren()) do
            if model:IsA("Model") and model.Name:match("^Stage%d+$") then stages += 1 end
        end
        remaining = duration * (1 - (math.clamp(saved.Stage or 1, 1, stages) - 1) / math.max(1, stages - 1))
    end
    local slots = {}
    for index, position in ipairs(positions) do
        local yield = 1
        if saved.Version == 2 then yield = #saved.Fruits[index]
        elseif saved.Version == 3 then yield = saved.Yields[index] end
        slots[index] = {Spot = position.Parent.Name, Yield = yield}
    end
    return {Duration = duration, Remaining = remaining or duration, Watered = saved.Watered == true or segment > 1,
        Slots = slots}
end

function PlantService.Restore(object, saved, legacyTemplate)
    local settings = config.Crops[saved.Type]
    local positions = getPositions(object)
    local folder = PlantsFolder:FindFirstChild(saved.Type)
    if not settings or not positions or not folder then return false, "Unknown crop" end
    object:SetAttribute("PlantingCapacity", #positions)
    local source = (saved.Version == 4 or saved.Version == 5) and saved.Batches or
        {legacyBatch(saved, getPositions(legacyTemplate or object), settings, folder)}
    local batches = {}
    for index, batch in ipairs(source) do
        local cycles = batch.WaterCycles
        if cycles == nil then cycles = batch.Watered and batch.Remaining > 0 and 1 or 0 end
        batches[index] = {Duration = batch.Duration, Remaining = batch.Remaining, WaterCycles = cycles,
            Slots = cloneSlots(batch.Slots)}
    end
    local state = {Type = saved.Type, BaseRate = 1, Batches = batches}
    growing[object] = state
    publish(object, state)
    return true
end

function PlantService.Plant(player, gardenBed)
    if not PlantService.CanUse(player, gardenBed) then return false end
    local slotIndex = player:GetAttribute("SelectedSlot") or 1
    local chosen = player.Inventory:FindFirstChild("Slot" .. slotIndex)
    if not chosen or chosen.Amount.Value < 1 then return false end
    local seedType = chosen.ItemName.Value
    local seed = ItemDefinitions[seedType]
    if not seed or seed.Type ~= "Seed" or not config.Crops[seed.PlantId] or
        not Journal.CanPlant(player, gardenBed, seedType) then return false end

    local state = growing[gardenBed]
    if state and state.Type ~= seed.PlantId then return false end
    local positions = getPositions(gardenBed)
    if not positions then return false end
    local occupied = {}
    for _, batch in ipairs(state and state.Batches or {}) do
        for _, slot in ipairs(batch.Slots) do occupied[slot.Spot] = true end
    end
    local free = {}
    for _, position in ipairs(positions) do
        local spot = position.Parent.Name
        if not occupied[spot] then table.insert(free, spot) end
    end
    local amount = math.min(chosen.Amount.Value, #free)
    if amount == 0 then return false end

    if not InventoryService.RemoveFromSlot(player, slotIndex, seedType, amount) then return false end
    if not state then
        state = {Type = seed.PlantId, BaseRate = 1, Batches = {}}
        growing[gardenBed] = state
    end
    local slots = {}
    for index = 1, amount do slots[index] = {Spot = free[index]} end
    local batch = {WaterCycles = waterCycles(state), Slots = slots}
    startCycle(batch, cycleSettings(player, state.Type, not Journal.TutorialComplete(player)))
    table.insert(state.Batches, batch)
    gardenBed:SetAttribute("PlantingCapacity", #positions)
    publish(gardenBed, state)
    Journal.Record(player, "Plant", amount, seedType, gardenBed)
    return true
end

function PlantService.Water(player, gardenBed)
    if not PlantService.CanUse(player, gardenBed) then return false end
    local chosen = player.Inventory:FindFirstChild("Slot" .. (player:GetAttribute("SelectedSlot") or 1))
    if not chosen or chosen.ItemName.Value ~= "WateringCan" or chosen.Amount.Value < 1 then return false end
    local state = growing[gardenBed]
    if not state or gardenBed:GetAttribute("CanWater") ~= true then return false end
    for _, batch in ipairs(state.Batches) do batch.WaterCycles = config.WateringCycles end
    publish(gardenBed, state)
    return true
end

function PlantService.Harvest(player, gardenBed)
    if not PlantService.CanUse(player, gardenBed) or not gardenBed:GetAttribute("ReadyToHarvest") or not Journal.CanHarvest(player, gardenBed) then return false end
    local state = growing[gardenBed]
    if not state then return false end
    local count, ripe = 0, {}
    for _, batch in ipairs(state.Batches) do
        if batch.Remaining == 0 then
            for _, slot in ipairs(batch.Slots) do count += slot.Yield end
            table.insert(ripe, batch)
        end
    end
    if count == 0 or not InventoryService.AddItem(player, state.Type, count) then return false end
    local settings, weights, duration = cycleSettings(player, state.Type, false)
    for _, batch in ipairs(ripe) do startCycle(batch, settings, weights, duration) end
    publish(gardenBed, state)
    Journal.Record(player, "Harvest", count, state.Type, gardenBed)
    return true
end

function PlantService.Clear(player, gardenBed)
    if not PlantService.CanUse(player, gardenBed) then return false, "Move closer to your garden bed." end
    local state = growing[gardenBed]
    if not state then return false, "This bed is already empty." end

    local count = 0
    for _, batch in ipairs(state.Batches) do count += #batch.Slots end
    local counter = config.SeedPurchaseAttribute(state.Type)
    local bought = player:GetAttribute(counter) or 0

    growing[gardenBed] = nil
    table.clear(state.Batches)
    publish(gardenBed, state)
    player:SetAttribute(counter, math.max(0, bought - count))
    return true, string.format("Cleared %d planting spots.", count)
end

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    if elapsed < 0.2 then return end
    local step = elapsed
    elapsed = 0
    local now = workspace:GetServerTimeNow()
    for object in pairs(growing) do
        if not object:IsDescendantOf(workspace) then growing[object] = nil
        else
            local owner = game.Players:GetPlayerByUserId(object:GetAttribute("OwnerUserId") or 0)
            if owner and owner:GetAttribute("DataLoaded") == true then
                local boosted = (owner:GetAttribute("GrowthBoostEndsAt") or 0) > now
                PlantService.Advance(object, step, boosted and tutorialConfig.GrowthBoostMultiplier or 1)
            end
        end
    end
end)

return PlantService
