local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local definitions = require(ReplicatedStorage.Configs.ResourceDefinitions)
local InventoryService = require(script.Parent.InventoryService)
local ResourceSpawnService = require(script.Parent.ResourceSpawnService)
local nodes = workspace:WaitForChild("ResourceNodes")
local targets = {}
local attempts = {}
local holdTolerance = 0.15
local triggerTimeout = 2

local function registerNode(node)
    if not node:IsA("Model") then
        return
    end
    local resourceId = node:GetAttribute("ResourceId")
    if not resourceId then
        return
    end
    local definition = definitions[resourceId]
    local point = node.PrimaryPart and node.PrimaryPart:FindFirstChild("GatherPoint")
    if not definition or not point or not point:IsA("Attachment") then
        return
    end

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "GatherPrompt"
    prompt:SetAttribute("RequiredTool", definition.Tool)
    prompt.ObjectText = definition.DisplayName
    prompt.ActionText = definition.ActionText
    prompt.HoldDuration = definition.HoldDuration
    prompt.MaxActivationDistance = definition.MaxDistance
    prompt.RequiresLineOfSight = false
    prompt.ClickablePrompt = true
    local surfaces = {}
    for _, object in ipairs(node:GetDescendants()) do
        if object:IsA("BasePart") and object.Transparency < 1 and object.CanQuery then
            table.insert(surfaces, object)
        end
    end
    targets[prompt] = { Node = node, Definition = definition, ResourceId = resourceId, Surfaces = surfaces }
    prompt.Parent = point
end

local function getContext(player, prompt)
    local target = targets[prompt]
    if not target or target.Node.Parent ~= nodes or not prompt.Enabled
        or not prompt:IsDescendantOf(target.Node)
        or player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true
        or player:GetAttribute("Teleporting") == true then
        return
    end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local tool = character and character:FindFirstChild("EquippedItem")
    if not root or not humanoid or humanoid.Health <= 0 then
        return
    end

    local requiredTool = target.Definition.Tool
    if requiredTool then
        if not tool or not tool:IsA("Tool") or tool:GetAttribute("ItemName") ~= requiredTool then
            return
        end
        local slotNumber = player:GetAttribute("SelectedSlot") or 1
        local inventory = player:FindFirstChild("Inventory")
        local slot = inventory and inventory:FindFirstChild("Slot" .. slotNumber)
        if not slot or slot.Amount.Value <= 0 or slot.ItemName.Value ~= requiredTool then
            return
        end
    end

    local point = prompt.Parent
    local distance = (root.Position - point.WorldPosition).Magnitude
    if distance ~= distance or distance > target.Definition.MaxDistance then
        return
    end
    return target, character, root, tool
end

local function getStance(target, character, root)
    local center = target.Node.PrimaryPart.Position
    local offset = center - root.Position
    local horizontal = Vector3.new(offset.X, 0, offset.Z)
    if horizontal.Magnitude < 0.1 then
        return
    end

    local forward = horizontal.Unit
    local right = forward:Cross(Vector3.yAxis)
    local resourceRay = RaycastParams.new()
    resourceRay.FilterType = Enum.RaycastFilterType.Include
    resourceRay.FilterDescendantsInstances = target.Surfaces

    local height = target.Definition.Swing == "Chop"
        and math.min(root.Position.Y + 0.74, center.Y + 1.75) or center.Y + 1.1
    local aim = Vector3.new(center.X, height, center.Z)
    local castStart = aim - forward * 9
    local castDirection = forward * 9
    if target.Definition.Swing == "Mine" then
        castStart += Vector3.yAxis * 3
        castDirection -= Vector3.yAxis * 4.2
    end
    local surface = workspace:Raycast(castStart, castDirection, resourceRay)
    if not surface then
        return
    end

    local position = surface.Position - forward * target.Definition.StandDistance - right * 0.55
    position = Vector3.new(position.X, root.Position.Y, position.Z)
    local walkRay = RaycastParams.new()
    walkRay.FilterDescendantsInstances = { character }
    walkRay.RespectCanCollide = true
    local step = position - root.Position
    if step.Magnitude > 0.05 and workspace:Raycast(root.Position, step, walkRay) then
        return
    end
    local currentGround = workspace:Raycast(root.Position, -Vector3.yAxis * 7, walkRay)
    local newGround = workspace:Raycast(position, -Vector3.yAxis * 7, walkRay)
    if not currentGround or not newGround or math.abs(currentGround.Position.Y - newGround.Position.Y) > 0.65 then
        return
    end
    position += Vector3.yAxis * (newGround.Position.Y - currentGround.Position.Y)
    return CFrame.lookAt(position, position + forward), surface.Position
end

local function stop(player)
    local attempt = attempts[player]
    if not attempt then
        return
    end
    attempts[player] = nil
    attempt.Character:SetAttribute("GatherStartedAt", nil)
    attempt.Character:SetAttribute("GatherResource", nil)
    attempt.Character:SetAttribute("GatherStrike", nil)
    attempt.Character:SetAttribute("GatherFacing", nil)
end

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, player)
    if attempts[player] then
        return
    end
    local target, character, root, tool = getContext(player, prompt)
    if not target or not target.Definition.Swing then
        return
    end
    local definition = target.Definition
    if not InventoryService.CanAddItem(player, definition.RewardItem, definition.RewardAmount) then
        return
    end
    local stance, strike = getStance(target, character, root)
    if not stance then
        return
    end

    local startedAt = workspace:GetServerTimeNow()
    attempts[player] = {
        Prompt = prompt, Character = character, Tool = tool, StartedAt = startedAt, Position = stance.Position,
    }
    root.CFrame = stance
    character:SetAttribute("GatherStrike", strike)
    character:SetAttribute("GatherFacing", stance.LookVector)
    character:SetAttribute("GatherResource", target.ResourceId)
    character:SetAttribute("GatherStartedAt", startedAt)
end)

ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt, player)
    local attempt = attempts[player]
    local target = targets[prompt]
    if not attempt or attempt.Prompt ~= prompt or not target then
        return
    end

    local elapsed = workspace:GetServerTimeNow() - attempt.StartedAt
    if elapsed < target.Definition.HoldDuration - holdTolerance then
        stop(player)
        return
    end

    attempt.Character:SetAttribute("GatherStartedAt", nil)
    task.delay(0.5, function()
        if attempts[player] == attempt then
            stop(player)
        end
    end)
end)

local function giveReward(player, target)
    local definition = target.Definition
    if InventoryService.AddItem(player, definition.RewardItem, definition.RewardAmount) then
        ResourceSpawnService.harvest(target.Node)
    end
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
    local target, character, root, tool = getContext(player, prompt)
    if target and target.Definition.HoldDuration == 0 then
        giveReward(player, target)
        return
    end
    local attempt = attempts[player]
    if not attempt or attempt.Prompt ~= prompt then
        return
    end
    local elapsed = workspace:GetServerTimeNow() - attempt.StartedAt
    stop(player)
    if not target or character ~= attempt.Character or tool ~= attempt.Tool
        or (root.Position - attempt.Position).Magnitude > 1.3
        or elapsed < target.Definition.HoldDuration - holdTolerance
        or elapsed > target.Definition.HoldDuration + triggerTimeout then
        return
    end
    giveReward(player, target)
end)

local checkTime = 0
RunService.Heartbeat:Connect(function(deltaTime)
    checkTime += deltaTime
    if checkTime < 0.1 then
        return
    end
    checkTime = 0
    local now = workspace:GetServerTimeNow()
    for player, attempt in pairs(attempts) do
        local target, character, root, tool = getContext(player, attempt.Prompt)
        if not target or character ~= attempt.Character or tool ~= attempt.Tool
            or (root.Position - attempt.Position).Magnitude > 1.3
            or now - attempt.StartedAt > target.Definition.HoldDuration + triggerTimeout then
            stop(player)
        end
    end
end)

Players.PlayerRemoving:Connect(stop)
nodes.ChildAdded:Connect(registerNode)
nodes.ChildRemoved:Connect(function(node)
    for prompt, target in pairs(targets) do
        if target.Node == node then
            targets[prompt] = nil
            prompt:Destroy()
        end
    end
end)
for _, node in ipairs(nodes:GetChildren()) do
    registerNode(node)
end
ResourceSpawnService.start()
