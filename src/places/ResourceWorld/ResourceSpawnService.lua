local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local config = require(ReplicatedStorage.Configs.ResourceDefinitions).Spawn
local templates = ServerStorage:WaitForChild("ResourceTemplates")
local map = workspace:WaitForChild("ResourceMap")
local nodes = workspace:WaitForChild("ResourceNodes")
local random = Random.new()
local cellsByZone = {}
local active = {}
local families = {}

local ResourceSpawnService = {}

function ResourceSpawnService.getTargetCount(playerCount)
    if playerCount < 1 then
        return 0
    end
    local extraPlayers = math.min(playerCount, config.PlayerCap) - 1
    local ratio = extraPlayers / (config.ReferencePlayers - 1)
    return config.SoloCount + math.round((config.ReferenceCount - config.SoloCount) * ratio ^ config.GrowthExponent)
end

local function buildCells()
    local blockers = {}
    local portal = workspace:WaitForChild("TravelPortals")
    for _, group in ipairs({ map.Paths, map.Scenery, map.Landmarks, portal }) do
        for _, part in ipairs(group:GetDescendants()) do
            if part:IsA("BasePart") then
                table.insert(blockers, part)
            end
        end
    end

    local spacing = config.CellSpacing
    for _, zone in ipairs(map.SpawnZones:GetChildren()) do
        local cells = {}
        local size = zone.Size
        for x = spacing / 2, size.X - spacing / 2, spacing do
            for z = spacing / 2, size.Z - spacing / 2, spacing do
                local position = zone.CFrame:PointToWorldSpace(Vector3.new(
                    x - size.X / 2 + random:NextNumber(-0.7, 0.7),
                    0,
                    z - size.Z / 2 + random:NextNumber(-0.7, 0.7)
                ))
                local blocked = false
                for _, part in ipairs(blockers) do
                    local offset = part.CFrame:PointToObjectSpace(position)
                    local uprightCylinder = part:IsA("Part") and part.Shape == Enum.PartType.Cylinder
                        and math.abs(part.CFrame.RightVector.Y) > 0.9
                    local across = uprightCylinder and offset.Y or offset.X
                    local width = uprightCylinder and part.Size.Y or part.Size.X
                    if math.abs(across) < width / 2 + 3.4 and math.abs(offset.Z) < part.Size.Z / 2 + 3.4 then
                        blocked = true
                        break
                    end
                end
                if not blocked then
                    table.insert(cells, { Position = position, AvailableAt = 0 })
                end
            end
        end
        cellsByZone[zone.Name] = cells
    end
end

local function nearPlayer(position, playerPositions, distance)
    for _, playerPosition in ipairs(playerPositions) do
        if (playerPosition - position).Magnitude < distance then
            return true
        end
    end
    return false
end

local function chooseCell(zone, preferred, now, playerPositions)
    local chosen
    local count = 0
    for zoneName, cells in pairs(cellsByZone) do
        local matches = preferred and zoneName == zone or not preferred and string.sub(zoneName, 1, 6) == "Meadow"
        if matches then
            for _, cell in ipairs(cells) do
                if not cell.Node and cell.AvailableAt <= now and not nearPlayer(cell.Position, playerPositions, 9) then
                    count += 1
                    if random:NextInteger(1, count) == 1 then
                        chosen = cell
                    end
                end
            end
        end
    end
    return chosen
end

local function spawnNode(family, now, playerPositions)
    local preferred = random:NextNumber() < config.PreferredChance
    local zone = family.Definition.Zone
    local cell = chooseCell(zone, preferred, now, playerPositions) or chooseCell(zone, not preferred, now, playerPositions)
    if not cell then
        return false
    end

    local roll = random:NextNumber(0, family.TotalWeight)
    for _, variant in ipairs(family.Definition.Variants) do
        roll -= variant.Weight
        if roll <= 0 then
            local node = templates[variant.Id]:Clone()
            node:SetAttribute("ResourceId", variant.Id)
            node:PivotTo(CFrame.new(cell.Position) * CFrame.Angles(0, random:NextNumber(0, 2 * math.pi), 0))
            cell.Node = node
            active[node] = { Family = family, Cell = cell }
            family.Count += 1
            node.Parent = nodes
            return true
        end
    end
    return false
end

local function releaseCell(node)
    local entry = active[node]
    if entry then
        active[node] = nil
        entry.Cell.Node = nil
        entry.Family.Count -= 1
    end
end

function ResourceSpawnService.harvest(node)
    local entry = active[node]
    if not entry then
        return
    end
    local cooldown = config.RespawnSeconds
    local readyAt = time() + random:NextNumber(cooldown.Min, cooldown.Max)
    table.insert(entry.Family.Respawns, readyAt)
    entry.Cell.AvailableAt = readyAt + cooldown.Max
    releaseCell(node)
    node:Destroy()
end

local function update()
    local players = Players:GetPlayers()
    local target = ResourceSpawnService.getTargetCount(#players)
    local playerPositions = {}
    for _, player in ipairs(players) do
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root then
            table.insert(playerPositions, root.Position)
        end
    end

    local now = time()
    for node, entry in pairs(active) do
        if entry.Family.Count > target and not nearPlayer(entry.Cell.Position, playerPositions, 20) then
            releaseCell(node)
            node:Destroy()
        end
    end
    for _, family in ipairs(families) do
        for index = #family.Respawns, 1, -1 do
            if family.Respawns[index] <= now then
                table.remove(family.Respawns, index)
            end
        end
        local missing = target - family.Count - #family.Respawns
        for _ = 1, math.min(missing, 12) do
            if not spawnNode(family, now, playerPositions) then
                break
            end
        end
    end
end

function ResourceSpawnService.start()
    buildCells()
    for _, definition in pairs(config.Families) do
        local totalWeight = 0
        for _, variant in ipairs(definition.Variants) do
            totalWeight += variant.Weight
        end
        table.insert(families, { Definition = definition, TotalWeight = totalWeight, Count = 0, Respawns = {} })
    end
    nodes.ChildRemoved:Connect(releaseCell)
    task.spawn(function()
        while true do
            update()
            task.wait(0.6)
        end
    end)
end

return ResourceSpawnService
