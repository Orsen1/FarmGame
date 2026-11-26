local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local config = require(ReplicatedStorage.Configs.CropConfig)
local plots = workspace:WaitForChild("Plots")
local visuals = Instance.new("Folder")
visuals.Name, visuals.Parent = "CropVisuals", workspace
local beds, order, cache = {}, {}, {}
local partsPerFrame = 480
local nearUpdateInterval, farUpdateInterval = 0.12, 0.5

local function stagesFor(crop)
    if cache[crop] then return cache[crop] end
    local stages = {}
    for _, source in ipairs(ReplicatedStorage.Plants[crop]:GetChildren()) do
        local index = tonumber(source.Name:match("^Stage(%d+)$"))
        if not index or not source:IsA("Model") then continue end

        local model = source:Clone()
        local parts = 0
        for _, part in ipairs(model:GetDescendants()) do
            if not part:IsA("BasePart") then continue end
            local stalk = crop == "Wheat" and part.Name:match("^%a+(%d+)_")
            if stalk == "2" or stalk == "4" or crop == "Potato" and part.Name:match("_Midrib$") then
                part:Destroy()
            else
                part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
                part.CastShadow = false
                parts += 1
            end
        end

        model:PivotTo(CFrame.identity)
        local center, size = model:GetBoundingBox()
        local outer = center.Position:Abs() + size * 0.5
        stages[index] = {Model = model, Parts = parts, Scale = model:GetScale(), Height = center.Position.Y + size.Y * 0.5,
            Width = math.max(outer.X, outer.Z) * 2}
    end
    cache[crop] = stages
    return stages
end

local function clear(state, budget)
    state.Cursor, state.NextRender = nil, 0
    local parts = 0
    if state.Visual then
        if budget then
            for spot, plant in pairs(state.Plants) do
                plant.Model:Destroy()
                state.Plants[spot] = nil
                parts += plant.Parts
                if parts >= budget then return parts end
            end
        else
            for _, plant in pairs(state.Plants) do parts += plant.Parts end
        end
        state.Visual:Destroy()
    end
    state.Visual, state.Plants, state.Crop = nil, nil, nil
    return parts
end

local function positionsFor(spots)
    local positions = {}
    for _, spot in ipairs(spots:GetChildren()) do
        local position = spot:FindFirstChild("PlantPosition")
        if position and position:IsA("BasePart") then table.insert(positions, position) end
    end
    table.sort(positions, function(a, b) return a.Parent.Name < b.Parent.Name end)
    local spacing = 2.2
    for index, a in ipairs(positions) do
        for other = index + 1, #positions do
            local delta = a.Position - positions[other].Position
            spacing = math.min(spacing, Vector2.new(delta.X, delta.Z).Magnitude)
        end
    end
    return positions, spacing * .9
end

local function readClocks(bed, state)
    local encoded = bed:GetAttribute("CropGrowth")
    if encoded == state.ClockText then return state.Clocks end
    state.ClockText, state.Clocks, state.EndsAt = encoded, {}, 0
    if encoded then
        local ok, batches = pcall(HttpService.JSONDecode, HttpService, encoded)
        if ok then
            for _, batch in ipairs(batches) do
                state.EndsAt = math.max(state.EndsAt, batch.EndsAt)
                for _, spot in ipairs(batch.Spots) do state.Clocks[spot] = batch end
            end
        end
    end
    return state.Clocks
end

local function renderPlant(state, clock, container, index, position, stages, setting, clearance, serverNow)
    local progress = 1 - math.max(0, clock.EndsAt - serverNow) * clock.Rate
    local phase = math.clamp(progress, 0, 1) * #stages
    local stage = math.min(#stages, math.floor(phase) + 1)
    local template, mature = stages[stage], stages[#stages]
    local fraction = phase - stage + 1
    local height = mature.Height * math.min(setting.VisualScale, clearance / mature.Width)
    local shape = setting.GrowthShape
    local first = stage == 1 and .065 or (shape and shape[stage - 1] or (stage - 1) / #stages)
    local last = shape and shape[stage] or stage / #stages
    local scale = math.min(height * (first + (last - first) * fraction) / template.Height,
        clearance / template.Width) * template.Scale
    local lift = stage == #stages and (setting.MatureLift or 0) * fraction or 0
    local anchor = position.CFrame
    local previous = state.Model
    if state.Stage ~= stage then
        local model = template.Model:Clone()
        model.Name = "Plant" .. index
        model:ScaleTo(scale)
        model:PivotTo(anchor + Vector3.yAxis * lift)
        model.Parent = container
        local work = 3 * template.Parts + (state.Parts or 0)
        if previous then previous:Destroy() end
        state.Model, state.Parts, state.Stage = model, template.Parts, stage
        state.Scale, state.Lift, state.Anchor = scale, lift, anchor
        return work
    end

    local work = 0
    if math.abs(scale - state.Scale) > scale * .008 or progress >= 1 and scale ~= state.Scale then
        state.Model:ScaleTo(scale)
        state.Scale = scale
        work += template.Parts
    end
    if anchor ~= state.Anchor or math.abs(lift - state.Lift) > .008 or progress >= 1 and lift ~= state.Lift then
        state.Model:PivotTo(anchor + Vector3.yAxis * lift)
        state.Anchor, state.Lift = anchor, lift
        work += template.Parts
    end
    return work
end

local function render(bed, state, now, serverNow, interval, budget)
    local crop = bed:GetAttribute("PlantType")
    local setting = config.Crops[crop]
    local clocks = readClocks(bed, state)
    if not setting or not clocks or not next(clocks) then
        if state.Visual then budget -= clear(state, budget) end
        if not state.Visual then state.NextRender = math.huge end
        return budget
    end
    if not state.Positions then
        state.Positions, state.Clearance = positionsFor(state.Spots)
        state.PositionNames = {}
        for _, position in ipairs(state.Positions) do state.PositionNames[position.Parent.Name] = true end
    end
    if #state.Positions == 0 then
        state.NextRender = math.huge
        return budget
    end
    local stages = stagesFor(crop)
    if #stages == 0 then return budget end
    if state.Crop ~= crop then
        budget -= clear(state, budget)
        if budget <= 0 then return budget end
        state.Crop, state.Plants = crop, {}
        local container = Instance.new("Model")
        container.Name, container.Parent = bed.Name, visuals
        state.Visual = container
    end
    if not state.Cursor then
        state.Cursor, state.SampleTime = 1, serverNow
        for spot, plant in pairs(state.Plants) do
            if not clocks[spot] or not state.PositionNames[spot] then
                plant.Model:Destroy()
                budget -= plant.Parts
                state.Plants[spot] = nil
            end
        end
    end
    while state.Cursor <= #state.Positions and budget > 0 do
        local index = state.Cursor
        local position = state.Positions[index]
        local spot = position.Parent.Name
        local clock = clocks[spot]
        if clock then
            local plant = state.Plants[spot]
            if not plant then plant = {};state.Plants[spot] = plant end
            budget -= renderPlant(plant, clock, state.Visual, index, position, stages, setting, state.Clearance, state.SampleTime)
        end
        state.Cursor += 1
    end
    if state.Cursor > #state.Positions then
        state.Cursor = nil
        state.NextRender = state.SampleTime >= state.EndsAt and math.huge or now + interval
    end
    return budget
end

local function unbind(state)
    state.Added:Disconnect()
    state.Removing:Disconnect()
    state.ClockChanged:Disconnect()
    state.CropChanged:Disconnect()
    return clear(state)
end

local function bind(spots)
    if spots.Name ~= "PlantingSpots" or not spots:IsA("Folder") then return end
    local bed = spots.Parent
    if not bed or not bed:IsA("Model") then return end
    local existing = beds[bed]
    if existing and existing.Spots == spots then return end
    if existing then unbind(existing) else table.insert(order, bed) end
    local state = {Spots = spots, NextRender = 0}
    local function invalidateGrowth()
        state.HasGrowth = bed:GetAttribute("CropGrowth") ~= nil
        state.Cursor, state.NextRender = nil, 0
    end
    local function invalidatePositions()
        state.Positions = nil
        invalidateGrowth()
    end
    state.Added = spots.DescendantAdded:Connect(invalidatePositions)
    state.Removing = spots.DescendantRemoving:Connect(invalidatePositions)
    state.ClockChanged = bed:GetAttributeChangedSignal("CropGrowth"):Connect(invalidateGrowth)
    state.CropChanged = bed:GetAttributeChangedSignal("PlantType"):Connect(invalidateGrowth)
    invalidateGrowth()
    beds[bed] = state
end
plots.DescendantAdded:Connect(bind)
for _, object in ipairs(plots:GetDescendants()) do bind(object) end
local nextBed = 1
RunService.Heartbeat:Connect(function()
    local camera = workspace.CurrentCamera
    if not camera or #order == 0 then return end
    local eye = camera.CFrame.Position
    local now = os.clock()
    local serverNow = workspace:GetServerTimeNow()
    local budget = partsPerFrame
    for _ = 1, #order do
        if budget <= 0 then break end
        if nextBed > #order then nextBed = 1 end
        local bed = order[nextBed]
        local state = beds[bed]
        if not bed:IsDescendantOf(plots) or state.Spots.Parent ~= bed then
            budget -= unbind(state)
            table.remove(order, nextBed)
            beds[bed] = nil
            if #order == 0 then break end
            continue
        end
        nextBed += 1
        if not state.HasGrowth and not state.Visual then continue end
        local pivot = bed:GetPivot()
        if pivot ~= state.Pivot then
            state.Pivot, state.Cursor, state.NextRender = pivot, nil, 0
        end
        local distance = (pivot.Position - eye).Magnitude
        if distance <= config.VisualDistance + (state.Visual and 10 or 0) then
            if now >= state.NextRender then
                local interval = distance <= 60 and nearUpdateInterval or farUpdateInterval
                budget = render(bed, state, now, serverNow, interval, budget)
            end
        elseif state.Visual then
            budget -= clear(state, budget)
        end
    end
end)
