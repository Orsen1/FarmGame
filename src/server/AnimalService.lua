local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InventoryService = require(script.Parent.InventoryService)
local Config = require(ReplicatedStorage.Configs.AnimalConfig)
local Motion = require(ReplicatedStorage.Animals.AnimalMotion)
local plots = workspace:WaitForChild("Plots")
local homes = {}
local AnimalService = {}

local function getConfig(object)
    return Config.Coops[object:GetAttribute("ItemName") or object.Name]
end

local function animalFolder(object)
    local folder = object:FindFirstChild("Animals")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "Animals"
        folder.Parent = object
    end
    return folder
end

local function setState(record, activity, position, target, duration, yaw, now)
    record.From, record.To = position, target
    record.YawFrom = Motion.yaw(record, now)
    record.YawTo = yaw
    record.Activity, record.StartedAt, record.Duration = activity, now, duration
    for _, name in ipairs({"From", "To", "YawFrom", "YawTo", "Activity", "StartedAt", "Duration", "Phase"}) do
        record.Folder:SetAttribute(name, record[name])
    end
    record.Folder:SetAttribute("Revision", (record.Folder:GetAttribute("Revision") or 0) + 1)
end

local function groundAt(home, point)
    local world = home.Object:GetPivot():PointToWorldSpace(point)
    local plot = home.Object.Parent and home.Object.Parent.Parent
    if not plot then return end
    local radius = home.Settings.Radius
    local function floorPosition(floor)
        local localPoint = floor.CFrame:PointToObjectSpace(world)
        if math.abs(localPoint.X) + radius > floor.Size.X / 2 or
            math.abs(localPoint.Z) + radius > floor.Size.Z / 2 then return end
        local top = Vector3.new(world.X, floor.Position.Y + floor.Size.Y / 2, world.Z)
        return home.Object:GetPivot():PointToObjectSpace(top)
    end
    local ground = plot:FindFirstChild("Ground")
    local position = ground and floorPosition(ground)
    if position then return position end
    local sections = plot:FindFirstChild("Sections")
    if sections then
        for _, section in ipairs(sections:GetChildren()) do
            local floor = section:FindFirstChild("Ground")
            if floor and section:GetAttribute("Unlocked") == true then
                position = floorPosition(floor)
                if position then return position end
            end
        end
    end
end

local function obstacles(home)
    local result = {}
    for _, object in ipairs(home.Object.Parent:GetChildren()) do
        if object ~= home.Object and object:IsA("Model") then
            local frame, size = object:GetBoundingBox()
            table.insert(result, {Frame = frame, Size = size})
        end
    end
    return result
end

local function clearPoint(home, point, boxes)
    local position = groundAt(home, point)
    if not position then return end
    local world = home.Object:GetPivot():PointToWorldSpace(position)
    for _, box in ipairs(boxes) do
        local localPoint = box.Frame:PointToObjectSpace(world)
        if math.abs(localPoint.X) < box.Size.X / 2 + home.Settings.Radius and
            math.abs(localPoint.Z) < box.Size.Z / 2 + home.Settings.Radius then return end
    end
    return position
end

local function clearPath(home, from, target, boxes)
    local steps = math.max(1, math.ceil((target - from).Magnitude))
    for index = 0, steps do
        local point = clearPoint(home, from:Lerp(target, index / steps), boxes)
        if not point or math.abs(point.Y - from.Y) > 0.4 then return false end
    end
    return true
end

local function pointDistanceSquared(point, from, target)
    local delta = target - from
    local length = delta:Dot(delta)
    local fraction = length > 0.000001 and math.clamp((point - from):Dot(delta) / length, 0, 1) or 0
    local offset = point - from - delta * fraction
    return offset:Dot(offset)
end

local function cross(a, b)
    return a.X * b.Y - a.Y * b.X
end

local function pathsDistanceSquared(a, b, c, d)
    local ab, cd = b - a, d - c
    local denominator = cross(ab, cd)
    if math.abs(denominator) > 0.000001 then
        local t = cross(c - a, cd) / denominator
        local u = cross(c - a, ab) / denominator
        if t >= 0 and t <= 1 and u >= 0 and u <= 1 then return 0 end
    end
    return math.min(pointDistanceSquared(a, c, d), pointDistanceSquared(b, c, d),
        pointDistanceSquared(c, a, b), pointDistanceSquared(d, a, b))
end

local function separated(home, record, from, target, now)
    local frame = home.Object:GetPivot()
    local worldFrom, worldTo = frame:PointToWorldSpace(from), frame:PointToWorldSpace(target)
    local a, b = Vector2.new(worldFrom.X, worldFrom.Z), Vector2.new(worldTo.X, worldTo.Z)
    for _, otherHome in pairs(homes) do
        local otherFrame = otherHome.Object:GetPivot()
        if (frame.Position - otherFrame.Position).Magnitude <= home.Range + otherHome.Range then
            local distance = home.Settings.Radius + otherHome.Settings.Radius + Config.SeparationGap
            for _, other in ipairs(otherHome.Animals) do
                if other ~= record and other.Activity ~= "Waiting" then
                    local position = otherFrame:PointToWorldSpace(Motion.position(other, now))
                    local finish = otherFrame:PointToWorldSpace(other.Activity == "Walk" and other.To or other.From)
                    local c, d = Vector2.new(position.X, position.Z), Vector2.new(finish.X, finish.Z)
                    if pathsDistanceSquared(a, b, c, d) < distance * distance then return false end
                end
            end
        end
    end
    return true
end

local function findPoint(home, record, from, now)
    local boxes = obstacles(home)
    local area = home.Config
    for _ = 1, from and home.Settings.TargetAttempts or home.Config.SpawnAttempts do
        local point
        if from then
            local angle = home.Random:NextNumber(0, math.pi * 2)
            local range = home.Settings.WalkDistance
            local distance = home.Random:NextNumber(range.X, range.Y)
            point = Vector3.new(math.clamp(from.X + math.cos(angle) * distance, area.AreaMin.X, area.AreaMax.X), 0,
                math.clamp(from.Z + math.sin(angle) * distance, area.AreaMin.Y, area.AreaMax.Y))
        else
            point = Vector3.new(home.Random:NextNumber(area.AreaMin.X, area.AreaMax.X), 0,
                home.Random:NextNumber(area.AreaMin.Y, area.AreaMax.Y))
        end
        point = clearPoint(home, point, boxes)
        if point then
            local duration = from and (point - from).Magnitude / home.Settings.WalkSpeed or 12
            if duration >= 0.6 and (not from or clearPath(home, from, point, boxes)) and
                separated(home, record, from or point, point, now) then
                return point, duration
            end
        end
    end
end

local function newRecord(home, folder, now)
    local record = {Folder = folder, From = Vector3.zero, To = Vector3.zero, StartedAt = now,
        Duration = 0, YawFrom = 0, YawTo = 0, Activity = "Waiting", Phase = home.Random:NextNumber(0, math.pi * 2)}
    local point = findPoint(home, record, nil, now)
    setState(record, point and "Idle" or "Waiting", point or Vector3.zero, point or Vector3.zero, 2, 0, now)
    table.insert(home.Animals, record)
    return record
end

function AnimalService.Bind(object)
    if homes[object] or not object:IsA("Model") or not object:IsDescendantOf(plots) then return end
    local config = getConfig(object)
    if not config then return end
    local home = {Object = object, Config = config, Settings = Config.Animals[config.ItemName],
        Random = Random.new(), Animals = {}}
    home.Range = Vector2.new(math.max(math.abs(config.AreaMin.X), math.abs(config.AreaMax.X)),
        math.max(math.abs(config.AreaMin.Y), math.abs(config.AreaMax.Y))).Magnitude + home.Settings.Radius
    homes[object] = home
    local folder = animalFolder(object)
    local now = workspace:GetServerTimeNow()
    for _, animal in ipairs(folder:GetChildren()) do newRecord(home, animal, now) end
    object:SetAttribute("AnimalCount", #home.Animals)
    home.Connection = object.Destroying:Connect(function()
        home.Connection:Disconnect()
        homes[object] = nil
    end)
end

function AnimalService.Step(now)
    for object, home in pairs(homes) do
        if not object:IsDescendantOf(plots) then
            home.Connection:Disconnect()
            homes[object] = nil
        else
            for _, record in ipairs(home.Animals) do
                if now >= record.StartedAt + record.Duration then
                    local position = Motion.position(record, now)
                    local yaw = Motion.yaw(record, now)
                    local target, duration
                    if record.Activity == "Waiting" then
                        target = findPoint(home, record, nil, now)
                        position = target or Vector3.zero
                    elseif home.Random:NextNumber() < home.Settings.WalkChance then
                        target, duration = findPoint(home, record, position, now)
                    end
                    if target and duration then
                        local delta = target - position
                        setState(record, "Walk", position, target, duration, math.atan2(-delta.X, -delta.Z), now)
                    else
                        local activity = home.Random:NextNumber() < home.Settings.SitChance and "Sit" or "Look"
                        if record.Activity == "Waiting" and not target then activity = "Waiting" end
                        local range = activity == "Sit" and home.Settings.SitTime or home.Settings.LookTime
                        setState(record, activity, position, position, home.Random:NextNumber(range.X, range.Y),
                            yaw + home.Random:NextNumber(-home.Settings.TurnAngle, home.Settings.TurnAngle), now)
                    end
                end
            end
        end
    end
end

function AnimalService.Add(player, object)
    local config = getConfig(object)
    local plot = plots:FindFirstChild(player:GetAttribute("PlotName") or "")
    if not config or player:GetAttribute("DataLoaded") ~= true or not plot or
        object.Parent ~= plot:FindFirstChild("PlacedObjects") or plot:GetAttribute("OwnerUserId") ~= player.UserId or
        object:GetAttribute("OwnerUserId") ~= player.UserId then return false, "This is not your coop." end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local prompt = object:FindFirstChild("ActionPrompt", true)
    if not root or not prompt or (root.Position - prompt.Parent.WorldPosition).Magnitude > prompt.MaxActivationDistance then
        return false, "Move closer to the coop."
    end
    local slot = player.Inventory:FindFirstChild("Slot" .. (player:GetAttribute("SelectedSlot") or 1))
    if not slot or slot.ItemName.Value ~= config.ItemName or slot.Amount.Value < 1 then
        return false, "Select a chicken in your inventory."
    end
    AnimalService.Bind(object)
    local home = homes[object]
    if #home.Animals >= config.Capacity then return false, string.format("Coop full: %d / %d chickens.", config.Capacity, config.Capacity) end
    local now = workspace:GetServerTimeNow()
    local point = findPoint(home, nil, nil, now)
    if not point then return false, "Clear some space in front of the coop." end
    local removed, reason = InventoryService.ExchangeItems(player, {[config.ItemName] = 1}, {})
    if not removed then return false, reason end
    local folder = Instance.new("Folder")
    folder.Name = "Animal" .. (#home.Animals + 1)
    folder:SetAttribute("ItemName", config.ItemName)
    local record = {Folder = folder, From = point, To = point, StartedAt = now, Duration = 0,
        YawFrom = 0, YawTo = 0, Activity = "Idle", Phase = home.Random:NextNumber(0, math.pi * 2)}
    setState(record, "Idle", point, point, home.Random:NextNumber(home.Settings.IdleTime.X, home.Settings.IdleTime.Y), 0, now)
    table.insert(home.Animals, record)
    folder.Parent = animalFolder(object)
    object:SetAttribute("AnimalCount", #home.Animals)
    return true, "Chicken added."
end

function AnimalService.getData(object)
    local config = getConfig(object)
    if not config then return nil, "Unknown animal home." end
    local result = {}
    local folder = object:FindFirstChild("Animals")
    for _, animal in ipairs(folder and folder:GetChildren() or {}) do
        if not animal:IsA("Folder") or animal:GetAttribute("ItemName") ~= config.ItemName then
            return nil, "Unknown animal in coop."
        end
        table.insert(result, {ItemName = config.ItemName})
    end
    if #result > config.Capacity then return nil, "Too many animals in coop." end
    return result
end

function AnimalService.loadData(object, data)
    local config = getConfig(object)
    if not config then return false, "Unknown animal home." end
    if data == nil then data = {} end
    if typeof(data) ~= "table" or #data > config.Capacity then return false, "Invalid saved animals." end
    for key, animal in pairs(data) do
        if typeof(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > #data or
            typeof(animal) ~= "table" or animal.ItemName ~= config.ItemName then return false, "Invalid saved animal." end
    end
    local folder = animalFolder(object)
    if #folder:GetChildren() > 0 then return false, "Animals are already loaded." end
    for index, animal in ipairs(data) do
        local entry = Instance.new("Folder")
        entry.Name = "Animal" .. index
        entry:SetAttribute("ItemName", animal.ItemName)
        if homes[object] then newRecord(homes[object], entry, workspace:GetServerTimeNow()) end
        entry.Parent = folder
    end
    object:SetAttribute("AnimalCount", #data)
    return true
end

function AnimalService.Release(player, object)
    local animals, reason = AnimalService.getData(object)
    if not animals then return false, reason end
    local outputs = {}
    for _, animal in ipairs(animals) do outputs[animal.ItemName] = (outputs[animal.ItemName] or 0) + 1 end
    local added = InventoryService.ExchangeItems(player, {}, outputs)
    if not added then return false, "Free an inventory slot for the chickens first." end
    local home = homes[object]
    if home then home.Animals = {} end
    local folder = object:FindFirstChild("Animals")
    if folder then folder:Destroy() end
    object:SetAttribute("AnimalCount", 0)
    return true
end

return AnimalService
