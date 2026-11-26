local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Definitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local BedConfig = require(ReplicatedStorage.Configs.GardenBedConfig)
local Models = require(script.Parent.PlacementModels)
local Beds = require(script.Parent.GardenBedLayout)
local House = require(script.Parent.StarterHouseLayout)

local step = 2
local epsilon = .001
local Rules = {CellSize = step}
local shapes = {}
local nextBlueprint, previousBuilding, paths = {}, {}, {}
for _, definition in pairs(Definitions) do
    if definition.UpgradeFrom and definition.PacksInto then
        nextBlueprint[definition.UpgradeFrom] = definition.PacksInto
        previousBuilding[Definitions[definition.PacksInto].BuildsInto] = definition.UpgradeFrom
    end
end

local function levelsFor(item)
    if paths[item] then return paths[item] end
    local building = Definitions[item].BuildsInto or item
    local first, previous = 1, previousBuilding[building]
    while previous do first += 1; previous = previousBuilding[previous] end
    local path = {First = first, Max = first, [first] = item}
    local bed = BedConfig.Types[item]
    if bed then
        path.Max += #bed.UpgradePrices
    else
        while nextBlueprint[building] do
            local blueprint = nextBlueprint[building]
            path.Max += 1
            path[path.Max] = blueprint
            building = Definitions[blueprint].BuildsInto
        end
    end
    paths[item] = path
    return path
end

local function shape(model)
    if not shapes[model] then
        local box, size = model:GetBoundingBox()
        shapes[model] = {Frame = model:GetPivot():ToObjectSpace(box), Size = size}
    end
    return shapes[model]
end

function Rules.Levels(item)
    local path = levelsFor(item)
    return path.First, path.Max
end

function Rules.LevelTemplate(item, level)
    return Models.getTemplate(levelsFor(item)[level] or item)
end

local function bounds(item, pivot, level)
    local model = Rules.LevelTemplate(item, level)
    local bed = BedConfig.Types[item]
    if bed then return Beds.Bounds(model, pivot, bed, level) end
    local s = shape(model)
    return pivot * s.Frame, s.Size
end

function Rules.movableItem(plot, object, owner)
    local placed = plot:FindFirstChild("PlacedObjects")
    if not placed or typeof(object) ~= "Instance" or not object:IsA("Model") or object.Parent ~= placed
        or object:GetAttribute("OwnerUserId") ~= owner then return end
    local item = object:GetAttribute("ItemName") or object.Name
    local definition = Definitions[item]
    if definition and definition.Placeable and not definition.PermanentHouse and not definition.FixedWarehouse
        and Models.getTemplate(item) then return item end
end

function Rules.moveOrigin(plot, object, item, level)
    local box = bounds(item, object:GetPivot(), level)
    local forward = plot.Ground.CFrame:VectorToObjectSpace(box.LookVector)
    local rotation = math.round(math.atan2(forward.X, -forward.Z) / (math.pi / 2)) % 4
    return box.Position, rotation
end

local function radii(frame, size)
    return (math.abs(frame.RightVector.X) * size.X + math.abs(frame.ZVector.X) * size.Z) / 2,
        (math.abs(frame.RightVector.Z) * size.X + math.abs(frame.ZVector.Z) * size.Z) / 2
end

local function cellBox(ground, box, size)
    local frame = ground.CFrame:ToObjectSpace(box)
    local x, z = radii(frame, size)
    local lowX = math.floor((frame.X - x + epsilon) / step) * step
    local lowZ = math.floor((frame.Z - z + epsilon) / step) * step
    local highX = math.ceil((frame.X + x - epsilon) / step) * step
    local highZ = math.ceil((frame.Z + z - epsilon) / step) * step
    return ground.CFrame * CFrame.new((lowX + highX) / 2, frame.Y, (lowZ + highZ) / 2),
        Vector3.new(highX - lowX, size.Y, highZ - lowZ)
end

local function landError(plot, ground, frame, size)
    local point = ground.CFrame:PointToObjectSpace(frame.Position)
    local function area(floor)
        local center = ground.CFrame:PointToObjectSpace(floor.Position)
        local x = math.min(point.X + size.X / 2, center.X + floor.Size.X / 2)
            - math.max(point.X - size.X / 2, center.X - floor.Size.X / 2)
        local z = math.min(point.Z + size.Z / 2, center.Z + floor.Size.Z / 2)
            - math.max(point.Z - size.Z / 2, center.Z - floor.Size.Z / 2)
        return math.max(x, 0) * math.max(z, 0)
    end
    local covered, locked = area(ground), 0
    local sections = plot:FindFirstChild("Sections")
    for _, section in ipairs(sections and sections:GetChildren() or {}) do
        local floor = section:FindFirstChild("Ground")
        if floor then
            if section:GetAttribute("Unlocked") then covered += area(floor) else locked += area(floor) end
        end
    end
    if covered + .01 >= size.X * size.Z then return end
    return covered + locked + .01 >= size.X * size.Z and "Unlock this land first" or "Outside your farm"
end

local function validate(plot, frame, size, ignore, character)
    local ground = plot.Ground
    local reason = landError(plot, ground, frame, size)
    if reason then return false, reason end
    if House.Overlaps(plot, frame, size) then return false, "Leave room for the farmhouse" end
    local placed = plot:FindFirstChild("PlacedObjects")
    for _, object in ipairs(placed and placed:GetChildren() or {}) do
        local item = object:GetAttribute("ItemName") or object.Name
        if object ~= ignore and object:IsA("Model") and Definitions[item] and Models.getTemplate(item) then
            local box, extent = bounds(item, object:GetPivot(), object:GetAttribute("BedLevel") or Rules.Levels(item))
            if House.BoxesOverlap(frame, size, box, extent) then return false, "This space is occupied" end
        end
    end

    local ignored = {ground}
    for _, instance in pairs({plot:FindFirstChild("Sections"), ignore, character, plot:FindFirstChild("SpawnPoint")}) do
        table.insert(ignored, instance)
    end
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignored
    local querySize = Vector3.new(size.X - .02, math.max(size.Y - .02, .01), size.Z - .02)
    for _, part in ipairs(workspace:GetPartBoundsInBox(frame, querySize, params)) do
        if part.CanCollide or (placed and part:IsDescendantOf(placed)) then return false, "This space is occupied" end
    end
    return true, ""
end

local function snapPlacement(plot, position, frame, size, rotation, ignore, pivotHeight)
    if typeof(position) ~= "Vector3" or not (position.Magnitude < 1000000) then return nil, false, "Invalid position" end
    if rotation == nil then rotation = 0 end
    if typeof(rotation) ~= "number" or rotation % 1 ~= 0 or rotation < 0 or rotation > 3 then
        return nil, false, "Invalid rotation"
    end
    local ground = plot:FindFirstChild("Ground")
    if not ground then return nil, false, "Ground is missing" end
    local point = ground.CFrame:PointToObjectSpace(position)
    local width, depth = size.X, size.Z
    if rotation % 2 == 1 then width, depth = depth, width end
    local function snap(value, length)
        local half = math.ceil((length - epsilon) / step) * step / 2
        return math.round((value - half) / step) * step + half
    end
    local height = pivotHeight and pivotHeight + frame.Y or (ground.Size.Y + size.Y) / 2
    local box = ground.CFrame * CFrame.new(snap(point.X, width), height, snap(point.Z, depth))
        * CFrame.Angles(0, -rotation * math.pi / 2, 0)
    local cells, extent = cellBox(ground, box, size)
    local valid, reason = validate(plot, cells, extent, ignore)
    return box * frame:Inverse(), valid, reason, cells, extent
end

function Rules.getPlacement(plot, position, template, rotation, ignore)
    local s = shape(template)
    return snapPlacement(plot, position, s.Frame, s.Size, rotation, ignore)
end

function Rules.getMovePlacement(plot, object, item, position, rotation)
    local level = object:GetAttribute("BedLevel") or Rules.Levels(item)
    local frame, size = bounds(item, CFrame.identity, level)
    local height = plot.Ground.CFrame:PointToObjectSpace(object:GetPivot().Position).Y
    return snapPlacement(plot, position, frame, size, rotation, object, height)
end

function Rules.levelArea(plot, item, pivot, level, ignore, character)
    local box, size = bounds(item, pivot, level)
    local cells, extent = cellBox(plot.Ground, box, size)
    local valid, reason = validate(plot, cells, extent, ignore, character)
    return cells, extent, valid, reason
end

function Rules.getBedExpansion(plot, object, item, level, character)
    return Rules.levelArea(plot, item, object:GetPivot(), level, object, character)
end

return Rules
