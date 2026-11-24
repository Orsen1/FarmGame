local Config = require(script.Parent.Parent.Configs.GardenBedConfig)
local PlacementModels = require(script.Parent.PlacementModels)
local upgrades = script.Parent.Parent.FarmModels:WaitForChild("GardenBedUpgrades")

local Layout = {}
local bounds = {}

local function appearanceFor(definition, level)
    if definition.Appearance and level > 1 then
        return upgrades[definition.Appearance .. "Level" .. level]
    end
end

local function localBounds(model)
    local cached = bounds[model]
    if not cached then
        local box, size = model:GetBoundingBox()
        cached = {Frame = model:GetPivot():ToObjectSpace(box), Size = size}
        bounds[model] = cached
    end
    return cached
end

function Layout.Bounds(template, pivot, definition, level)
    local appearance = appearanceFor(definition, level)
    local shape = localBounds(appearance or template)
    local extra = appearance and 0 or definition.RowWidth * (level - 1)
    return pivot * CFrame.new(extra / 2, 0, 0) * shape.Frame, shape.Size + Vector3.new(extra, 0, 0)
end

function Layout.SpaceSaved(item, level)
    local template = PlacementModels.getTemplate(item)
    local base = localBounds(template).Size
    local _, size = Layout.Bounds(template, CFrame.identity, Config.Types[item], level)
    return math.round(100 * (1 - size.X * size.Z / (base.X * base.Z * level)))
end

local function makeRow(template, frame, spots, row, definition)
    local model = template:Clone()
    model:PivotTo(frame)
    local additions = Instance.new("Folder")
    additions.Name = "Row" .. row

    for _, instance in ipairs(model:GetDescendants()) do
        if instance:IsA("BasePart") then
            instance.Anchored = true
            instance.CanQuery = true
        elseif instance:IsA("ProximityPrompt") or instance:IsA("JointInstance") or instance:IsA("Constraint") or
            instance:IsA("LuaSourceContainer") then
            instance:Destroy()
        end
    end
    for _, spot in ipairs(model.PlantingSpots:GetChildren()) do
        local index = tonumber(spot.Name:match("%d+$"))
        spot.Name = string.format("Spot%02d", (row - 1) * definition.SpotsPerRow + index)
        spot.Parent = spots
    end
    model.PlantingSpots:Destroy()
    if model:FindFirstChild("Welds") then model.Welds:Destroy() end
    for _, part in ipairs(model:GetChildren()) do part.Parent = additions end
    model:Destroy()
    return additions
end

local function addSpots(template, frame, spots, row, definition)
    local transform = frame * template:GetPivot():Inverse()
    for _, source in ipairs(template.PlantingSpots:GetChildren()) do
        local spot = source:Clone()
        local index = tonumber(source.Name:match("%d+$"))
        spot.Name = string.format("Spot%02d", (row - 1) * definition.SpotsPerRow + index)
        spot.PlantPosition.CFrame = transform * source.PlantPosition.CFrame
        spot.Parent = spots
    end
end

local function replaceAppearance(object, appearance, pivot)
    local previous = object:FindFirstChild("BedAppearance") or object:FindFirstChild("Soil")
    local model = appearance:Clone()
    model.Name = "BedAppearance"
    model:PivotTo(pivot)
    if previous then previous:Destroy() end
    model.Parent = object
end

function Layout.Expand(object, item, level)
    local definition = Config.Types[item]
    local template = PlacementModels.getTemplate(item)
    local pivot = object:GetPivot()
    if not object.PrimaryPart then object.WorldPivot = pivot end
    local appearance = appearanceFor(definition, level)
    local extensions = object:FindFirstChild("BedExtensions")
    if not extensions and not appearance then
        extensions = Instance.new("Folder")
        extensions.Name = "BedExtensions"
        extensions.Parent = object
    end
    for row = (object:GetAttribute("BedLevel") or 1) + 1, level do
        local frame = pivot * CFrame.new((row - 1) * definition.RowWidth, 0, 0)
        if appearance then
            addSpots(template, frame, object.PlantingSpots, row, definition)
        else
            makeRow(template, frame, object.PlantingSpots, row, definition).Parent = extensions
        end
    end
    if appearance then replaceAppearance(object, appearance, pivot) end
    object:SetAttribute("PlantingCapacity", #object.PlantingSpots:GetChildren())
    object:SetAttribute("BedLevel", level)
end

return Layout
