local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InventoryService = require(script.Parent.InventoryService)
local AnimalCare = require(script.Parent.AnimalCare)
local Config = require(ReplicatedStorage.Configs.AnimalConfig)
local Motion = require(ReplicatedStorage.Animals.AnimalMotion)
local plots = workspace:WaitForChild("Plots")
local homes = {}
local obstacleCache
local AnimalService = {}
local milking = {}
local milkEvent = ReplicatedStorage.RemoteEvents:WaitForChild("MilkingEvent")
local Players = game:GetService("Players")

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
    local objects = home.Object.Parent
    if obstacleCache and obstacleCache[objects] then return obstacleCache[objects] end
    local result = {}
    for _, object in ipairs(objects:GetChildren()) do
        if object:IsA("Model") then
            local frame, size = object:GetBoundingBox()
            table.insert(result, {Object = object, Frame = frame, Size = size})
        end
    end
    if obstacleCache then obstacleCache[objects] = result end
    return result
end

local function clearPoint(home, point, boxes)
    local position = groundAt(home, point)
    if not position then return end
    local world = home.Object:GetPivot():PointToWorldSpace(position)
    for _, box in ipairs(boxes) do
        local localPoint = box.Frame:PointToObjectSpace(world)
        if box.Object ~= home.Object and math.abs(localPoint.X) < box.Size.X / 2 + home.Settings.Radius and
            math.abs(localPoint.Z) < box.Size.Z / 2 + home.Settings.Radius then return end
    end
    return position
end

local function inDoorLane(home, point)
    return math.abs(point.X) < home.Config.DoorLaneWidth and
        point.Z < home.Config.AreaMin.Y + home.Config.DoorLaneLength
end

local function clearPath(home, from, target, boxes)
    local steps = math.max(1, math.ceil((target - from).Magnitude))
    local leavingLane = inDoorLane(home, from)
    for index = 0, steps do
        local point = clearPoint(home, from:Lerp(target, index / steps), boxes)
        if not point or math.abs(point.Y - from.Y) > 0.4 then return false end
        if inDoorLane(home, point) then
            if not leavingLane then return false end
        else
            leavingLane = false
        end
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
            for _, other in ipairs(otherHome.Animals) do
                if other ~= record and other.Activity ~= "Waiting" then
                    local radius = record and (record.Inside or record.Route) and home.Config.IndoorRadius or home.Settings.Radius
                    local otherRadius = (other.Inside or other.Route) and otherHome.Config.IndoorRadius or otherHome.Settings.Radius
                    local distance = radius + otherRadius + Config.SeparationGap
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
    if not from and area.SpawnPoints then
        for _, spawn in ipairs(area.SpawnPoints) do
            local point = clearPoint(home, spawn, boxes)
            if point and separated(home, record, point, point, now) then return point end
        end
    end
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
        if point and not inDoorLane(home, point) then
            local duration = from and (point - from).Magnitude / home.Settings.WalkSpeed or 12
            if duration >= 0.6 and (not from or clearPath(home, from, point, boxes)) and
                separated(home, record, from or point, point, now) then
                return point, duration
            end
        end
    end
end

local function eggValue(object)
    local output = object:FindFirstChild("OutputInventory")
    local config = getConfig(object)
    return output and config and config.EggItem and output:FindFirstChild(config.EggItem)
end

local function setTime(folder, name, value)
    local previous = folder:GetAttribute(name)
    if value == nil or previous == nil or math.abs(previous - value) > 0.5 then folder:SetAttribute(name, value) end
end

local function publishCare(home, now)
    local hungry, working = 0, 0
    local producing = home.Config.EggItem ~= nil or home.Config.Milking ~= nil
    local full = home.Config.EggItem ~= nil and home.Production.Eggs >= home.Config.EggCapacity
    for _, record in ipairs(home.Animals) do
        local state = record.Care
        local fed = state.FoodRemaining > 0
        if not fed then hungry += 1 end
        local ready = state.MilkReady == true
        if producing and fed and not full and not ready then working += 1 end
        record.Folder:SetAttribute("Hungry", not fed)
        record.Folder:SetAttribute("WaitingForSpace", full)
        record.Folder:SetAttribute("EggDuration", AnimalCare.workDuration(home.Config))
        record.Folder:SetAttribute("MilkReady", ready)
        if not fed or full or ready then record.Folder:SetAttribute("WorkRemaining", state.WorkRemaining) end
        setTime(record.Folder, "EggReadyAt", producing and fed and not full and not ready and now + state.WorkRemaining or nil)
        setTime(record.Folder, "FedUntil", fed and now + state.FoodRemaining or nil)
    end
    local egg = eggValue(home.Object)
    if egg then egg.Value = home.Production.Eggs end
    home.Object:SetAttribute("FeedStock", home.Production.FeedStock)
    home.Object:SetAttribute("HungryCount", hungry)
    home.Object:SetAttribute("PendingEggs", working)
end

local function refreshCare(home, now)
    local egg = eggValue(home.Object)
    home.Production.Eggs = egg and egg.Value or 0
    AnimalCare.advance(home.Production, home.Config, now - home.CareUpdatedAt)
    home.CareUpdatedAt = now
    publishCare(home, now)
end

local function route(home, record, points, destination)
    record.Route, record.RouteIndex, record.Destination = points, 1, destination
end

local function routeDetour(home, record, position, target, now, waypoints)
    local points = {position, target}
    local boxes = obstacles(home)
    for _, point in ipairs(waypoints) do
        if clearPoint(home, point, boxes) then table.insert(points, point) end
    end
    local distances, previous, visited = {[1] = 0}, {}, {}
    for _ = 1, #points do
        local closest, distance = nil, math.huge
        for index, value in pairs(distances) do
            if not visited[index] and value < distance then closest, distance = index, value end
        end
        if not closest or closest == 2 then break end
        visited[closest] = true
        for index = 2, #points do
            if not visited[index] and separated(home, record, points[closest], points[index], now) then
                local candidate = distance + (points[index] - points[closest]).Magnitude
                if candidate < (distances[index] or math.huge) then
                    distances[index], previous[index] = candidate, closest
                end
            end
        end
    end
    if not previous[2] then return end
    local index = 2
    while previous[index] ~= 1 do index = previous[index] end
    return points[index]
end

local function advanceRoute(home, record, position, now)
    local target = record.Route[record.RouteIndex]
    if target then
        local clear = separated(home, record, position, target, now)
        local boxes = obstacles(home)
        local steps = math.max(1, math.ceil((target - position).Magnitude))
        for index = 0, steps do
            if not clearPoint(home, position:Lerp(target, index / steps), boxes) then clear = false;break end
        end
        if clear then
            local delta = target - position
            record.RouteIndex += 1
            setState(record, "Walk", position, target, math.max(0.1, delta.Magnitude / home.Settings.WalkSpeed),
                math.atan2(-delta.X, -delta.Z), now)
        else
            if position.Z >= home.Config.AreaMin.Y - 1 then
                local waypoint = routeDetour(home, record, position, target, now, home.Config.OutdoorWaypoints)
                if waypoint then
                    local delta = waypoint - position
                    setState(record, "Walk", position, waypoint, math.max(0.1, delta.Magnitude / home.Settings.WalkSpeed),
                        math.atan2(-delta.X, -delta.Z), now)
                    return
                end
                local detour, duration = findPoint(home, record, position, now)
                if detour then
                    local delta = detour - position
                    setState(record, "Walk", position, detour, duration, math.atan2(-delta.X, -delta.Z), now)
                    return
                end
            end
            local low, high = home.Config.IndoorMin, home.Config.IndoorMax
            if position.X >= low.X and position.X <= high.X and position.Z >= low.Y and position.Z <= high.Y and
                target.X >= low.X and target.X <= high.X and target.Z >= low.Y and target.Z <= high.Y then
                local waypoint = routeDetour(home, record, position, target, now, home.Config.IndoorWaypoints)
                if waypoint then
                    local delta = waypoint - position
                    setState(record, "Walk", position, waypoint, math.max(0.1, delta.Magnitude / home.Settings.WalkSpeed),
                        math.atan2(-delta.X, -delta.Z), now)
                    return
                end
                for _ = 1, home.Settings.TargetAttempts do
                    local detour = Vector3.new(home.Random:NextNumber(low.X, high.X), position.Y,
                        home.Random:NextNumber(low.Y, high.Y))
                    if separated(home, record, position, detour, now) then
                        local delta = detour - position
                        setState(record, "Walk", position, detour, math.max(0.1, delta.Magnitude / home.Settings.WalkSpeed),
                            math.atan2(-delta.X, -delta.Z), now)
                        return
                    end
                end
            end
            setState(record, "Look", position, position, 0.8, record.YawTo, now)
        end
        return
    end
    local destination = record.Destination
    record.Route, record.Destination = nil, nil
    home.Gate = nil
    record.Inside = destination == "Inside"
    record.Folder:SetAttribute("Inside", record.Inside)
    if record.Inside then
        record.RestUntil = now + home.Random:NextNumber(home.Config.RestTime.X, home.Config.RestTime.Y)
    else
        record.IndoorSlot = nil
        record.NextVisitAt = now + home.Random:NextNumber(home.Config.OutsideTime.X, home.Config.OutsideTime.Y)
    end
    local yaw = record.Inside and home.Config.RestYaw or record.YawTo
    setState(record, record.Inside and "Sit" or "Look", position, position, 2, yaw, now)
end

local function enterHome(home, record, now)
    if home.Gate then return false end
    local position = Motion.position(record, now)
    local target = home.Config.Entrance[1]
    if not separated(home, record, position, target, now) and
        not routeDetour(home, record, position, target, now, home.Config.OutdoorWaypoints) then return false end
    local used = {}
    for _, other in ipairs(home.Animals) do if other.IndoorSlot then used[other.IndoorSlot] = true end end
    for index, point in ipairs(home.Config.IndoorSpots) do
        if not used[index] then
            record.IndoorSlot = index
            home.Gate = record
            local points = table.clone(home.Config.Entrance)
            table.insert(points, point)
            route(home, record, points, "Inside")
            return true
        end
    end
    return false
end

local function leaveHome(home, record, now)
    if home.Gate then return false end
    local position = Motion.position(record, now)
    local target = home.Config.Entrance[#home.Config.Entrance]
    if not separated(home, record, position, target, now) and
        not routeDetour(home, record, position, target, now, home.Config.IndoorWaypoints) then return false end
    home.Gate = record
    local points = {}
    for index = #home.Config.Entrance, 1, -1 do table.insert(points, home.Config.Entrance[index]) end
    route(home, record, points, "Outside")
    return true
end

local function nextActivity(home, record, now)
    local position = Motion.position(record, now)
    local yaw = Motion.yaw(record, now)
    if record.Route then advanceRoute(home, record, position, now);return end
    if record.Inside then
        if now >= record.RestUntil and leaveHome(home, record, now) then
            advanceRoute(home, record, position, now)
            return
        end
        local activity = home.Random:NextNumber() < 0.7 and "Sit" or "Look"
        setState(record, activity, position, position, home.Random:NextNumber(2, 4), yaw, now)
        return
    elseif record.Activity ~= "Waiting" and now >= (record.NextVisitAt or 0) and
        home.Random:NextNumber() < home.Config.VisitChance and enterHome(home, record, now) then
        advanceRoute(home, record, position, now)
        return
    end
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

local function newRecord(home, folder, now, point, duration)
    local record = {Folder = folder, From = Vector3.zero, To = Vector3.zero, StartedAt = now,
        Duration = 0, YawFrom = 0, YawTo = 0, Activity = "Waiting", Phase = home.Random:NextNumber(0, math.pi * 2),
        Care = {ItemName = home.Config.ItemName, WorkRemaining = folder:GetAttribute("WorkRemaining") or AnimalCare.workDuration(home.Config),
            FoodRemaining = folder:GetAttribute("FoodRemaining") or 0}}
    if home.Config.Milking then record.Care.MilkReady = folder:GetAttribute("MilkReady") == true end
    point = point or findPoint(home, record, nil, now)
    setState(record, point and "Idle" or "Waiting", point or Vector3.zero, point or Vector3.zero, duration or 2, 0, now)
    table.insert(home.Animals, record)
    table.insert(home.Production.Animals, record.Care)
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
    local output = object:FindFirstChild("OutputInventory")
    if not output then output = Instance.new("Folder");output.Name = "OutputInventory";output.Parent = object end
    if config.EggItem and not eggValue(object) then
        local egg = Instance.new("IntValue");egg.Name = config.EggItem;egg.Parent = output
    end
    local now = workspace:GetServerTimeNow()
    local egg = eggValue(object)
    home.Production = {Animals = {}, Eggs = egg and egg.Value or 0, FeedStock = object:GetAttribute("FeedStock") or 0}
    home.CareUpdatedAt = now
    for _, animal in ipairs(folder:GetChildren()) do newRecord(home, animal, now) end
    refreshCare(home, now)
    object:SetAttribute("AnimalCount", #home.Animals)
    home.Connection = object.Destroying:Connect(function()
        home.Connection:Disconnect()
        homes[object] = nil
    end)
end

function AnimalService.Step(now)
    AnimalService.StepMilking(now)
    obstacleCache = {}
    for object, home in pairs(homes) do
        if not object:IsDescendantOf(plots) then
            home.Connection:Disconnect()
            homes[object] = nil
        else
            refreshCare(home, now)
            for _, record in ipairs(home.Animals) do
                if not record.Milker and now >= record.StartedAt + record.Duration then
                    nextActivity(home, record, now)
                end
            end
        end
    end
    obstacleCache = nil
end

local function canUse(player, object, promptName)
    local config = getConfig(object)
    local plot = plots:FindFirstChild(player:GetAttribute("PlotName") or "")
    if not config or player:GetAttribute("DataLoaded") ~= true or not plot or
        object.Parent ~= plot:FindFirstChild("PlacedObjects") or plot:GetAttribute("OwnerUserId") ~= player.UserId or
        object:GetAttribute("OwnerUserId") ~= player.UserId then return false, "This is not your animal home." end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local prompt = object:FindFirstChild(promptName, true)
    if not root or not humanoid or humanoid.Health <= 0 or player:GetAttribute("ProductionMode") == true or
        not prompt or not prompt.Parent:IsA("Attachment") or
        not ((root.Position - prompt.Parent.WorldPosition).Magnitude <= prompt.MaxActivationDistance) then
        return false, "Move closer to the animal home."
    end
    return true
end

local function selectedBucket(player, itemName)
    local inventory = player:FindFirstChild("Inventory")
    local slot = inventory and inventory:FindFirstChild("Slot" .. (player:GetAttribute("SelectedSlot") or 1))
    return slot and slot.ItemName.Value == itemName and slot.Amount.Value > 0
end

local function milkAccess(player, home, record)
    local object = home.Object
    local plot = plots:FindFirstChild(player:GetAttribute("PlotName") or "")
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true or not plot or
        object.Parent ~= plot:FindFirstChild("PlacedObjects") or object:GetAttribute("OwnerUserId") ~= player.UserId or
        plot:GetAttribute("OwnerUserId") ~= player.UserId or not record.Folder:IsDescendantOf(object) then
        return false, "This is not your cow."
    end
    local position = object:GetPivot():PointToWorldSpace(Motion.position(record, workspace:GetServerTimeNow()))
    if not root or not humanoid or humanoid.Health <= 0 or
        (root.Position - position).Magnitude > home.Config.Milking.MaxDistance then
        return false, "Move closer to the cow."
    end
    if not selectedBucket(player, home.Config.Milking.BucketItem) then return false, "Select an empty bucket." end
    return true
end

function AnimalService.CancelMilking(player, message)
    local session = milking[player]
    if not session then return end
    milking[player] = nil
    for _, connection in ipairs(session.Connections) do connection:Disconnect() end
    local record = session.Record
    record.Milker = nil
    if record.Folder.Parent then
        record.Folder:SetAttribute("MilkerUserId", nil)
        record.Folder:SetAttribute("MilkingStartedAt", nil)
        record.Folder:SetAttribute("MilkingDuration", nil)
        record.StartedAt = workspace:GetServerTimeNow()
        record.Duration = 1
    end
    if session.Track then session.Track:Stop(0.2);session.Track:Destroy() end
    local humanoid = session.Humanoid
    if humanoid.Parent then
        for name, value in pairs(session.Movement) do humanoid[name] = value end
    end
    if session.Root.Parent then session.Root.Anchored = session.WasAnchored end
    player:SetAttribute("Milking", nil)
    player:SetAttribute("ProductionMode", nil)
    if player.Parent == Players then milkEvent:FireClient(player, "Finished", message or "Milking cancelled.") end
end

local function workFrame(home, record, now, humanoid, root)
    local frame = home.Object:GetPivot() * CFrame.new(Motion.position(record, now)) * CFrame.Angles(0, Motion.yaw(record, now), 0)
    local offset = home.Config.Milking.WorkOffset
    local height = humanoid.HipHeight + root.Size.Y / 2
    if humanoid.RigType == Enum.HumanoidRigType.R6 then height += 2 end
    local overlap = OverlapParams.new()
    overlap.FilterType = Enum.RaycastFilterType.Exclude
    overlap.FilterDescendantsInstances = {root.Parent}
    for _, side in ipairs({1, -1}) do
        local point = frame:PointToWorldSpace(Vector3.new(offset.X * side, 0, offset.Z))
        local center = point + Vector3.new(0, 2, 0)
        local clear = true
        for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(center), Vector3.new(1.6, 3, 1.6), overlap)) do
            if part.CanCollide then clear = false;break end
        end
        if clear then
            local position = point + Vector3.new(0, height, 0)
            local target = frame:PointToWorldSpace(home.Config.Milking.HandOffset)
            return CFrame.lookAt(position, Vector3.new(target.X, position.Y, target.Z)), frame, side
        end
    end
end

function AnimalService.StartMilking(player, folder)
    if milking[player] or player:GetAttribute("ProductionMode") == true or player:GetAttribute("StorageOpen") == true or
        player:GetAttribute("FeederOpen") == true then return false, "Finish your current action first." end
    if typeof(folder) ~= "Instance" or not folder:IsA("Folder") or not folder.Parent or folder.Parent.Name ~= "Animals" then
        return false, "Unknown cow."
    end
    local home = homes[folder.Parent.Parent]
    if not home or not home.Config.Milking then return false, "This animal cannot be milked." end
    local record
    for _, animal in ipairs(home.Animals) do if animal.Folder == folder then record = animal;break end end
    if not record then return false, "Unknown cow." end
    local allowed, reason = milkAccess(player, home, record)
    if not allowed then return false, reason end
    local now = workspace:GetServerTimeNow()
    refreshCare(home, now)
    if not record.Care.MilkReady then return false, "Milk is not ready yet." end
    if record.Milker then return false, "This cow is being milked." end
    if record.Route or record.Activity == "Waiting" then return false, "Let the cow finish moving through the gate." end
    local settings = home.Config.Milking
    if not InventoryService.CanExchangeItems(player, {[settings.BucketItem] = 1}, {[settings.OutputItem] = 1}) then
        return false, "Make room for a milk bucket."
    end
    local character = player.Character
    local humanoid, root = character:FindFirstChildOfClass("Humanoid"), character.HumanoidRootPart
    if humanoid.Sit then return false, "Stand up first." end
    local work, cow, side = workFrame(home, record, now, humanoid, root)
    if not work then return false, "Wait until there is room beside the cow." end
    local session = {Home = home, Record = record, Character = character, Humanoid = humanoid, Root = root,
        StartedAt = now, Duration = settings.Duration, WasAnchored = root.Anchored, Connections = {},
        Movement = {WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower,
            JumpHeight = humanoid.JumpHeight, AutoRotate = humanoid.AutoRotate}}
    milking[player], record.Milker = session, player
    local position = Motion.position(record, now)
    setState(record, "Idle", position, position, settings.Duration + 1, Motion.yaw(record, now), now)
    root.CFrame = work
    root.Anchored = true
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight, humanoid.AutoRotate = 0, 0, 0, false
    player:SetAttribute("Milking", true)
    player:SetAttribute("ProductionMode", true)
    folder:SetAttribute("MilkingFrame", cow)
    folder:SetAttribute("MilkingSide", side)
    folder:SetAttribute("MilkingDuration", settings.Duration)
    folder:SetAttribute("MilkingStartedAt", now)
    folder:SetAttribute("MilkerUserId", player.UserId)
    if humanoid.RigType == Enum.HumanoidRigType.R15 then
        local animation = Instance.new("Animation")
        animation.AnimationId = settings.AnimationId
        local animator = humanoid:FindFirstChildOfClass("Animator")
        local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
        animation:Destroy()
        if ok then
            session.Track = track
            track.Priority = Enum.AnimationPriority.Action4
            track.Looped = false
            track:Play(0.2)
            if track.Length > 0 then track:AdjustSpeed(track.Length / settings.Duration) end
        end
    end
    table.insert(session.Connections, humanoid.Died:Connect(function() AnimalService.CancelMilking(player) end))
    table.insert(session.Connections, home.Object.Destroying:Connect(function() AnimalService.CancelMilking(player) end))
    table.insert(session.Connections, player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
        if player:GetAttribute("DataLoaded") ~= true then AnimalService.CancelMilking(player) end
    end))
    milkEvent:FireClient(player, "Started", folder, now, settings.Duration, cow)
    return true
end

function AnimalService.StepMilking(now)
    for player, session in pairs(milking) do
        local allowed, reason = milkAccess(player, session.Home, session.Record)
        if not allowed or player.Character ~= session.Character then
            AnimalService.CancelMilking(player, reason)
        elseif now >= session.StartedAt + session.Duration then
            local settings = session.Home.Config.Milking
            local success = InventoryService.ExchangeItems(player, {[settings.BucketItem] = 1}, {[settings.OutputItem] = 1})
            if success then
                session.Record.Care.MilkReady = false
                session.Record.Care.WorkRemaining = settings.ProductionDuration
                publishCare(session.Home, now)
            end
            AnimalService.CancelMilking(player, success and "Milk collected!" or "Inventory changed. Milk is still ready.")
        end
    end
end

Players.PlayerRemoving:Connect(function(player) AnimalService.CancelMilking(player) end)

function AnimalService.Add(player, object)
    local allowed, reason = canUse(player, object, "ActionPrompt")
    if not allowed then return false, reason end
    local config = getConfig(object)
    local slot = player.Inventory:FindFirstChild("Slot" .. (player:GetAttribute("SelectedSlot") or 1))
    if not slot or slot.ItemName.Value ~= config.ItemName or slot.Amount.Value < 1 then
        return false, "Select " .. config.ItemName .. " in your inventory."
    end
    AnimalService.Bind(object)
    local home = homes[object]
    if #home.Animals >= config.Capacity then return false, string.format("Home full: %d / %d.", config.Capacity, config.Capacity) end
    local now = workspace:GetServerTimeNow()
    local point = findPoint(home, nil, nil, now)
    if not point then return false, "Clear some space in the animal home." end
    local removed, reason = InventoryService.ExchangeItems(player, {[config.ItemName] = 1}, {})
    if not removed then return false, reason end
    local folder = Instance.new("Folder")
    folder.Name = "Animal" .. (#home.Animals + 1)
    folder:SetAttribute("ItemName", config.ItemName)
    newRecord(home, folder, now, point, home.Random:NextNumber(home.Settings.IdleTime.X, home.Settings.IdleTime.Y))
    folder.Parent = animalFolder(object)
    object:SetAttribute("AnimalCount", #home.Animals)
    publishCare(home, now)
    return true, config.ItemName .. " added."
end

function AnimalService.Feed(player, object)
    local allowed, reason = canUse(player, object, "FeedPrompt")
    if not allowed then return false, reason end
    AnimalService.Bind(object)
    local home = homes[object]
    local now = workspace:GetServerTimeNow()
    refreshCare(home, now)
    if home.Config.FeedCapacity > 0 then return true, "OpenFeeder" end
    local chosen
    for _, record in ipairs(home.Animals) do
        if record.Care.FoodRemaining <= 0 then
            chosen = record
            if not record.Inside and not record.Route then break end
        end
    end
    if not chosen then return false, #home.Animals == 0 and "Add an animal first." or "All animals are fed." end
    local removed = InventoryService.ExchangeItems(player, {[home.Config.FeedItem] = 1}, {})
    if not removed then return false, "You need 1 wheat." end
    chosen.Care.FoodRemaining = home.Config.FedDuration
    if not chosen.Route and not chosen.Inside and chosen.Activity ~= "Waiting" then
        local position = Motion.position(chosen, now)
        setState(chosen, "Eat", position, position, home.Config.EatingTime, chosen.YawTo, now)
    end
    publishCare(home, now)
    object:SetAttribute("FeedEffectAt", now)
    return true, "1 wheat added."
end

function AnimalService.DepositFeed(player, object, amount)
    if amount ~= 1 and amount ~= 10 and amount ~= "Max" then return false, "Invalid feed amount." end
    local allowed, reason = canUse(player, object, "FeedPrompt")
    if not allowed then return false, reason end
    AnimalService.Bind(object)
    local home = homes[object]
    if home.Config.FeedCapacity <= 0 then return false, "This feeder has no reserve." end
    local now = workspace:GetServerTimeNow()
    refreshCare(home, now)
    local available = 0
    for _, slot in ipairs(InventoryService.GetInventory(player)) do
        if slot.ItemName == home.Config.FeedItem then available += slot.Amount end
    end
    local count = math.min(available, home.Config.FeedCapacity - home.Production.FeedStock,
        amount == "Max" and home.Config.FeedCapacity or amount)
    if count <= 0 then return false, available == 0 and "You need wheat." or "Feeder full." end
    local removed = InventoryService.ExchangeItems(player, {[home.Config.FeedItem] = count}, {})
    if not removed then return false, "Inventory changed." end
    home.Production.FeedStock += count
    AnimalCare.advance(home.Production, home.Config, 0)
    publishCare(home, now)
    object:SetAttribute("FeedEffectAt", now)
    return true, string.format("Added %d wheat.", count)
end

function AnimalService.Collect(player, object)
    local allowed, reason = canUse(player, object, "EggPrompt")
    if not allowed then return false, reason end
    AnimalService.Bind(object)
    local home = homes[object]
    refreshCare(home, workspace:GetServerTimeNow())
    local egg = eggValue(object)
    if not egg or egg.Value == 0 then return false, "No eggs ready." end
    local added = InventoryService.ExchangeItems(player, {}, {[getConfig(object).EggItem] = egg.Value})
    if not added then return false, "Your inventory is full." end
    egg.Value = 0
    home.Production.Eggs = 0
    publishCare(home, workspace:GetServerTimeNow())
    return true, "Eggs collected."
end

function AnimalService.getData(object)
    local home = homes[object]
    if home then
        refreshCare(home, workspace:GetServerTimeNow())
        local result = {}
        for _, record in ipairs(home.Animals) do table.insert(result, table.clone(record.Care)) end
        return result
    end
    local config = getConfig(object)
    if not config then return nil, "Unknown animal home." end
    local animals = {}
    local folder = object:FindFirstChild("Animals")
    for _, entry in ipairs(folder and folder:GetChildren() or {}) do
        table.insert(animals, {ItemName = entry:GetAttribute("ItemName"),
            WorkRemaining = entry:GetAttribute("WorkRemaining"), FoodRemaining = entry:GetAttribute("FoodRemaining"),
            MilkReady = entry:GetAttribute("MilkReady")})
    end
    local egg = eggValue(object)
    local data, reason = AnimalCare.load(animals, egg and egg.Value or 0, object:GetAttribute("FeedStock") or 0, config)
    return data and data.Animals, reason
end

function AnimalService.loadData(object, animals, feedStock)
    local config = getConfig(object)
    if not config then return false, "Unknown animal home." end
    local output = object:FindFirstChild("OutputInventory")
    if not output or not output:IsA("Folder") then return false, "Missing saved coop output." end
    local egg = eggValue(object)
    if config.EggItem and not egg and #output:GetChildren() == 0 then
        egg = Instance.new("IntValue");egg.Name = config.EggItem;egg.Parent = output
    end
    if config.EggItem and (not egg or not egg:IsA("IntValue")) then return false, "Invalid saved eggs." end
    for _, item in ipairs(output:GetChildren()) do if item ~= egg then return false, "Unknown saved coop output." end end
    if animals == nil then animals = {} end
    if feedStock == nil then feedStock = 0 end
    local data, reason = AnimalCare.load(animals, egg and egg.Value or 0, feedStock, config)
    if not data then return false, reason end
    local folder = animalFolder(object)
    if #folder:GetChildren() > 0 then return false, "Animals are already loaded." end
    object:SetAttribute("FeedStock", data.FeedStock)
    local home = homes[object]
    if home then home.Production.FeedStock = data.FeedStock end
    for index, animal in ipairs(data.Animals) do
        local entry = Instance.new("Folder")
        entry.Name = "Animal" .. index
        for name, value in pairs(animal) do entry:SetAttribute(name, value) end
        if home then newRecord(home, entry, workspace:GetServerTimeNow()) end
        entry.Parent = folder
    end
    object:SetAttribute("AnimalCount", #data.Animals)
    if home then publishCare(home, workspace:GetServerTimeNow()) end
    return true
end

function AnimalService.Snapshot(object)
    local animals, reason = AnimalService.getData(object)
    if not animals then return nil, reason end
    local egg = eggValue(object)
    return {Animals = animals, Eggs = egg and egg.Value or 0, FeedStock = object:GetAttribute("FeedStock") or 0,
        CapturedAt = workspace:GetServerTimeNow()}
end

function AnimalService.Restore(object, snapshot, elapsed)
    if typeof(snapshot) ~= "table" then return false, "Invalid coop contents." end
    local config = getConfig(object)
    local data, reason = AnimalCare.load(snapshot.Animals, snapshot.Eggs, snapshot.FeedStock, config)
    if not data then return false, reason end
    AnimalCare.advance(data, config, elapsed or 0)
    local egg = eggValue(object)
    if egg then egg.Value = data.Eggs end
    return AnimalService.loadData(object, data.Animals, data.FeedStock)
end

function AnimalService.Copy(oldObject, newObject)
    local data, reason = AnimalService.Snapshot(oldObject)
    if not data then return false, reason end
    return AnimalService.Restore(newObject, data)
end

function AnimalService.CanUse(player, object)
    return canUse(player, object, "ActionPrompt")
end

function AnimalService.Release(player, object)
    if (object:GetAttribute("FeedStock") or 0) > 0 then return false, "Use the stored feed before removing this coop." end
    local animals, reason = AnimalService.getData(object)
    if not animals then return false, reason end
    local outputs = {}
    local config = getConfig(object)
    for _, animal in ipairs(animals) do
        outputs[animal.ItemName] = (outputs[animal.ItemName] or 0) + 1
    end
    local egg = eggValue(object)
    if egg and egg.Value > 0 then outputs[config.EggItem] = egg.Value end
    local added = InventoryService.ExchangeItems(player, {}, outputs)
    if not added then return false, "Free an inventory slot for the animals first." end
    local home = homes[object]
    if home then home.Animals = {};home.Production.Animals = {};home.Gate = nil end
    local folder = object:FindFirstChild("Animals")
    if folder then folder:Destroy() end
    if egg then egg.Value = 0 end
    object:SetAttribute("PendingEggs", 0)
    object:SetAttribute("AnimalCount", 0)
    return true
end

return AnimalService
