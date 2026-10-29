-- Вращение видит каждый игрок. Камера и персонаж здесь не изменяются.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local plots = workspace:WaitForChild("Plots")
local templates = ReplicatedStorage:WaitForChild("PlaceableModels")
local stations = {}
local TWO_PI = math.pi * 2

local function bindStation(station)
    if stations[station] or not station:IsA("Model")
        or station:GetAttribute("ProductionVisual") ~= "HandMill" then return end
    local root = station:FindFirstChild("PlacementRoot")
    local rotor = station:FindFirstChild("Rotor")
    local axis = rotor and rotor:FindFirstChild("RotorPivot")
    if not root or not rotor or not axis then return end
    local template = templates:FindFirstChild(station:GetAttribute("ItemName") or station.Name)
    local referenceRoot = template and template:FindFirstChild("PlacementRoot")
    local referenceRotor = template and template:FindFirstChild("Rotor")
    local referenceAxis = referenceRotor and referenceRotor:FindFirstChild("RotorPivot")
    if not referenceRoot or not referenceAxis then
        referenceRoot, referenceRotor, referenceAxis = root, rotor, axis
    end
    stations[station] = {
        Root = root, Rotor = rotor,
        RootToAxis = referenceRoot.CFrame:ToObjectSpace(referenceAxis.CFrame),
        AxisToRotor = referenceAxis.CFrame:ToObjectSpace(referenceRotor:GetPivot()),
    }
end

local function scanStations()
    for _, plot in ipairs(plots:GetChildren()) do
        local objects = plot:FindFirstChild("PlacedObjects")
        if objects then for _, station in ipairs(objects:GetChildren()) do bindStation(station) end end
    end
end

local function getAngle(station)
    local angle = station:GetAttribute("ProductionAngle") or 0
    if station:GetAttribute("Busy") then
        local start = station:GetAttribute("ProductionStartedAt")
        local duration = station:GetAttribute("ProductionDuration")
        local cycle = station:GetAttribute("ProductionCycleSeconds") or 4
        if start and duration and cycle > 0 then
            angle = angle + math.clamp(workspace:GetServerTimeNow() - start, 0, duration) / cycle * TWO_PI
        end
    end
    return angle % TWO_PI
end

RunService.PreAnimation:Connect(function()
    for station, state in pairs(stations) do
        local objects = station.Parent
        if not objects or objects.Name ~= "PlacedObjects" or not station:IsDescendantOf(plots)
            or not state.Root.Parent or not state.Rotor.Parent then
            stations[station] = nil
        else
            local frame = state.Root.CFrame * state.RootToAxis
                * CFrame.Angles(0, getAngle(station), 0) * state.AxisToRotor
            if frame ~= state.LastFrame then
                state.Rotor:PivotTo(frame)
                state.LastFrame = frame
            end
        end
    end
end)

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
    elapsed = elapsed + dt
    if elapsed >= 0.5 then elapsed = 0; scanStations() end
end)
scanStations()
