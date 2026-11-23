local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
    if state.Previous then state.Previous:Destroy() end
    state.Visual, state.Previous, state.Stage, state.Crop = nil, nil, nil, nil
    state.Models, state.Parts, state.PreviousParts = nil, nil, nil
end

local function opacity(parts, transparency)
    for _, part in ipairs(parts) do part.LocalTransparencyModifier = transparency end
end

local function build(state, crop, stage, template, now)
    local previous = state.Crop == crop and state.Stage and stage == state.Stage + 1 and state.Visual
    local previousParts = state.Parts
    if previous then state.Visual = nil end
    clear(state)
    local visual = Instance.new("Model")
    visual.Name = "CropVisuals"
    local models, parts = {}, {}
    for index in ipairs(state.Positions) do
        local model = template.Model:Clone()
        model.Name = "Plant" .. index
        model.Parent = visual
        models[index] = model
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") and part.Transparency < 1 then table.insert(parts, part) end
        end
    end
    if previous then
        previous.Name = "PreviousCropVisuals"
        opacity(parts, 1)
        state.Previous, state.PreviousParts, state.Transition = previous, previousParts, now
    end
    state.Crop, state.Stage, state.Visual, state.Models, state.Parts = crop, stage, visual, models, parts
    state.Scale, state.Lift = nil, nil
end

local function positionsFor(bed)
    local positions = {}
    for _, spot in ipairs(bed.PlantingSpots:GetChildren()) do
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

local function render(bed, state, now)
    local crop = bed:GetAttribute("PlantType")
    local setting = config.Crops[crop]
    if not setting then
        if state.Visual then clear(state) end
        return
    end
    if not state.Positions then state.Positions, state.Clearance = positionsFor(bed) end
    local stages = stagesFor(crop)
    if #stages == 0 then return end
    local progress = bed:GetAttribute("GrowthTarget")
    if not progress then return end
    if not bed:GetAttribute("NeedsWater") and not bed:GetAttribute("ReadyToHarvest") then
        local remaining = math.max(0, (bed:GetAttribute("GrowthEndsAt") or 0) - workspace:GetServerTimeNow())
        progress -= remaining * (bed:GetAttribute("GrowthPerSecond") or 0)
    end
    local phase = math.clamp(progress, 0, 1) * #stages
    local stage = math.min(#stages, math.floor(phase) + 1)
    local template, mature = stages[stage], stages[#stages]
    if state.Crop ~= crop or state.Stage ~= stage then build(state, crop, stage, template, now) end

    local fraction = phase - stage + 1
    local matureHeight = mature.Height * math.min(setting.VisualScale, state.Clearance / mature.Width)
    local shape = setting.GrowthShape
    local first = stage == 1 and .065 or (shape and shape[stage - 1] or (stage - 1) / #stages)
    local last = shape and shape[stage] or stage / #stages
    local scale = math.min(matureHeight * (first + (last - first) * fraction) / template.Height,
        state.Clearance / template.Width) * template.Scale
    local lift = stage == #stages and (setting.MatureLift or 0) * fraction or 0
    if not state.Scale or math.abs(scale - state.Scale) > .002 or math.abs(lift - state.Lift) > .002 or
        progress >= 1 and (scale ~= state.Scale or lift ~= state.Lift) then
        for index, plant in ipairs(state.Models) do
            plant:ScaleTo(scale)
            plant:PivotTo(state.Positions[index].CFrame + Vector3.yAxis * lift)
        end
        state.Scale, state.Lift = scale, lift
    end
    if not state.Visual.Parent then state.Visual.Parent = bed end
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

local function bind(bed)
    if not bed:IsA("Model") or not bed:FindFirstChild("PlantingSpots") then return end
    beds[bed] = {}
end
for _, bed in ipairs(plots:GetDescendants()) do bind(bed) end
plots.DescendantAdded:Connect(function(object) if object:IsA("Model") then task.defer(bind, object) end end)
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    if elapsed < 0.05 then return end
    elapsed = 0
    local camera = workspace.CurrentCamera
    local now = os.clock()
    for bed, state in pairs(beds) do
        if not bed:IsDescendantOf(plots) then clear(state);beds[bed] = nil
        elseif camera and (bed:GetPivot().Position - camera.CFrame.Position).Magnitude < config.VisualDistance then
            if now >= (state.NextRender or 0) then
                local distance = (bed:GetPivot().Position - camera.CFrame.Position).Magnitude
                state.NextRender = now + (distance > 60 and 0.5 or 0)
                render(bed, state, now)
            end
            if bed:GetAttribute("NeedsWater") and not state.Hint then
                local gui = Instance.new("BillboardGui")
                gui.Name = "WaterHint"
                gui.Size = UDim2.fromOffset(114, 34)
                gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
                gui.MaxDistance = 32
                gui.Adornee = bed.PrimaryPart or bed:FindFirstChildWhichIsA("BasePart", true)
                local label = Instance.new("TextLabel")
                label.Size = UDim2.fromScale(1, 1)
                label.BackgroundColor3 = Color3.fromRGB(255, 225, 166)
                label.TextColor3 = Color3.fromRGB(44, 110, 151)
                label.Font = Enum.Font.FredokaOne
                label.TextSize = 19
                label.Text = "Needs water"
                local corner = Instance.new("UICorner");corner.CornerRadius = UDim.new(0, 10);corner.Parent = label
                label.Parent = gui
                gui.Parent = bed
                state.Hint = gui
            elseif not bed:GetAttribute("NeedsWater") and state.Hint then state.Hint:Destroy();state.Hint = nil end
        else clear(state);if state.Hint then state.Hint:Destroy();state.Hint = nil end end
    end
end)
