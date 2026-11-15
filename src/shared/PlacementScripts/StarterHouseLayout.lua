local config = require(game.ReplicatedStorage.Configs.StarterHouseConfig)
local Layout = {}

function Layout.GetPivot(plot)
    local ground = plot.Ground
    local entry = ground.CFrame:PointToObjectSpace(plot.SpawnPoint.Position)
    local sideEntry = math.abs(entry.X) > math.abs(entry.Z)
    local yaw = sideEntry and (entry.X > 0 and math.pi / 2 or -math.pi / 2) or (entry.Z > 0 and 0 or math.pi)
    local width = sideEntry and ground.Size.Z or ground.Size.X
    local depth = sideEntry and ground.Size.X or ground.Size.Z
    local frame = ground.CFrame * CFrame.new(0, ground.Size.Y / 2, 0) * CFrame.Angles(0, yaw, 0)
    return frame * CFrame.new(-width / 2 + config.BoundaryGap - config.BoundsMin.X, 0,
        -depth / 2 + config.BoundaryGap - config.BoundsMin.Z)
end

local function projectedRadius(frame, size, axis)
    return (math.abs(frame.RightVector:Dot(axis)) * size.X + math.abs(frame.UpVector:Dot(axis)) * size.Y +
        math.abs(frame.LookVector:Dot(axis)) * size.Z) / 2
end

local function overlaps(first, firstSize, second, secondSize)
    local delta = second.Position - first.Position
    for _, axis in ipairs({first.RightVector, first.LookVector, second.RightVector, second.LookVector}) do
        axis = Vector3.new(axis.X, 0, axis.Z)
        if axis.Magnitude < 0.001 then continue end
        axis = axis.Unit
        if math.abs(delta:Dot(axis)) >= projectedRadius(first, firstSize, axis) + projectedRadius(second, secondSize, axis) - 0.01 then
            return false
        end
    end
    return true
end

function Layout.Overlaps(plot, frame, size)
    local pivot = Layout.GetPivot(plot)
    for _, area in ipairs(config.Footprints) do
        if overlaps(pivot * CFrame.new(area.Center), area.Size, frame, size) then return true end
    end
    return false
end

return Layout
