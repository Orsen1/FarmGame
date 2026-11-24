local Config = require(script.Parent.Parent.Configs.GardenBedConfig)
local PlacementModels = require(script.Parent.PlacementModels)

local Layout = {}

function Layout.Bounds(template, pivot, definition, level)
    local box, size = template:GetBoundingBox()
    local extra = definition.RowWidth * (level - 1)
    local relative = template:GetPivot():ToObjectSpace(box)
    return pivot * CFrame.new(extra / 2, 0, 0) * relative, size + Vector3.new(extra, 0, 0)
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

function Layout.Expand(object, item, level)
    local definition = Config.Types[item]
    local template = PlacementModels.getTemplate(item)
    local pivot = object:GetPivot()
    if not object.PrimaryPart then object.WorldPivot = pivot end
    local extensions = object:FindFirstChild("BedExtensions")
    if not extensions then
        extensions = Instance.new("Folder")
        extensions.Name = "BedExtensions"
        extensions.Parent = object
    end
    for row = (object:GetAttribute("BedLevel") or 1) + 1, level do
        local frame = pivot * CFrame.new((row - 1) * definition.RowWidth, 0, 0)
        makeRow(template, frame, object.PlantingSpots, row, definition).Parent = extensions
    end
    object:SetAttribute("PlantingCapacity", #object.PlantingSpots:GetChildren())
    object:SetAttribute("BedLevel", level)
end

return Layout
