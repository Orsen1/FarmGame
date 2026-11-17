local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local definitions = require(ReplicatedStorage.Configs.ResourceDefinitions)
local config = definitions.Spawn
local farm = workspace:FindFirstChild("Plots") and definitions.FarmSpawn
local templates = ServerStorage:WaitForChild("ResourceTemplates")
local map = not farm and workspace:WaitForChild("ResourceMap")
local nodes = workspace:WaitForChild("ResourceNodes")
local random = Random.new()
local cellsByZone, active, families = {}, {}, {}
local started = false
local ResourceSpawnService = {}

function ResourceSpawnService.getSpawnInterval(playerCount, definition)
    return math.max(config.MinimumInterval, definition.Interval / math.max(1, math.min(playerCount, config.PlayerCap)) ^ config.GrowthExponent)
end

local farmClearance
local function buildFarmCells()
    local zones = workspace:WaitForChild("PublicZones")
    farmClearance = OverlapParams.new()
    farmClearance.FilterType = Enum.RaycastFilterType.Exclude
    farmClearance.FilterDescendantsInstances = {workspace.Terrain, workspace:WaitForChild("Baseplate"), zones}
    local configured = {}
    for _, family in pairs(farm.Families) do configured[family.Zone] = true end
    for name in pairs(configured) do
        local floor = zones:WaitForChild(name):WaitForChild("Ground")
        local cells = {}
        cellsByZone[name] = cells
        for x = farm.ZoneInset, floor.Size.X - farm.ZoneInset, farm.CellSpacing do
            for z = farm.ZoneInset, floor.Size.Z - farm.ZoneInset, farm.CellSpacing do
                local position = floor.CFrame:PointToWorldSpace(Vector3.new(x - floor.Size.X / 2,
                    floor.Size.Y / 2, z - floor.Size.Z / 2))
                table.insert(cells, {Position = position, AvailableAt = 0})
            end
        end
    end
end

local function buildCells()
    if farm then buildFarmCells();return end
    local blockers = {}
    for _, group in ipairs({map.Paths, map.Landmarks, workspace:WaitForChild("TravelPortals")}) do
        for _, part in ipairs(group:GetDescendants()) do
            if part:IsA("BasePart") and (group == map.Paths or part.CanCollide or part:GetAttribute("ResourceSpawnBlocker")) then
                table.insert(blockers, part)
            end
        end
    end
    for _, zone in ipairs(map.SpawnZones:GetChildren()) do
        local cells = cellsByZone[zone.Name] or {}
        cellsByZone[zone.Name] = cells
        for x = config.CellSpacing / 2, zone.Size.X, config.CellSpacing do
            for z = config.CellSpacing / 2, zone.Size.Z, config.CellSpacing do
                local position = zone.CFrame:PointToWorldSpace(Vector3.new(x - zone.Size.X / 2, 0, z - zone.Size.Z / 2))
                local blocked = false
                for _, part in ipairs(blockers) do
                    local offset = part.CFrame:PointToObjectSpace(position)
                    if part:GetAttribute("AllowedSpawnZone") ~= zone.Name and
                        math.abs(offset.X) < part.Size.X / 2 + 3 and math.abs(offset.Z) < part.Size.Z / 2 + 3 and
                        (part:IsDescendantOf(map.Paths) or part.Position.Y - part.Size.Y / 2 < position.Y + 5 and part.Position.Y + part.Size.Y / 2 > position.Y + 0.5) then
                        blocked = true;break
                    end
                end
                if not blocked then table.insert(cells, {Position = position, AvailableAt = 0}) end
            end
        end
    end
end

local function nearPlayer(position, positions)
    for _, other in ipairs(positions) do
        if (other - position).Magnitude < (farm and farm.PlayerClearance or config.PlayerClearance) then return true end
    end
    return false
end

local function chooseCell(zone, now, positions, nearby)
    local chosen, count = nil, 0
    for _, cell in ipairs(cellsByZone[zone] or {}) do
        if not cell.Node and cell.AvailableAt <= now and not nearPlayer(cell.Position, positions) and
            (not nearby or (cell.Position - nearby).Magnitude <= farm.RespawnRadius) and
            (not farm or #workspace:GetPartBoundsInBox(CFrame.new(cell.Position + Vector3.yAxis * 8.1),
                Vector3.new(farm.Clearance * 2, 16, farm.Clearance * 2), farmClearance) == 0) then
            count += 1
            if random:NextInteger(1, count) == 1 then chosen = cell end
        end
    end
    return chosen
end

local function spawnNode(family, now, positions, nearby, resourceId)
    local roll, variant = random:NextNumber(0, family.TotalWeight), nil
    for _, entry in ipairs(family.Definition.Variants) do
        roll -= entry.Weight
        if roll <= 0 then variant = entry;break end
    end
    if resourceId then variant = {Id = resourceId} end
    if not variant then return false end
    local zone = variant.Zone or family.Definition.Zone
    if not variant.Zone and family.Definition.AlternateZone and random:NextNumber() > config.PreferredChance then
        zone = family.Definition.AlternateZone
    end
    local cell = chooseCell(zone, now, positions, nearby)
    if not cell and nearby then cell = chooseCell(zone, now, positions) end
    if not cell and not variant.Zone then cell = chooseCell(family.Definition.Zone, now, positions) end
    if not cell then return false end
    local node = templates[variant.Id]:Clone()
    node:SetAttribute("ResourceId", variant.Id)
    node:PivotTo(CFrame.new(cell.Position) * CFrame.Angles(0, random:NextNumber(0, 2 * math.pi), 0))
    cell.Node = node
    active[node] = {Family = family, Cell = cell}
    family.Count += 1
    node.Parent = nodes
    return true
end

local function releaseCell(node)
    local entry = active[node]
    if not entry then return end
    active[node] = nil
    entry.Cell.Node = nil
    entry.Cell.AvailableAt = time() + (farm and 0.5 or config.CellCooldown)
    entry.Family.Count -= 1
end

local function playerPositions()
    local positions = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root then table.insert(positions, root.Position) end
    end
    return positions
end

function ResourceSpawnService.harvest(node)
    local entry = active[node]
    if not entry then return end
    local resourceId = node:GetAttribute("ResourceId")
    releaseCell(node)
    node:Destroy()
    if farm then spawnNode(entry.Family, time(), playerPositions(), entry.Cell.Position, resourceId) end
end

function ResourceSpawnService.update(dt, playerCount, positions)
    if playerCount < 1 then return end
    for _, family in ipairs(families) do
        if family.Count < family.Definition.Count then
            if farm then spawnNode(family, time(), positions);continue end
            family.Progress += dt / (ResourceSpawnService.getSpawnInterval(playerCount, family.Definition) * family.IntervalScale)
            if family.Progress >= 1 then
                spawnNode(family, time(), positions)
                family.Progress = 0
                family.IntervalScale = random:NextNumber(0.85, 1.15)
            end
        else family.Progress = 0 end
    end
end

function ResourceSpawnService.start()
    if started then return end
    started = true
    if not farm then
        for name, value in pairs(definitions.Environment) do game.Lighting[name] = value end
    end
    buildCells()
    for name, definition in pairs(farm and farm.Families or config.Families) do
        local totalWeight = 0
        for _, variant in ipairs(definition.Variants) do totalWeight += variant.Weight end
        local family = {Name = name, Definition = definition, TotalWeight = totalWeight, Count = 0, Progress = 0, IntervalScale = 1}
        table.insert(families, family)
        for _ = 1, definition.Count do spawnNode(family, time(), {}) end
    end
    nodes.ChildRemoved:Connect(releaseCell)
    task.spawn(function()
        local last = time()
        while true do
            task.wait(0.5)
            local players, positions = Players:GetPlayers(), playerPositions()
            local now = time()
            ResourceSpawnService.update(math.min(now - last, 1), #players, positions)
            last = now
        end
    end)
end

return ResourceSpawnService
