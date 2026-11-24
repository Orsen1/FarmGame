local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local config = require(ReplicatedStorage.Configs.CropConfig)
local plots = workspace:WaitForChild("Plots")
local beds, cache = {}, {}
local transitionTime = 0.42

local function stagesFor(crop)
    if cache[crop] then return cache[crop] end
    local stages = {}
    for _, source in ipairs(ReplicatedStorage.Plants[crop]:GetChildren()) do
        local index = tonumber(source.Name:match("^Stage(%d+)$"))
        if not index or not source:IsA("Model") then continue end

        local model = source:Clone()
        for _, part in ipairs(model:GetDescendants()) do
            if not part:IsA("BasePart") then continue end
            local stalk = crop == "Wheat" and part.Name:match("^%a+(%d+)_")
            if stalk == "2" or stalk == "4" or crop == "Potato" and part.Name:match("_Midrib$") then
                part:Destroy()
            else
                part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
            end
        end

        model:PivotTo(CFrame.identity)
        local center, size = model:GetBoundingBox()
        local outer = center.Position:Abs() + size * 0.5
        stages[index] = {Model = model, Scale = model:GetScale(), Height = center.Position.Y + size.Y * 0.5,
            Width = math.max(outer.X, outer.Z) * 2}
    end
    cache[crop] = stages
    return stages
end

local function clear(state)
    if state.Visual then state.Visual:Destroy() end
    state.Visual, state.Plants, state.Crop = nil, nil, nil
end

local function opacity(parts, transparency)
    for _, part in ipairs(parts) do part.LocalTransparencyModifier = transparency end
end

local function changeStage(state, stage, template, name, now)
    local previous = state.Stage and stage == state.Stage + 1 and state.Model
    if state.Previous then state.Previous:Destroy() end
    if state.Model and not previous then state.Model:Destroy() end
    local model, parts = template.Model:Clone(), {}
    model.Name = name
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") and part.Transparency < 1 then table.insert(parts, part) end
    end
    state.Previous, state.PreviousParts = previous, previous and state.Parts
    if previous then
        previous.Name = name .. "Previous"
        opacity(parts, 1)
        state.Transition = now
    end
    state.Model, state.Parts, state.Stage = model, parts, stage
    state.Scale, state.Lift = nil, nil
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
    state.ClockText, state.Clocks = encoded, {}
    if encoded then
        local ok, batches = pcall(HttpService.JSONDecode, HttpService, encoded)
        if ok then
            for _, batch in ipairs(batches) do
                for _, spot in ipairs(batch.Spots) do state.Clocks[spot] = batch end
            end
        end
    end
    return state.Clocks
end

local function renderPlant(state, clock, container, index, position, stages, setting, clearance, now, serverNow)
    local progress = 1 - math.max(0, clock.EndsAt - serverNow) * clock.Rate
    local phase = math.clamp(progress, 0, 1) * #stages
    local stage = math.min(#stages, math.floor(phase) + 1)
    local template, mature = stages[stage], stages[#stages]
    if state.Stage ~= stage then changeStage(state, stage, template, "Plant" .. index, now) end

    local fraction = phase - stage + 1
    local height = mature.Height * math.min(setting.VisualScale, clearance / mature.Width)
    local shape = setting.GrowthShape
    local first = stage == 1 and .065 or (shape and shape[stage - 1] or (stage - 1) / #stages)
    local last = shape and shape[stage] or stage / #stages
    local scale = math.min(height * (first + (last - first) * fraction) / template.Height,
        clearance / template.Width) * template.Scale
    local lift = stage == #stages and (setting.MatureLift or 0) * fraction or 0
    if not state.Scale or math.abs(scale - state.Scale) > .002 or math.abs(lift - state.Lift) > .002 or
        progress >= 1 and (scale ~= state.Scale or lift ~= state.Lift) then
        state.Model:ScaleTo(scale)
        state.Model:PivotTo(position.CFrame + Vector3.yAxis * lift)
        state.Scale, state.Lift = scale, lift
    end
    if not state.Model.Parent then state.Model.Parent = container end
    if state.Previous then
        local blend = math.clamp((now - state.Transition) / transitionTime, 0, 1)
        opacity(state.Parts, 1 - blend)
        if blend >= 1 then
            state.Previous:Destroy()
            state.Previous, state.PreviousParts = nil, nil
        else
            opacity(state.PreviousParts, blend)
        end
    end
end

local function render(bed, state, now)
    local crop = bed:GetAttribute("PlantType")
    local setting = config.Crops[crop]
    local clocks = readClocks(bed, state)
    if not setting or not clocks or not next(clocks) then
        if state.Visual then clear(state) end
        return
    end
    if not state.Positions then
        state.Positions, state.Clearance = positionsFor(state.Spots)
        state.PositionNames = {}
        for _, position in ipairs(state.Positions) do state.PositionNames[position.Parent.Name] = true end
    end
    if #state.Positions == 0 then return end
    if state.Crop ~= crop or state.Visual.Parent ~= bed then
        clear(state)
        state.Crop, state.Plants = crop, {}
        local container = Instance.new("Model")
        container.Name, container.Parent = "CropVisuals", bed
        state.Visual = container
    end
    local stages = stagesFor(crop)
    if #stages == 0 then return end
    local serverNow = workspace:GetServerTimeNow()
    for spot, plant in pairs(state.Plants) do
        if not clocks[spot] or not state.PositionNames[spot] then
            plant.Model:Destroy()
            if plant.Previous then plant.Previous:Destroy() end
            state.Plants[spot] = nil
        end
    end
    for index, position in ipairs(state.Positions) do
        local spot = position.Parent.Name
        local clock = clocks[spot]
        if clock then
            local plant = state.Plants[spot]
            if not plant then plant = {};state.Plants[spot] = plant end
            renderPlant(plant, clock, state.Visual, index, position, stages, setting, state.Clearance, now, serverNow)
        end
    end
end

local function unbind(state)
    clear(state)
    state.Added:Disconnect()
    state.Removing:Disconnect()
end

local function bind(spots)
    if spots.Name ~= "PlantingSpots" or not spots:IsA("Folder") then return end
    local bed = spots.Parent
    if not bed or not bed:IsA("Model") then return end
    local existing = beds[bed]
    if existing and existing.Spots == spots then
        existing.Positions, existing.NextRender = nil, nil
        return
    end
    if existing then unbind(existing) end
    local state = {Spots = spots}
    local function invalidate()
        state.Positions, state.NextRender = nil, nil
    end
    state.Added = spots.DescendantAdded:Connect(invalidate)
    state.Removing = spots.DescendantRemoving:Connect(invalidate)
    beds[bed] = state
end
plots.DescendantAdded:Connect(bind)
for _, object in ipairs(plots:GetDescendants()) do bind(object) end
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    if elapsed < 0.05 then return end
    elapsed = 0
    local camera = workspace.CurrentCamera
    local now = os.clock()
    for bed, state in pairs(beds) do
        if not bed:IsDescendantOf(plots) or state.Spots.Parent ~= bed then
            unbind(state)
            beds[bed] = nil
        elseif camera and (bed:GetPivot().Position - camera.CFrame.Position).Magnitude < config.VisualDistance then
            if now >= (state.NextRender or 0) then
                local distance = (bed:GetPivot().Position - camera.CFrame.Position).Magnitude
                state.NextRender = now + (distance > 60 and 0.5 or 0)
                render(bed, state, now)
            end
        else clear(state) end
    end
end)
