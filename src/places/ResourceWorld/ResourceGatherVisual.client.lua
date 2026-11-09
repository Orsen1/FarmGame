local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local definitions = require(ReplicatedStorage.Configs.ResourceDefinitions)
local poses = {
    Chop = {
        Shoulder = { Vector3.new(65, 15, 40), Vector3.new(88, -20, -20) },
        Elbow = { Vector3.new(32, 0, 0), Vector3.new(12, 0, 0) },
        Waist = { Vector3.new(-4, -21, 0), Vector3.new(8, 20, 0) },
    },
    Mine = {
        Shoulder = { Vector3.new(145, 0, 15), Vector3.new(48, -7, 8) },
        Elbow = { Vector3.new(42, 0, 0), Vector3.new(9, 0, 0) },
        Waist = { Vector3.new(-7, -6, 0), Vector3.new(17, 5, 0) },
    },
}

local jointNames = {
    RightShoulder = "Shoulder",
    ["Right Shoulder"] = "Shoulder",
    RightElbow = "Elbow",
    Waist = "Waist",
}
local active = {}

local function findJoints(character)
    local joints = {}
    for _, descendant in ipairs(character:GetDescendants()) do
        local role = jointNames[descendant.Name]
        if role and (descendant:IsA("Motor6D") or descendant:IsA("AnimationConstraint")) then
            joints[role] = descendant
        end
    end
    return joints
end

local function smooth(value)
    return value * value * (3 - 2 * value)
end

local function swingBlend(phase)
    if phase < 0.42 then
        return 1 - smooth(phase / 0.42)
    elseif phase < 0.66 then
        return smooth((phase - 0.42) / 0.24)
    end
    return 1
end

RunService.PreAnimation:Connect(function()
    for _, state in pairs(active) do
        for joint, frame in pairs(state.Frames) do
            if joint.Parent and joint.Transform == frame.Applied then
                joint.Transform = frame.Base
            end
        end
        table.clear(state.Frames)
    end
end)

RunService.PreSimulation:Connect(function()
    local now = workspace:GetServerTimeNow()
    for character in pairs(active) do
        if not character.Parent or not character:GetAttribute("GatherStartedAt") then
            active[character] = nil
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local startedAt = character and character:GetAttribute("GatherStartedAt")
        local definition = character and definitions[character:GetAttribute("GatherResource")]
        local swing = definition and poses[definition.Swing]
        if not startedAt or not swing then
            continue
        end
        local elapsed = math.max(0, now - startedAt)
        if elapsed > definition.HoldDuration + 2 then
            continue
        end

        local state = active[character]
        if not state or state.StartedAt ~= startedAt then
            state = { StartedAt = startedAt, Joints = findJoints(character), Frames = {} }
            active[character] = state
        end

        local phase = (elapsed / definition.SwingInterval) % 1
        local blend = swingBlend(phase)
        local weight = math.clamp(elapsed / 0.14, 0, 1)
        for role, joint in pairs(state.Joints) do
            local pose = swing[role]
            if pose and joint.Parent then
                local degrees = pose[1]:Lerp(pose[2], blend)
                local rotation = CFrame.Angles(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
                local base = joint.Transform
                local applied = base:Lerp(rotation, weight)
                joint.Transform = applied
                state.Frames[joint] = { Base = base, Applied = applied }
            end
        end
    end
end)

local localPlayer = Players.LocalPlayer
local nodes = workspace:WaitForChild("ResourceNodes")
local prompts = {}
local characterConnections = {}
local equippedName

local function updatePrompt(prompt)
    prompt.Enabled = equippedName ~= nil and equippedName == prompt:GetAttribute("RequiredTool")
end

local function updateEquipment(character)
    local tool = character and character:FindFirstChild("EquippedItem")
    equippedName = tool and tool:IsA("Tool") and tool:GetAttribute("ItemName") or nil

    for prompt in pairs(prompts) do
        updatePrompt(prompt)
    end
end

local function trackPrompt(prompt)
    if prompt:IsA("ProximityPrompt") and prompt.Name == "GatherPrompt" then
        prompts[prompt] = true
        updatePrompt(prompt)
    end
end

local function watchCharacter(character)
    for _, connection in ipairs(characterConnections) do
        connection:Disconnect()
    end
    table.clear(characterConnections)

    if character then
        local function equipmentChanged(child)
            if child.Name == "EquippedItem" then
                updateEquipment(character)
            end
        end

        table.insert(characterConnections, character.ChildAdded:Connect(equipmentChanged))
        table.insert(characterConnections, character.ChildRemoved:Connect(equipmentChanged))
    end
    updateEquipment(character)
end

localPlayer.CharacterAdded:Connect(watchCharacter)
localPlayer.CharacterRemoving:Connect(function()
    watchCharacter(nil)
end)
watchCharacter(localPlayer.Character)

nodes.DescendantAdded:Connect(trackPrompt)
nodes.DescendantRemoving:Connect(function(object)
    prompts[object] = nil
end)
for _, object in ipairs(nodes:GetDescendants()) do
    trackPrompt(object)
end
