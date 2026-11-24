local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDefinitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local PlacementModels = require(script.Parent.PlacementModels)
local BedLayout = require(script.Parent.GardenBedLayout)
local BedConfig = require(ReplicatedStorage.Configs.GardenBedConfig)
local StarterHouseLayout = require(script.Parent.StarterHouseLayout)
local PlacementRules = {}
local footprints = {}
local snapDistance = 2.5
local snapGap = 0.12
local edgeAlignments = {0, -1, 1}

local function footprint(template)
    if not footprints[template] then
        local box, size = template:GetBoundingBox()
        footprints[template] = { Size = size, BoxToPivot = box:ToObjectSpace(template:GetPivot()) }
    end
    return footprints[template]
end

local function getHalfSize(size, rotation)
    if rotation % 2 == 1 then
        return size.Z / 2, size.X / 2
    end
    return size.X / 2, size.Z / 2
end

local function insideUnlockedLand(ground, sections, point, halfX, halfZ)
    local function overlap(center, size)
        local width = math.min(point.X + halfX, center.X + size.X / 2)
            - math.max(point.X - halfX, center.X - size.X / 2)
        local depth = math.min(point.Z + halfZ, center.Z + size.Z / 2)
            - math.max(point.Z - halfZ, center.Z - size.Z / 2)
        return math.max(0, width) * math.max(0, depth)
    end

    local covered = overlap(Vector3.zero, ground.Size)
    if sections then
        for _, section in ipairs(sections:GetChildren()) do
            local floor = section:FindFirstChild("Ground")
            if floor and section:GetAttribute("Unlocked") == true then
                covered += overlap(ground.CFrame:PointToObjectSpace(floor.Position), floor.Size)
            end
        end
    end
    return covered >= 4 * halfX * halfZ - 0.005
end

local function validateBounds(plot, ground, targetBox, boxSize, ignoredObject, character)
    local box = ground.CFrame:ToObjectSpace(targetBox)
    local halfX = (math.abs(box.RightVector.X) * boxSize.X + math.abs(box.ZVector.X) * boxSize.Z) / 2
    local halfZ = (math.abs(box.RightVector.Z) * boxSize.X + math.abs(box.ZVector.Z) * boxSize.Z) / 2
    local sections = plot:FindFirstChild("Sections")
    if not insideUnlockedLand(ground, sections, box.Position, halfX, halfZ) then
        return false, "Keep the whole object inside your unlocked land"
    end

    if StarterHouseLayout.Overlaps(plot, targetBox, boxSize) then
        return false, "Leave room for the farmhouse"
    end

    local ignored = {ground}
    for _, instance in pairs({sections, ignoredObject, character, plot:FindFirstChild("SpawnPoint")}) do
        table.insert(ignored, instance)
    end

    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignored

    local placedObjects = plot:FindFirstChild("PlacedObjects")
    local querySize = Vector3.new(math.max(boxSize.X - 0.02, 0.001), math.max(boxSize.Y - 0.02, 0.001),
        math.max(boxSize.Z - 0.02, 0.001))

    for _, part in ipairs(workspace:GetPartBoundsInBox(targetBox, querySize, params)) do
        if part.CanCollide or (placedObjects and part:IsDescendantOf(placedObjects)) then
            return false, "This space is occupied"
        end
    end
    return true, ""
end

function PlacementRules.getPlacement(plot, position, template, rotation, preview)
    if typeof(position) ~= "Vector3" then
        return nil, false, "Invalid position"
    end

    for _, value in ipairs({position.X, position.Y, position.Z}) do
        if value ~= value or math.abs(value) > 1000000 then
            return nil, false, "Invalid position"
        end
    end

    rotation = rotation == nil and 0 or rotation
    if typeof(rotation) ~= "number" or rotation % 1 ~= 0 or rotation < 0 or rotation > 3 then
        return nil, false, "Invalid rotation"
    end

    local ground = plot:FindFirstChild("Ground")
    if not ground or not ground:IsA("BasePart") then
        return nil, false, "Ground is missing"
    end

    local shape = footprint(template)
    local boxSize = shape.Size
    local point = ground.CFrame:PointToObjectSpace(position)

    local targetBox = ground.CFrame * CFrame.new(point.X, ground.Size.Y / 2 + boxSize.Y / 2, point.Z)

        * CFrame.Angles(0, -rotation * math.pi / 2, 0)
    local targetPivot = targetBox * shape.BoxToPivot

    local valid, reason = validateBounds(plot, ground, targetBox, boxSize, preview)
    return targetPivot, valid, reason
end

function PlacementRules.getBedExpansion(plot, object, itemName, level, character)
    local ground = plot:FindFirstChild("Ground")
    local template = PlacementModels.getTemplate(itemName)
    local box, size = BedLayout.Bounds(template, object:GetPivot(), BedConfig.Types[itemName], level)
    local valid, reason = validateBounds(plot, ground, box, size, object, character)
    return box, size, valid, reason
end

function PlacementRules.getSnapPosition(plot, position, template, rotation, itemName, preview)
    local definition = ItemDefinitions[itemName]
    local objects = plot:FindFirstChild("PlacedObjects")
    local ground = plot:FindFirstChild("Ground")
    if not definition or not definition.PlacementSnapGroup or not objects or not ground then
        return
    end

    local point = ground.CFrame:PointToObjectSpace(position)
    local cursor = Vector2.new(point.X, point.Z)
    local halfX, halfZ = getHalfSize(footprint(template).Size, rotation)
    local bestPosition
    local bestDistance = snapDistance
    local function consider(x, z)
        local distance = (Vector2.new(x, z) - cursor).Magnitude
        if distance < bestDistance then
            local candidate = ground.CFrame:PointToWorldSpace(Vector3.new(x, point.Y, z))
            local _, valid = PlacementRules.getPlacement(plot, candidate, template, rotation, preview)
            if valid then
                bestPosition = candidate
                bestDistance = distance
            end
        end
    end

    for _, object in ipairs(objects:GetChildren()) do
        local neighborId = object:GetAttribute("ItemName") or object.Name
        local neighbor = ItemDefinitions[neighborId]
        if not object:IsA("Model") or not neighbor or neighbor.PlacementSnapGroup ~= definition.PlacementSnapGroup then
            continue
        end
        local neighborTemplate = PlacementModels.getTemplate(neighborId)
        if not neighborTemplate then
            continue
        end
        local shape = footprint(neighborTemplate)
        local box = object:GetPivot() * shape.BoxToPivot:Inverse()
        local size = shape.Size
        local bed = BedConfig.Types[neighborId]
        local level = object:GetAttribute("BedLevel")
        if bed and level and level > 1 then
            box, size = BedLayout.Bounds(neighborTemplate, object:GetPivot(), bed, level)
        end
        box = ground.CFrame:ToObjectSpace(box)
        local center = box.Position
        local neighborX, neighborZ = getHalfSize(size, math.abs(box.RightVector.X) > 0.99 and 0 or 1)
        local sideX = halfX + neighborX + snapGap
        local sideZ = halfZ + neighborZ + snapGap
        local alignX = math.abs(halfX - neighborX)
        local alignZ = math.abs(halfZ - neighborZ)

        for _, offset in ipairs(edgeAlignments) do
            consider(center.X - sideX, center.Z + alignZ * offset)
            consider(center.X + sideX, center.Z + alignZ * offset)
            consider(center.X + alignX * offset, center.Z - sideZ)
            consider(center.X + alignX * offset, center.Z + sideZ)
        end
    end
    return bestPosition
end

return PlacementRules
