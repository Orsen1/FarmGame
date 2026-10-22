local ReplicatedStorage = game:GetService("ReplicatedStorage")
local template = ReplicatedStorage:WaitForChild("PlaceableModels"):WaitForChild("GardenBed")

local boxCFrame, boxSize = template:GetBoundingBox()
local boxToPivot = boxCFrame:ToObjectSpace(template:GetPivot())

local PlacementRules = {}

function PlacementRules.getPlacement(plot, position, preview)
    if typeof(position) ~= "Vector3" then
        return nil, false, "Invalid position"
    end

    for _, value in ipairs({position.X, position.Y, position.Z}) do
        if value ~= value or math.abs(value) > 1000000 then
            return nil, false, "Invalid position"
        end
    end

    local ground = plot:FindFirstChild("Ground")
    if not ground or not ground:IsA("BasePart") then
        return nil, false, "Ground is missing"
    end

    local point = ground.CFrame:PointToObjectSpace(position)

    local targetBox = ground.CFrame * CFrame.new(
        point.X,
        ground.Size.Y / 2 + boxSize.Y / 2,
        point.Z
    )

    local targetPivot = targetBox * boxToPivot

    if math.abs(point.X) + boxSize.X / 2 > ground.Size.X / 2
        or math.abs(point.Z) + boxSize.Z / 2 > ground.Size.Z / 2 then
        return targetPivot, false, "Keep the whole bed inside your plot"
    end

    local ignored = {ground}

    if preview then
        table.insert(ignored, preview)
    end

    local spawnPoint = plot:FindFirstChild("SpawnPoint")
    if spawnPoint then
        table.insert(ignored, spawnPoint)
    end

    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignored

    local placedObjects = plot:FindFirstChild("PlacedObjects")

    local querySize = Vector3.new(
        math.max(boxSize.X - 0.02, 0.001),
        math.max(boxSize.Y - 0.02, 0.001),
        math.max(boxSize.Z - 0.02, 0.001)
    )

    local overlappingParts = workspace:GetPartBoundsInBox(
        targetBox,
        querySize,
        params
    )

    for _, part in ipairs(overlappingParts) do
        if part.CanCollide
            or (placedObjects and part:IsDescendantOf(placedObjects)) then
            return targetPivot, false, "This space is occupied"
        end
    end

    return targetPivot, true, ""
end

return PlacementRules