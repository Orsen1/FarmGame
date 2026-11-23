local PlantService = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlantsFolder = ReplicatedStorage:WaitForChild("Plants")
local ServerScriptService = game:GetService("ServerScriptService")
local InventoryService = require(ServerScriptService:WaitForChild("InventoryService"))
local ItemDefinitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local Journal = require(ServerScriptService.FarmJournalService)
local plots = workspace:WaitForChild("Plots")

local function canUse(player, gardenBed)
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

local function growthRate(state)
    return state.BaseRate * (state.Watered and config.WateringGrowthMultiplier or 1)
end

local function publish(object, state, resetClock)
    if resetClock then
        local rate = growthRate(state)
        object:SetAttribute("GrowthPerSecond", rate / state.Duration)
        object:SetAttribute("GrowthEndsAt", workspace:GetServerTimeNow() + state.Remaining / rate)
    end
    local progress = 1 - state.Remaining / state.Duration
    local stage = 1 + math.floor(progress * (state.Stages - 1))
    object:SetAttribute("GrowthStage", stage)
    object:SetAttribute("Watered", state.Watered)
    object:SetAttribute("ReadyToHarvest", state.Remaining == 0)
end

function PlantService.Advance(object, dt, rate)
    local state = growing[object]
    if not state or state.Remaining == 0 then return end
    rate = rate or 1
    local rateChanged = rate ~= state.BaseRate
    state.BaseRate = rate
    state.Remaining = math.max(0, state.Remaining - dt * growthRate(state))
    publish(object, state, state.Remaining == 0 or rateChanged)
    if state.Remaining == 0 then
        local player = game.Players:GetPlayerByUserId(object:GetAttribute("OwnerUserId") or 0)
        if player then Journal.Record(player, "Ripen", 1, state.Type, object) end
    end
end

function PlantService.GetData(object)
    local state = growing[object]
    if not state then return nil end
    return {Version = 3, Type = state.Type, Segment = 1, Remaining = state.Remaining,
        NeedsWater = false, Ready = state.Remaining == 0, Intervals = {state.Duration}, Watered = state.Watered,
        Yields = table.clone(state.Yields), Stage = object:GetAttribute("GrowthStage")}
end

function PlantService.Restore(object, saved)
    local settings = config.Crops[saved.Type]
    local positions = getPositions(object)
    local folder = PlantsFolder:FindFirstChild(saved.Type)
    if not settings or not positions or not folder then return false, "Unknown crop" end
    local stages = 0
    for _, model in ipairs(folder:GetChildren()) do if model:IsA("Model") and model.Name:match("^Stage%d+$") then stages += 1 end end
    local duration = 0
    local segment = saved.Segment or 1
    local remaining = saved.Remaining
    for index, seconds in ipairs(saved.Intervals or {settings.GrowthSeconds}) do
        duration += seconds
        if remaining and index > segment then remaining += seconds end
    end
    local state = {Type = saved.Type, Stages = stages, Duration = duration, BaseRate = 1,
        Remaining = remaining or duration, Watered = saved.Watered == true or segment > 1, Yields = saved.Yields}
    if saved.Version == 2 then
        state.Yields = {}
        for index, fruits in ipairs(saved.Fruits) do state.Yields[index] = #fruits end
    end
    if saved.Version == nil then
        state.Yields = table.create(#positions, 1)
        local stage = math.clamp(saved.Stage or 0, 1, stages)
        state.Remaining = stage == stages and 0 or duration * (1 - (stage - 1) / math.max(1, stages - 1))
    end
    growing[object] = state
    object:SetAttribute("Occupied", true)
    object:SetAttribute("PlantType", state.Type)
    publish(object, state, true)
    return true
end

function PlantService.Plant(player, gardenBed, seedType)
    if not canUse(player, gardenBed) or gardenBed:GetAttribute("Occupied") or not Journal.CanPlant(player, gardenBed, seedType) then return false end
    local seed = typeof(seedType) == "string" and ItemDefinitions[seedType]
    local settings = seed and config.Crops[seed.PlantId]
    local positions = getPositions(gardenBed)
    if not settings or not positions or not PlantsFolder:FindFirstChild(seed.PlantId) then return false end
    local bonuses = Laboratory.GetBonuses(player)
    local yieldWeights = LaboratoryConfig.Weighted(settings.YieldWeights, bonuses.Yield)
    local duration = Journal.TutorialComplete(player) and settings.GrowthSeconds * (1 - bonuses.Growth / 100) or
        tutorialConfig.FirstCropSeconds
    local yields = {}
    for index in ipairs(positions) do
        yields[index] = math.min(settings.YieldMax, settings.YieldMin + choose(yieldWeights) - 1)
    end
    if not InventoryService.RemoveItem(player, seedType, #positions) then return false end
    local planted = PlantService.Restore(gardenBed, {Version = 3, Type = seed.PlantId, Yields = yields, Intervals = {duration}})
    if planted then Journal.Record(player, "Plant", 1, seedType, gardenBed) end
    return planted
end

function PlantService.Water(player, gardenBed)
    if not canUse(player, gardenBed) then return false end
    local slot = player.Inventory:FindFirstChild("Slot" .. (player:GetAttribute("SelectedSlot") or 1))
    if not slot or slot.ItemName.Value ~= "WateringCan" or slot.Amount.Value < 1 then return false end
    return PlantService.ApplyWater(gardenBed)
end

function PlantService.ApplyWater(gardenBed)
    local state = growing[gardenBed]
    if not state or state.Watered or state.Remaining == 0 then return false end
    state.Watered = true
    publish(gardenBed, state, true)
    return true
end

function PlantService.Harvest(player, gardenBed)
    if not canUse(player, gardenBed) or not gardenBed:GetAttribute("ReadyToHarvest") or not Journal.CanHarvest(player, gardenBed) then return false end
    local state = growing[gardenBed]
    if not state then return false end
    local count = 0
    for _, amount in ipairs(state.Yields) do count += amount end
    if not InventoryService.AddItem(player, state.Type, count) then return false end
    Journal.Record(player, "Harvest", count, state.Type, gardenBed)
    growing[gardenBed] = nil
    for _, name in ipairs({"Watered", "GrowthPerSecond", "GrowthEndsAt"}) do gardenBed:SetAttribute(name, nil) end
    gardenBed:SetAttribute("Occupied", false)
    gardenBed:SetAttribute("PlantType", "")
    gardenBed:SetAttribute("GrowthStage", 0)
    gardenBed:SetAttribute("ReadyToHarvest", false)
    return true
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
