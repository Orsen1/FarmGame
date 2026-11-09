local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local definitions = require(ReplicatedStorage.Configs.ResourceDefinitions)
local InventoryService = require(script.Parent.InventoryService)
local nodes = workspace:WaitForChild("ResourceNodes")
local targets = {}
local attempts = {}
local holdTolerance = 0.15
local triggerTimeout = 2

local function registerNode(node)
    if not node:IsA("Model") then
        return
    end
    local resourceId = node:GetAttribute("ResourceId") or node.Name
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
    targets[prompt] = { Node = node, Definition = definition, ResourceId = resourceId }
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
    if not root or not humanoid or humanoid.Health <= 0 or not tool or not tool:IsA("Tool")
        or tool:GetAttribute("ItemName") ~= target.Definition.Tool then
        return
    end

    local slotNumber = player:GetAttribute("SelectedSlot") or 1
    local inventory = player:FindFirstChild("Inventory")
    local slot = inventory and inventory:FindFirstChild("Slot" .. slotNumber)
    if not slot or slot.Amount.Value <= 0 or slot.ItemName.Value ~= target.Definition.Tool then
        return
    end

    local point = prompt.Parent
    local distance = (root.Position - point.WorldPosition).Magnitude
    if distance ~= distance or distance > target.Definition.MaxDistance then
        return
    end
    return target, character, root, tool
end

local function stop(player)
    local attempt = attempts[player]
    if not attempt then
        return
    end
    attempts[player] = nil
    attempt.Character:SetAttribute("GatherStartedAt", nil)
    attempt.Character:SetAttribute("GatherResource", nil)
end

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, player)
    if attempts[player] then
        return
    end
    local target, character, root, tool = getContext(player, prompt)
    if not target then
        return
    end
    local definition = target.Definition
    if not InventoryService.CanAddItem(player, definition.RewardItem, definition.RewardAmount) then
        return
    end

    local startedAt = workspace:GetServerTimeNow()
    attempts[player] = {
        Prompt = prompt, Character = character, Tool = tool, StartedAt = startedAt,
    }
    local direction = prompt.Parent.WorldPosition - root.Position
    local horizontal = Vector3.new(direction.X, 0, direction.Z)
    if horizontal.Magnitude > 0.01 then
        root.CFrame = CFrame.lookAt(root.Position, root.Position + horizontal)
    end
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

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
    local attempt = attempts[player]
    if not attempt or attempt.Prompt ~= prompt then
        return
    end
    local target, character, _, tool = getContext(player, prompt)
    local elapsed = workspace:GetServerTimeNow() - attempt.StartedAt
    stop(player)
    if not target or character ~= attempt.Character or tool ~= attempt.Tool
        or elapsed < target.Definition.HoldDuration - holdTolerance
        or elapsed > target.Definition.HoldDuration + triggerTimeout then
        return
    end
    InventoryService.AddItem(player, target.Definition.RewardItem, target.Definition.RewardAmount)
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
        local target, character, _, tool = getContext(player, attempt.Prompt)
        if not target or character ~= attempt.Character or tool ~= attempt.Tool
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
