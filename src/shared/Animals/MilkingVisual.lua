local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Visual = {}
Visual.__index = Visual

local function workWeight(settings, elapsed, duration)
    if settings.CleanFrom then
        return math.clamp((elapsed - settings.CleanFrom) / 0.3, 0, 1) *
            math.clamp((settings.CleanUntil - elapsed) / 0.3, 0, 1)
    end
    return math.clamp(elapsed / 0.6, 0, 1) * math.clamp((duration - elapsed) / 0.6, 0, 1)
end

local function makeBrush(model)
    local parts = {}
    for index = 0, 6 do
        local part = Instance.new("Part")
        part.Name = index == 0 and "Handle" or "Bristles"
        part.Size = index == 0 and Vector3.new(0.55, 0.14, 0.35) or Vector3.new(0.06, 0.17, 0.3)
        part.CFrame = CFrame.new(index == 0 and Vector3.zero or Vector3.new((index - 3.5) * 0.075, 0.15, 0))
        part.Color = index == 0 and Color3.fromRGB(152, 103, 59) or Color3.fromRGB(244, 215, 153)
        part.Material = Enum.Material.SmoothPlastic
        part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
        part.Transparency = 1
        part.Parent = model
        table.insert(parts, part)
    end
    model.PrimaryPart = model.Handle
    return parts
end

function Visual.new(folder, settings, animalModel)
    local userId = folder:GetAttribute("MilkerUserId")
    local player = Players:GetPlayerByUserId(userId)
    local character = player and player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local frame = folder:GetAttribute("MilkingFrame")
    if not humanoid or not frame then return end
    local self = setmetatable({UserId = userId, Folder = folder, Character = character,
        Settings = settings, Frame = frame, Hidden = {}, Targets = {}, Controls = {}, Joints = {},
        KneelDepth = humanoid.HipHeight * 0.6,
        Side = folder:GetAttribute("MilkingSide") or 1}, Visual)
    local model = Instance.new("Model")
    model.Name = settings.BucketItem and "MilkingBucket" or "HoofBrush"
    if settings.BucketItem then
        for _, child in ipairs(ReplicatedStorage.Tools[settings.BucketItem]:GetChildren()) do
            if child:IsA("BasePart") then
                local part = child:Clone()
                part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
                part.Parent = model
            end
        end
        model.PrimaryPart = model.Handle
        model:ScaleTo(settings.BucketScale)
        local offset = settings.BucketOffset
        model:PivotTo(frame * CFrame.new(Vector3.new(offset.X * self.Side, offset.Y + 1.95 * settings.BucketScale, offset.Z)))
        self.Surface = model.MilkSurface
        self.SurfaceFrame = self.Surface.CFrame
    else
        self.BrushParts = makeBrush(model)
        self.Hoof = animalModel.FrontRightLeg:FindFirstChild("Hoof")
    end
    model.Parent = workspace
    self.Model = model
    for index, side in ipairs({"Left", "Right"}) do
        local target = Instance.new("Part")
        target.Name = side .. "MilkTarget"
        target.Size = Vector3.new(0.05, 0.05, 0.05)
        target.Anchored, target.CanCollide, target.CanQuery, target.CanTouch = true, false, false, false
        target.Transparency = 1
        target.Parent = model
        table.insert(self.Targets, target)
        local arm, hand = character:FindFirstChild(side .. "UpperArm"), character:FindFirstChild(side .. "Hand")
        if arm and hand then
            local control = Instance.new("IKControl")
            control.Name = side .. "Milking"
            control.Type = Enum.IKControlType.Position
            control.ChainRoot, control.EndEffector, control.Target = arm, hand, target
            control.Weight, control.SmoothTime = 0, 0.08
            control.Parent = humanoid
            table.insert(self.Controls, control)
        end
    end
    if self.Surface then
        local stream = Instance.new("Part")
        stream.Name = "MilkStream"
        stream.Anchored, stream.CanCollide, stream.CanQuery, stream.CanTouch = true, false, false, false
        stream.Color = Color3.fromRGB(255, 246, 222)
        stream.Material = Enum.Material.SmoothPlastic
        stream.Transparency = 1
        stream.Parent = model
        self.Stream = stream
    end
    for _, joint in ipairs(character:GetDescendants()) do
        if humanoid.RigType == Enum.HumanoidRigType.R15 and
            (joint:IsA("AnimationConstraint") or joint:IsA("Motor6D")) and
            (joint.Name == "Root" or joint.Name == "Waist" or joint.Name == "Neck" or joint.Name == "RootJoint" or
                joint.Name:find("Hip") or joint.Name:find("Knee") or joint.Name:find("Ankle")) then
            self.Joints[joint] = {Base = joint.Transform}
        end
    end
    self.PreAnimation = RunService.PreAnimation:Connect(function()
        for joint, pose in pairs(self.Joints) do
            if joint.Parent and pose.Applied then joint.Transform = pose.Base end
        end
    end)
    self.PreSimulation = RunService.PreSimulation:Connect(function() self:Pose() end)
    return self
end

function Visual:Pose()
    local now = workspace:GetServerTimeNow()
    local elapsed = now - (self.Folder:GetAttribute("MilkingStartedAt") or now)
    local duration = self.Folder:GetAttribute("MilkingDuration") or self.Settings.Duration
    local weight = workWeight(self.Settings, elapsed, duration)
    local kneeling = self.Settings.BucketItem ~= nil
    for joint, pose in pairs(self.Joints) do
        if joint.Parent then
            pose.Base = joint.Transform
            local offset = CFrame.identity
            if joint.Name == "Root" or joint.Name == "RootJoint" then
                offset = CFrame.new(0, -self.KneelDepth * weight * (kneeling and 1 or 0.15), 0)
            elseif joint.Name == "Waist" then
                offset = CFrame.Angles((kneeling and -0.55 or -0.25) * weight, 0, 0)
            elseif joint.Name == "Neck" then
                offset = CFrame.Angles(0.25 * weight, 0, 0)
            elseif kneeling and (joint.Name:find("Hip") or joint.Name:find("Ankle")) then
                offset = CFrame.Angles(1.05 * weight, 0, 0)
            elseif kneeling and joint.Name:find("Knee") then
                offset = CFrame.Angles(-2.1 * weight, 0, 0)
            end
            joint.Transform = offset * pose.Base
            pose.Applied = true
        end
    end
end

function Visual:Update(now)
    now = now or workspace:GetServerTimeNow()
    local elapsed = now - (self.Folder:GetAttribute("MilkingStartedAt") or now)
    local duration = self.Folder:GetAttribute("MilkingDuration") or self.Settings.Duration
    local alpha = math.clamp((elapsed - 0.6) / math.max(0.1, duration - 1.2), 0, 1)
    local weight = workWeight(self.Settings, elapsed, duration)
    if self.Surface then
        self.Surface.Transparency = 1 - math.clamp(alpha * 8, 0, 1)
        self.Surface.CFrame = self.SurfaceFrame + Vector3.new(0, -0.9 * (1 - alpha) * self.Settings.BucketScale, 0)
    elseif self.Hoof then
        local brushFrame = self.Hoof.CFrame * CFrame.new(0, -0.3, math.sin(elapsed * 18) * 0.13)
        self.Model:PivotTo(brushFrame)
        for _, part in ipairs(self.BrushParts) do part.Transparency = weight > 0 and 0 or 1 end
    end
    local pulse = math.sin(elapsed * math.pi * 4)
    for index, target in ipairs(self.Targets) do
        local side = index == 1 and -1 or 1
        if self.Hoof then
            target.CFrame = index == 1 and self.Hoof.CFrame * CFrame.new(0.25, -0.08, 0.25) or self.Model:GetPivot()
        else
            target.CFrame = self.Frame * CFrame.new(self.Settings.HandOffset + Vector3.new(self.Side * 0.35, pulse * side * 0.055, side * 0.18))
        end
    end
    for _, control in ipairs(self.Controls) do control.Weight = weight end
    if self.Surface then
        local top = self.Frame:PointToWorldSpace(self.Settings.HandOffset)
        local bottom = self.Surface.Position
        local length = (top - bottom).Magnitude
        self.Stream.Size = Vector3.new(0.035, math.max(0.01, length), 0.035)
        self.Stream.CFrame = CFrame.lookAt((top + bottom) / 2, top) * CFrame.Angles(math.pi / 2, 0, 0)
        self.Stream.Transparency = elapsed > 0.6 and elapsed < duration - 0.6 and pulse > -0.5 and 0.1 or 1
    end
    local tool = self.Character:FindFirstChild("EquippedItem")
    if tool then
        for _, part in ipairs(tool:GetDescendants()) do
            if part:IsA("BasePart") then
                if self.Hidden[part] == nil then self.Hidden[part] = part.LocalTransparencyModifier end
                part.LocalTransparencyModifier = 1
            end
        end
    end
end

function Visual:Destroy()
    self.PreAnimation:Disconnect()
    self.PreSimulation:Disconnect()
    for part, transparency in pairs(self.Hidden) do if part.Parent then part.LocalTransparencyModifier = transparency end end
    for joint, pose in pairs(self.Joints) do if joint.Parent and pose.Applied then joint.Transform = pose.Base end end
    for _, control in ipairs(self.Controls) do control:Destroy() end
    self.Model:Destroy()
end

return Visual
