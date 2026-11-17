local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local plots = workspace:WaitForChild("Plots")
local templates = ReplicatedStorage:WaitForChild("PlaceableModels")
local recipes = require(ReplicatedStorage.Configs.ProductionRecipes)
local Bakery = require(script.Parent:WaitForChild("BakeryVisual"))
local stations = {}
local TWO_PI = math.pi * 2
local woodColors = {
    SawOak = {Bark = Color3.fromRGB(119, 73, 38), Cut = Color3.fromRGB(207, 158, 89)},
    SawBirch = {Bark = Color3.fromRGB(231, 224, 202), Cut = Color3.fromRGB(228, 199, 145)},
}

local function createSawVisual(station)
    local folder = Instance.new("Folder")
    folder.Name = "LocalSawVisual"
    folder.Parent = station
    local function part(name, size, shape)
        local object = Instance.new("Part")
        object.Name = name
        object.Size = size
        object.Shape = shape or Enum.PartType.Block
        object.Anchored = true
        object.CanCollide = false
        object.CanTouch = false
        object.CanQuery = false
        object.CastShadow = false
        object.Material = Enum.Material.SmoothPlastic
        object.Transparency = 1
        object.Parent = folder
        return object
    end
    local visual = {
        Folder = folder,
        Log = part("Log", Vector3.new(2.2, 0.65, 0.65), Enum.PartType.Cylinder),
        Ends = {}, Boards = {}, Chips = {}, Marks = {},
    }
    for i = 1, 2 do visual.Ends[i] = part("CutEnd", Vector3.new(0.025, 0.59, 0.59), Enum.PartType.Cylinder) end
    for i = 1, 3 do
        visual.Boards[i] = part("Board", Vector3.new(2.2, 0.17, 0.22))
        visual.Marks[i] = part("BarkMark", Vector3.new(0.22, 0.025, 0.18))
        visual.Marks[i].Color = Color3.fromRGB(83, 76, 64)
    end
    for i = 1, 5 do visual.Chips[i] = part("WoodChip", Vector3.new(0.09, 0.06, 0.14)) end
    return visual
end

local function updateSaw(station, state)
    local started = station:GetAttribute("ProductionStartedAt")
    local duration = station:GetAttribute("ProductionDuration")
    local recipe = recipes[station:GetAttribute("ActiveRecipe")]
    local colors = recipe and woodColors[recipe.Visual]
    local working = station:GetAttribute("Busy") and started and duration and duration > 0 and colors
    local visual = state.Saw
    if not working then
        if visual and visual.Visible then
            for _, part in ipairs(visual.Folder:GetChildren()) do part.Transparency = 1 end
            visual.Visible = false
        end
        return
    end
    if not visual then visual = createSawVisual(station); state.Saw = visual end
    visual.Visible = true
    local progress = math.clamp((workspace:GetServerTimeNow() - started) / duration, 0, 1)
    local frame = state.Root.CFrame
    local lift = math.clamp(progress / 0.2, 0, 1)
    lift = lift * lift * (3 - 2 * lift)
    local feed = math.clamp((progress - 0.2) / 0.65, 0, 1)
    local x = -3 + feed * 5.8
    local y = 0.7 + lift * 1.65
    local split = math.clamp((progress - 0.53) / 0.15, 0, 1)
    local fade = math.clamp((progress - 0.92) / 0.08, 0, 1)
    visual.Log.Color = colors.Bark
    visual.Log.CFrame = frame * CFrame.new(x, y, 0)
    visual.Log.Transparency = split
    for i, part in ipairs(visual.Ends) do
        part.Color = colors.Cut
        part.CFrame = frame * CFrame.new(x + (i == 1 and -1.105 or 1.105), y, 0)
        part.Transparency = split
    end
    for i, part in ipairs(visual.Marks) do
        part.CFrame = frame * CFrame.new(x + (i - 2) * 0.6, y + 0.323, 0)
        part.Transparency = recipe.Visual == "SawBirch" and split or 1
    end
    for i, part in ipairs(visual.Boards) do
        part.Color = colors.Cut
        part.CFrame = frame * CFrame.new(x, y - 0.08 + math.sin(split * math.pi) * 0.1, (i - 2) * (0.2 + split * 0.2))
        part.Transparency = math.max(1 - split, fade)
    end
    for i, part in ipairs(visual.Chips) do
        local t = math.clamp((progress - 0.5 - i * 0.025) / 0.22, 0, 1)
        part.Color = colors.Cut
        part.CFrame = frame * CFrame.new(t * (i % 2 == 0 and 1 or -1), 2.3 + 1.6 * t - 2 * t * t, t * (0.5 + i * 0.12)) * CFrame.Angles(t * i, t * 3, 0)
        part.Transparency = (t <= 0 or t >= 1) and 1 or t
    end
end

local function bindStation(station)
    if stations[station] or not station:IsA("Model") then return end
    local visual = station:GetAttribute("ProductionVisual")
    if visual == "KitchenTable" or visual == "KitchenOven" then
        local state = Bakery.new(station)
        if state then stations[station] = {Bakery = state} end
        return
    end
    if visual ~= "HandMill" and visual ~= "Sawmill" then return end
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
        Root = root, Rotor = rotor, Visual = visual,
        RootToAxis = referenceRoot.CFrame:ToObjectSpace(referenceAxis.CFrame),
        AxisToRotor = referenceAxis.CFrame:ToObjectSpace(referenceRotor:GetPivot()),
    }
end

local function scanStations()
    for _, plot in ipairs(plots:GetChildren()) do
        local objects = plot:FindFirstChild("PlacedObjects")
        if objects then for _, station in ipairs(objects:GetChildren()) do bindStation(station) end end
        local house = plot:FindFirstChild("StarterHouse")
        local workspaces = house and house:FindFirstChild("Stations")
        if workspaces then for _, station in ipairs(workspaces:GetChildren()) do bindStation(station) end end
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
        if state.Bakery then
            if not station:IsDescendantOf(plots) then
                state.Bakery:Destroy()
                stations[station] = nil
            else state.Bakery:ResetPose() end
            continue
        end
        local objects = station.Parent
        if not objects or objects.Name ~= "PlacedObjects" or not station:IsDescendantOf(plots)
            or not state.Root.Parent or not state.Rotor.Parent then
            if state.Saw then state.Saw.Folder:Destroy() end
            stations[station] = nil
        else
            if state.Visual == "Sawmill" then updateSaw(station, state) end
            local angle = getAngle(station)
            local rotation = state.Visual == "Sawmill" and CFrame.Angles(0, 0, angle) or CFrame.Angles(0, angle, 0)
            local frame = state.Root.CFrame * state.RootToAxis * rotation * state.AxisToRotor
            if frame ~= state.LastFrame then
                state.Rotor:PivotTo(frame)
                state.LastFrame = frame
            end
        end
    end
end)

RunService.PreSimulation:Connect(function(dt)
    local now = workspace:GetServerTimeNow()
    for _, state in pairs(stations) do
        if state.Bakery then state.Bakery:Update(now, dt) end
    end
end)

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
    elapsed = elapsed + dt
    if elapsed >= 0.5 then elapsed = 0; scanStations() end
end)
scanStations()
