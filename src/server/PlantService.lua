local PlantService = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlantsFolder = ReplicatedStorage:WaitForChild("Plants")
local ServerScriptService = game:GetService("ServerScriptService")
local InventoryService = require(ServerScriptService:WaitForChild("InventoryService"))
local ItemDefinitions = require(ReplicatedStorage.Configs.ItemDefinitions)
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
local HttpService = game:GetService("HttpService")
local CropItems = require(ReplicatedStorage.CropItems)
local config = require(ReplicatedStorage.Configs.CropConfig)
local Records = require(script.Parent.CropRecordService)
local growing = {}
local random = Random.new()

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

local function growthIntervals(settings)
    if #settings.GrowthIntervals == settings.Waterings + 1 then return table.clone(settings.GrowthIntervals) end
    local total = 0
    for _, seconds in ipairs(settings.GrowthIntervals) do total += seconds end
    local intervals = {}
    for index = 1, settings.Waterings + 1 do intervals[index] = total / (settings.Waterings + 1) end
    return intervals
end

local function rollSize(settings)
    local band = choose(settings.SizeWeights)
    local ranges = {{settings.SizeMin, 115}, {116, math.floor(115 + (settings.SizeMax - 115) * 0.45)},
        {math.floor(115 + (settings.SizeMax - 115) * 0.45) + 1, math.floor(settings.SizeMax * 0.88)},
        {math.floor(settings.SizeMax * 0.88) + 1, settings.SizeMax}}
    return random:NextInteger(ranges[band][1], ranges[band][2])
end

local function publish(object, state)
    local elapsed, total = 0, 0
    for index, seconds in ipairs(state.Intervals) do
        total += seconds
        if index < state.Segment then elapsed += seconds end
    end
    elapsed += state.Intervals[state.Segment] - state.Remaining
    local stage = math.min(state.Stages, 1 + math.floor(elapsed / total * (state.Stages - 1)))
    if state.Ready then stage = state.Stages end
    object:SetAttribute("GrowthStage", stage)
    object:SetAttribute("NeedsWater", state.NeedsWater)
    object:SetAttribute("ReadyToHarvest", state.Ready)
end

function PlantService.Advance(object, dt)
    local state = growing[object]
    if not state or state.Ready or state.NeedsWater then return end
    state.Remaining = math.max(0, state.Remaining - dt)
    if state.Remaining == 0 then
        if state.Segment < #state.Intervals then state.NeedsWater = true
        else state.Ready = true end
    end
    publish(object, state)
end

function PlantService.GetData(object)
    local state = growing[object]
    if not state then return nil end
    return {Version = 2, Type = state.Type, Segment = state.Segment, Remaining = state.Remaining,
        NeedsWater = state.NeedsWater, Ready = state.Ready, Intervals = table.clone(state.Intervals),
        Fruits = state.Fruits, Stage = object:GetAttribute("GrowthStage")}
end

function PlantService.Restore(object, saved)
    local settings = config.Crops[saved.Type]
    local positions = getPositions(object)
    local folder = PlantsFolder:FindFirstChild(saved.Type)
    if not settings or not positions or not folder then return false, "Unknown crop" end
    table.sort(positions, function(a, b) return a.Parent.Name < b.Parent.Name end)
    local stages = 0
    for _, model in ipairs(folder:GetChildren()) do if model:IsA("Model") and model.Name:match("^Stage%d+$") then stages += 1 end end
    local state = {Type = saved.Type, Stages = stages, Segment = saved.Segment or 1,
        Remaining = saved.Remaining, NeedsWater = saved.NeedsWater == true, Ready = saved.Ready == true,
        Intervals = saved.Intervals or growthIntervals(settings), Fruits = saved.Fruits}
    if saved.Version == nil then
        state.Fruits = {}
        for index in ipairs(positions) do state.Fruits[index] = {100} end
        local stage = math.clamp(saved.Stage or 0, 1, stages)
        if stage == stages then state.Ready = true;state.Segment = #state.Intervals;state.Remaining = 0
        else
            local elapsed = (stage - 1) / math.max(1, stages - 1)
            local total = 0
            for _, seconds in ipairs(state.Intervals) do total += seconds end
            elapsed *= total
            for index, seconds in ipairs(state.Intervals) do
                state.Segment = index
                if elapsed < seconds then state.Remaining = seconds - elapsed;break end
                elapsed -= seconds
            end
        end
    end
    if state.Remaining == nil then state.Remaining = state.Intervals[state.Segment] end
    growing[object] = state
    object:SetAttribute("Occupied", true)
    object:SetAttribute("PlantType", state.Type)
    object:SetAttribute("CropFruits", HttpService:JSONEncode(state.Fruits))
    publish(object, state)
    return true
end

function PlantService.Plant(player, gardenBed, seedType)
    if not canUse(player, gardenBed) or gardenBed:GetAttribute("Occupied") then return false end
    local seed = typeof(seedType) == "string" and ItemDefinitions[seedType]
    local settings = seed and config.Crops[seed.PlantId]
    local positions = getPositions(gardenBed)
    if not settings or not positions or not PlantsFolder:FindFirstChild(seed.PlantId) then return false end
    local fruits = {}
    for index in ipairs(positions) do
        fruits[index] = {}
        local count = settings.YieldMin + choose(settings.YieldWeights) - 1
        for _ = 1, count do table.insert(fruits[index], rollSize(settings)) end
    end
    if not InventoryService.RemoveItem(player, seedType, #positions) then return false end
    return PlantService.Restore(gardenBed, {Version = 2, Type = seed.PlantId, Fruits = fruits})
end

function PlantService.Water(player, gardenBed)
    if not canUse(player, gardenBed) then return false end
    local slot = player.Inventory:FindFirstChild("Slot" .. (player:GetAttribute("SelectedSlot") or 1))
    if not slot or slot.ItemName.Value ~= "WateringCan" or slot.Amount.Value < 1 then return false end
    return PlantService.ApplyWater(gardenBed)
end

function PlantService.ApplyWater(gardenBed)
    local state = growing[gardenBed]
    if not state or not state.NeedsWater or state.Ready then return false end
    state.Segment += 1
    state.Remaining = state.Intervals[state.Segment]
    state.NeedsWater = false
    gardenBed:SetAttribute("WateredAt", workspace:GetServerTimeNow())
    publish(gardenBed, state)
    return true
end

function PlantService.Harvest(player, gardenBed)
    if not canUse(player, gardenBed) or not gardenBed:GetAttribute("ReadyToHarvest") then return false end
    local state = growing[gardenBed]
    if not state then return false end
    local groups, sizes, count = {}, {}, 0
    for _, fruits in ipairs(state.Fruits) do
        for _, size in ipairs(fruits) do table.insert(sizes, size);count += 1;groups = CropItems.Merge(groups, {{Size = size, Amount = 1}}) end
    end
    if not InventoryService.ExchangeItems(player, {}, {[state.Type] = count}, {[state.Type] = groups}) then return false end
    Records.Observe(player, state.Type, sizes)
    growing[gardenBed] = nil
    for _, name in ipairs({"CropFruits", "WateredAt"}) do gardenBed:SetAttribute(name, nil) end
    gardenBed:SetAttribute("Occupied", false)
    gardenBed:SetAttribute("PlantType", "")
    gardenBed:SetAttribute("GrowthStage", 0)
    gardenBed:SetAttribute("ReadyToHarvest", false)
    gardenBed:SetAttribute("NeedsWater", false)
    return true
end

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    if elapsed < 0.2 then return end
    local step = elapsed
    elapsed = 0
    for object in pairs(growing) do
        if not object:IsDescendantOf(workspace) then growing[object] = nil
        else
            local owner = game.Players:GetPlayerByUserId(object:GetAttribute("OwnerUserId") or 0)
            if owner and owner:GetAttribute("DataLoaded") == true then PlantService.Advance(object, step) end
        end
    end
end)

return PlantService
