local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local config = require(ReplicatedStorage.Configs.CropConfig)
local plots = workspace:WaitForChild("Plots")
local beds = {}
local cache = {}

local function physical(part)
    part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
end

local function templates(crop, stage)
    local key = crop .. stage
    if cache[key] then return cache[key] end
    local source = ReplicatedStorage.Plants[crop]:FindFirstChild("Stage" .. stage)
    if not source then return end
    local settings = config.Crops[crop]
    local whole = settings.Visual == "Whole" or settings.Visual == "Wheat"
    local base = source:Clone()
    local fruit = whole and base or Instance.new("Model")
    local anchor
    for _, part in ipairs(source:GetDescendants()) do
        if part:IsA("BasePart") and part.Name == settings.FruitAnchor then anchor = part;break end
    end
    local anchors = {}
    if whole then
        for _, part in ipairs(base:GetDescendants()) do
            if part:IsA("BasePart") then
                if settings.Visual == "Wheat" and part.Name:match("^[A-Za-z]+[2-9]_") then part:Destroy()
                else physical(part) end
            end
        end
        base:PivotTo(CFrame.identity)
    else
        for _, part in ipairs(source:GetDescendants()) do
            if part:IsA("BasePart") and part.Name == settings.FruitAnchor then table.insert(anchors, part) end
        end
        for _, part in ipairs(base:GetDescendants()) do
            if part:IsA("BasePart") then
                local isFruit = settings.FruitNames and settings.FruitNames[part.Name] or
                    settings.FruitPattern and part.Name:match(settings.FruitPattern)
                if isFruit then
                    local selected = anchor
                    for _, candidate in ipairs(anchors) do
                        if (candidate.Position - part.Position).Magnitude < (selected.Position - part.Position).Magnitude then selected = candidate end
                    end
                    if anchor and selected == anchor and (crop ~= "Potato" or part.Name:match("^Potato1")) then
                        local copy = part:Clone()
                        physical(copy)
                        copy.Parent = fruit
                    end
                    part:Destroy()
                else physical(part) end
            end
        end
        if anchor then fruit.WorldPivot = CFrame.new(anchor.Position) end
    end
    local points = {}
    for _, point in ipairs(anchors) do table.insert(points, point.Position) end
    local result = {Base = base, Fruit = fruit, Whole = whole, Anchor = anchor and anchor.Position, Points = points}
    cache[key] = result
    return result
end

local function clear(state)
    if state.Visual then state.Visual:Destroy();state.Visual = nil end
    state.Key = nil
end

local function render(bed, state)
    local crop, stage = bed:GetAttribute("PlantType"), bed:GetAttribute("GrowthStage") or 0
    local encoded = bed:GetAttribute("CropFruits")
    local key = tostring(crop) .. stage .. tostring(encoded)
    if state.Key == key then return end
    clear(state)
    if not config.Crops[crop] or stage < 1 or not encoded then return end
    local ok, fruits = pcall(HttpService.JSONDecode, HttpService, encoded)
    if not ok then return end
    local data = templates(crop, stage)
    if not data then return end
    local positions = {}
    for _, spot in ipairs(bed.PlantingSpots:GetChildren()) do table.insert(positions, spot.PlantPosition) end
    table.sort(positions, function(a, b) return a.Parent.Name < b.Parent.Name end)
    local visual = Instance.new("Model")
    visual.Name = "CropVisuals"
    for index, position in ipairs(positions) do
        local sizes = fruits[index]
        local radius = 1.01
        for other, neighbor in ipairs(positions) do
            if index ~= other then radius = math.min(radius, (position.Position - neighbor.Position).Magnitude * 0.46) end
        end
        if not data.Whole then
            local foliage = data.Base:Clone()
            foliage.Name = "Foliage" .. index
            foliage:PivotTo(position.CFrame)
            foliage.Parent = visual
        end
        if data.Whole or data.Anchor then
            local width = data.Fruit:GetExtentsSize()
            local maxSize = config.Crops[crop].SizeMax / 100
            local spread = #sizes > 1 and radius * 0.57 or 0
            local clearance = config.Crops[crop].YieldMax > 1 and radius * 0.43 or radius
            local fit = math.min(1, clearance * 2 / (math.max(width.X, width.Z) * maxSize))
            for number, size in ipairs(sizes) do
                local model = data.Fruit:Clone()
                model.Name = "Spot" .. index .. "Fruit" .. number
                model:SetAttribute("Size", size)
                model:ScaleTo(model:GetScale() * fit * size / 100)
                local angle = (number - 1) * math.pi * 2 / #sizes
                local offset = Vector3.new(math.cos(angle) * spread, 0, math.sin(angle) * spread)
                if not data.Whole then
                    if crop == "Potato" or crop == "Pumpkin" then
                        local box, bounds = model:GetBoundingBox()
                        local bottom = model:GetPivot():PointToObjectSpace(box.Position).Y - bounds.Y / 2
                        offset += Vector3.new(0, 0.04 - bottom, 0)
                    else
                        local point = data.Points[(number - 1) % #data.Points + 1]
                        offset = point
                        if number > #data.Points then offset += Vector3.new(math.cos(angle) * 0.15, 0.15, math.sin(angle) * 0.15) end
                        if crop == "Corn" then offset = Vector3.new(number % 2 == 0 and -0.2 or 0.2, point.Y + (number > #data.Points and 0.4 or 0), 0) end
                        local box, bounds = model:GetBoundingBox()
                        local bottom = model:GetPivot():PointToObjectSpace(box.Position).Y - bounds.Y / 2
                        offset = Vector3.new(offset.X, math.max(offset.Y, 0.04 - bottom), offset.Z)
                    end
                end
                model:PivotTo(position.CFrame * CFrame.new(offset))
                model.Parent = visual
            end
        end
    end
    visual.Parent = bed
    state.Visual, state.Key = visual, key
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
    if elapsed < 0.25 then return end
    elapsed = 0
    local camera = workspace.CurrentCamera
    for bed, state in pairs(beds) do
        if not bed:IsDescendantOf(plots) then clear(state);beds[bed] = nil
        elseif camera and (bed:GetPivot().Position - camera.CFrame.Position).Magnitude < config.VisualDistance then
            render(bed, state)
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
