local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local definitions = require(ReplicatedStorage.Configs.ResourceDefinitions)
local swings = {
    Chop = { Windup = -34, Impact = 36, Recoil = 4, Lift = 0.8 },
    Mine = { Windup = 5, Impact = 56, Recoil = 36, Lift = 0.95 },
}
local active = {}

local function readJoint(character, name)
    local joint = character:FindFirstChild(name, true)
    if joint and joint:IsA("Motor6D") then
        return { Joint = joint, Part = joint.Part0, ParentFrame = joint.C0, ChildFrame = joint.C1 }
    end
    if joint and joint:IsA("AnimationConstraint") and joint.Attachment0 and joint.Attachment1 then
        return {
            Joint = joint, Part = joint.Attachment0.Parent,
            ParentFrame = joint.Attachment0.CFrame, ChildFrame = joint.Attachment1.CFrame,
        }
    end
end

local function startSwing(character, startedAt)
    local hand = character:FindFirstChild("RightHand")
    local tool = character:FindFirstChild("EquippedItem")
    local handle = tool and tool:FindFirstChild("Handle")
    local tip = handle and handle:FindFirstChild("StrikeTip")
    local grip = hand and hand:FindFirstChild("RightGrip")
    if not tip or not grip or not grip:IsA("JointInstance") or grip.Part0 ~= hand or grip.Part1 ~= handle then
        return
    end

    local shoulder = readJoint(character, "RightShoulder")
    local elbow = readJoint(character, "RightElbow")
    local wrist = readJoint(character, "RightWrist")
    if not shoulder or not elbow or not wrist then
        return
    end
    local state = {
        StartedAt = startedAt, Tip = tip, Grip = grip, HandOffset = grip.C1 * grip.C0:Inverse(),
        Shoulder = shoulder, Elbow = elbow, Wrist = wrist, Frames = {},
        UpperLength = (elbow.ParentFrame.Position - shoulder.ChildFrame.Position).Magnitude,
        LowerLength = (wrist.ParentFrame.Position - elbow.ChildFrame.Position).Magnitude,
    }
    active[character] = state
    return state
end

local function smooth(value)
    return value * value * (3 - 2 * value)
end

local function toolRotation(forward, angle)
    local radians = math.rad(angle)
    local blade = forward * math.cos(radians) - Vector3.yAxis * math.sin(radians)
    local shaft = forward * math.sin(radians) + Vector3.yAxis * math.cos(radians)
    return CFrame.fromMatrix(Vector3.zero, blade, shaft)
end

local function swingFrame(phase, windup, impact, recoil)
    if phase < 0.38 then
        return recoil:Lerp(windup, smooth(phase / 0.38))
    elseif phase < 0.59 then
        local progress = (phase - 0.38) / 0.21
        return windup:Lerp(impact, progress * progress)
    elseif phase < 0.63 then
        return impact
    end
    return impact:Lerp(recoil, smooth((phase - 0.63) / 0.37))
end

local function limbFrame(startPoint, endPoint, localStart, localEnd, reference)
    local localAxis = (localEnd - localStart).Unit
    local worldAxis = (endPoint - startPoint).Unit
    local alignment = CFrame.fromRotationBetweenVectors(reference:VectorToWorldSpace(localAxis), worldAxis)
    local rotation = alignment * reference
    return rotation + startPoint - rotation:VectorToWorldSpace(localStart)
end

local function poseJoint(state, entry, parent, child, weight)
    local joint = entry.Joint
    local base = joint.Transform
    local transform = (parent * entry.ParentFrame):ToObjectSpace(child * entry.ChildFrame)
    local applied = base:Lerp(transform, weight)
    joint.Transform = applied
    state.Frames[joint] = { Base = base, Applied = applied }
end

local function aimArm(state, hand, forward, weight)
    local shoulder, elbow, wrist = state.Shoulder, state.Elbow, state.Wrist
    local torso = shoulder.Part.CFrame
    local origin = (torso * shoulder.ParentFrame).Position
    local wristGoal = (hand * wrist.ChildFrame).Position
    local reach = wristGoal - origin
    local upper, lower = state.UpperLength, state.LowerLength
    if reach.Magnitude < 0.01 or math.min(upper, lower) < 0.05 then
        return
    end
    local direction = reach.Unit
    local distance = math.clamp(reach.Magnitude, math.abs(upper - lower) + 0.01, upper + lower - 0.01)
    local along = (upper * upper - lower * lower + distance * distance) / (2 * distance)
    local outward = forward:Cross(Vector3.yAxis) - Vector3.yAxis * 0.72 - forward * 0.16
    local pole = outward - direction * outward:Dot(direction)
    if pole.Magnitude < 0.01 then
        pole = direction:Cross(Vector3.yAxis)
    end
    local bend = pole.Unit
    local elbowGoal = origin + direction * along + bend * math.sqrt(math.max(0, upper * upper - along * along))
    local wristPosition = origin + direction * distance
    local reference = CFrame.lookAlong(Vector3.zero, forward)
    local upperArm = limbFrame(origin, elbowGoal, shoulder.ChildFrame.Position, elbow.ParentFrame.Position, reference)
    local lowerArm = limbFrame(elbowGoal, wristPosition, elbow.ChildFrame.Position, wrist.ParentFrame.Position, reference)
    poseJoint(state, shoulder, torso, upperArm, weight)
    poseJoint(state, elbow, upperArm, lowerArm, weight)
    poseJoint(state, wrist, lowerArm, hand + wristPosition - wristGoal, weight)
end

RunService.PreAnimation:Connect(function()
    for character, state in pairs(active) do
        for joint, frame in pairs(state.Frames) do
            if joint.Parent and joint.Transform == frame.Applied then
                joint.Transform = frame.Base
            end
        end
        table.clear(state.Frames)
        if not character.Parent or not state.Grip.Parent or character:GetAttribute("GatherStartedAt") ~= state.StartedAt then
            active[character] = nil
        end
    end
end)

RunService.PreSimulation:Connect(function()
    local now = workspace:GetServerTimeNow()
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local startedAt = character and character:GetAttribute("GatherStartedAt")
        local strike = character and character:GetAttribute("GatherStrike")
        local forward = character and character:GetAttribute("GatherFacing")
        local definition = character and definitions[character:GetAttribute("GatherResource")]
        local swing = definition and swings[definition.Swing]
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not startedAt or not strike or not forward or not swing or not root then
            continue
        end
        local elapsed = math.max(0, now - startedAt)
        if elapsed > definition.HoldDuration + 0.5 then
            continue
        end
        local state = active[character] or startSwing(character, startedAt)
        if not state then
            continue
        end

        local right = forward:Cross(Vector3.yAxis)
        local rotation = toolRotation(forward, swing.Impact)
        local impact = rotation + strike - rotation:VectorToWorldSpace(state.Tip.Position)
        local windup = toolRotation(forward, swing.Windup) + root.Position + right * 0.85 + Vector3.yAxis * swing.Lift
        local recoil = toolRotation(forward, swing.Recoil) + impact.Position - forward * 0.25 + Vector3.yAxis * 0.22
        local phase = (elapsed / definition.SwingInterval) % 1
        local hand = swingFrame(phase, windup, impact, recoil) * state.HandOffset
        aimArm(state, hand, forward, math.min(elapsed / 0.15, 1))
    end
end)

local localPlayer = Players.LocalPlayer
local nodes = workspace:WaitForChild("ResourceNodes")
local prompts = {}
local characterConnections = {}
local equippedName

local function updatePrompt(prompt)
    local requiredTool = prompt:GetAttribute("RequiredTool")
    prompt.Enabled = requiredTool == nil or equippedName == requiredTool
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
