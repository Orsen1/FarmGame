local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bakery = {}
Bakery.__index = Bakery

local cream = Color3.fromRGB(243, 222, 177)
local flour = Color3.fromRGB(252, 244, 218)
local crust = Color3.fromRGB(179, 99, 34)
local wood = Color3.fromRGB(151, 101, 57)

local function smooth(value)
    value = math.clamp(value, 0, 1)
    return value * value * (3 - 2 * value)
end

local function readJoint(character, name)
    local joint = character:FindFirstChild(name, true)
    if joint and joint:IsA("Motor6D") and joint.Part0 and joint.Part1 then
        return { Joint = joint, Part = joint.Part0, ParentFrame = joint.C0, ChildFrame = joint.C1 }
    end
    if joint and joint:IsA("AnimationConstraint") and joint.Attachment0 and joint.Attachment1 then
        return {
            Joint = joint, Part = joint.Attachment0.Parent,
            ParentFrame = joint.Attachment0.CFrame, ChildFrame = joint.Attachment1.CFrame,
        }
    end
end

local function limbFrame(startPoint, endPoint, localStart, localEnd, reference)
    local localAxis = (localEnd - localStart).Unit
    local worldAxis = (endPoint - startPoint).Unit
    local rotation = CFrame.fromRotationBetweenVectors(reference:VectorToWorldSpace(localAxis), worldAxis) * reference
    return rotation + startPoint - rotation:VectorToWorldSpace(localStart)
end

local function poseJoint(state, entry, parent, child, weight)
    local joint = entry.Joint
    local frame = state.Frames[joint]
    if not frame then
        frame = {}
        state.Frames[joint] = frame
    end
    frame.Base = joint.Transform
    frame.Applied = frame.Base:Lerp((parent * entry.ParentFrame):ToObjectSpace(child * entry.ChildFrame), weight)
    joint.Transform = frame.Applied
end

local function arm(character, side)
    local shoulder = readJoint(character, side .. "Shoulder")
    local elbow = readJoint(character, side .. "Elbow")
    local wrist = readJoint(character, side .. "Wrist")
    if shoulder and elbow and wrist then
        return {
            Shoulder = shoulder, Elbow = elbow, Wrist = wrist,
            UpperLength = (elbow.ParentFrame.Position - shoulder.ChildFrame.Position).Magnitude,
            LowerLength = (wrist.ParentFrame.Position - elbow.ChildFrame.Position).Magnitude,
            Side = side == "Left" and -1 or 1,
        }
    end
end

local function aimArm(state, entry, hand, torso, weight)
    local shoulder, elbow, wrist = entry.Shoulder, entry.Elbow, entry.Wrist
    if not shoulder.Joint.Parent or not elbow.Joint.Parent or not wrist.Joint.Parent then return end
    torso = torso or shoulder.Part.CFrame
    local origin = (torso * shoulder.ParentFrame).Position
    local wristGoal = (hand * wrist.ChildFrame).Position
    local reach = wristGoal - origin
    local upper, lower = entry.UpperLength, entry.LowerLength
    if reach.Magnitude < 0.01 or math.min(upper, lower) < 0.05 then return end
    local direction = reach.Unit
    local distance = math.clamp(reach.Magnitude, math.abs(upper - lower) + 0.01, upper + lower - 0.01)
    local along = (upper * upper - lower * lower + distance * distance) / (2 * distance)
    local outward = state.Root.CFrame.RightVector * entry.Side - Vector3.yAxis * 0.72
    local pole = outward - direction * outward:Dot(direction)
    if pole.Magnitude < 0.01 then pole = state.Root.CFrame.LookVector end
    local elbowGoal = origin + direction * along + pole.Unit * math.sqrt(math.max(0, upper * upper - along * along))
    local wristPosition = origin + direction * distance
    local reference = state.Root.CFrame.Rotation
    local upperArm = limbFrame(origin, elbowGoal, shoulder.ChildFrame.Position, elbow.ParentFrame.Position, reference)
    local lowerArm = limbFrame(elbowGoal, wristPosition, elbow.ChildFrame.Position, wrist.ParentFrame.Position, reference)
    poseJoint(state, shoulder, torso, upperArm, weight)
    poseJoint(state, elbow, upperArm, lowerArm, weight)
    poseJoint(state, wrist, lowerArm, hand + wristPosition - wristGoal, weight)
end

function Bakery:ResetPose()
    for joint, frame in pairs(self.Frames) do
        if frame.Applied and joint.Parent and joint.Transform == frame.Applied then
            joint.Transform = frame.Base
        end
        frame.Applied = nil
    end
end

function Bakery:RestoreTool()
    for part, transparency in pairs(self.HiddenParts) do
        if part.Parent then part.LocalTransparencyModifier = transparency end
    end
    table.clear(self.HiddenParts)
    self.HiddenTool = nil
end

function Bakery:HideTool(character)
    local tool = character:FindFirstChild("EquippedItem")
    if tool == self.HiddenTool then return end
    self:RestoreTool()
    self.HiddenTool = tool
    if not tool then return end
    for _, part in ipairs(tool:GetDescendants()) do
        if part:IsA("BasePart") then
            self.HiddenParts[part] = part.LocalTransparencyModifier
            part.LocalTransparencyModifier = 1
        end
    end
end

function Bakery:Pose(left, right, weight, lean)
    local player = Players:GetPlayerByUserId(self.Station:GetAttribute("OperatorUserId") or 0)
    local character = player and player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then character = nil end
    if not character then
        self:RestoreTool()
        self:ResetPose()
        self.Character, self.Left, self.Right, self.Waist = nil, nil, nil, nil
        table.clear(self.Frames)
        return
    end
    if self.Station:GetAttribute("Busy") == true then self:HideTool(character) end
    if self.Character ~= character then
        self:ResetPose()
        table.clear(self.Frames)
        self.Character = character
        self.Left = character and arm(character, "Left")
        self.Right = character and arm(character, "Right")
        self.Waist = character and readJoint(character, "Waist")
    end
    if not self.Left or not self.Right then return end
    local torso
    if self.Waist and self.Waist.Joint.Parent then
        local waist = self.Waist
        local parent = waist.Part.CFrame
        local target = parent * waist.ParentFrame * CFrame.Angles(-lean, 0, 0) * waist.ChildFrame:Inverse()
        poseJoint(self, waist, parent, target, weight)
        torso = parent * waist.ParentFrame * waist.Joint.Transform * waist.ChildFrame:Inverse()
    end
    aimArm(self, self.Left, left, torso, weight)
    aimArm(self, self.Right, right, torso, weight)
end

function Bakery:Part(name, size, color, shape)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.Color = color
    part.Material = Enum.Material.SmoothPlastic
    part.Shape = Enum.PartType.Block
    if shape == Enum.PartType.Ball then
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = Enum.MeshType.Sphere
        mesh.Parent = part
    elseif shape then
        part.Shape = shape
    end
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.Transparency = 1
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = self.Model
    table.insert(self.Parts, part)
    return part
end

function Bakery:Show(part, frame, size, opacity)
    part.CFrame = frame
    if size then part.Size = size end
    part.Transparency = 1 - (opacity or 1) * self.Fade
end

function Bakery:Pour(origin, target, opacity)
    local length = (target - origin).Magnitude
    if length < 0.01 then return end
    self:Show(self.Stream, CFrame.lookAt((origin + target) / 2, target) * CFrame.Angles(math.pi / 2, 0, 0),
        Vector3.new(0.055, length, 0.055), opacity)
end

function Bakery:Build()
    local model = Instance.new("Model")
    model.Name = "BakeryVisual"
    model.Parent = self.Station
    self.Model = model
    self.Dough = self:Part("Dough", Vector3.new(1.1, 0.48, 0.8), cream, Enum.PartType.Ball)
    self.Fold = self:Part("DoughFold", Vector3.new(0.9, 0.3, 0.46), cream, Enum.PartType.Ball)
    if self.Kind == "KitchenTable" then
        self.Board = self:Part("PastryBoard", Vector3.new(2.6, 0.09, 1.7), wood)
        self.Board.Material = Enum.Material.Wood
        self.Dusting = self:Part("FlourOnBoard", Vector3.new(1.7, 0.012, 1.05), flour, Enum.PartType.Ball)
        self.Sack = self:Part("FlourSack", Vector3.new(0.62, 0.75, 0.5), Color3.fromRGB(194, 157, 105))
        self.Sack.Material = Enum.Material.Fabric
        self.SackTie = self:Part("SackFold", Vector3.new(0.5, 0.09, 0.43), Color3.fromRGB(135, 99, 58))
        self.Stream = self:Part("Pour", Vector3.new(0.05, 0.6, 0.05), flour)
        self.Eggs = {}
        local eggTemplate = ReplicatedStorage:FindFirstChild("AnimalModels")
        eggTemplate = eggTemplate and eggTemplate:FindFirstChild("Egg")
        eggTemplate = eggTemplate and eggTemplate:FindFirstChild("EggShell")
        for index = 1, 2 do
            local egg
            if eggTemplate and eggTemplate:IsA("BasePart") then
                egg = eggTemplate:Clone()
                egg.Anchored, egg.CanCollide, egg.CanTouch, egg.CanQuery = true, false, false, false
                egg.Transparency, egg.CastShadow = 1, false
                egg.Size = Vector3.new(0.25, 0.35, 0.25)
                egg.Parent = model
                table.insert(self.Parts, egg)
            else
                egg = self:Part("Egg", Vector3.new(0.25, 0.35, 0.25), flour, Enum.PartType.Ball)
            end
            self.Eggs[index] = egg
        end
        self.Yolk = self:Part("EggInDough", Vector3.new(0.32, 0.07, 0.27), Color3.fromRGB(246, 185, 53), Enum.PartType.Ball)
        self.Bucket = {}
        local tools = ReplicatedStorage:FindFirstChild("Tools")
        local template = tools and tools:FindFirstChild("MilkBucket")
        local handle = template and template:FindFirstChild("Handle")
        if handle then
            for _, original in ipairs(template:GetDescendants()) do
                if original:IsA("BasePart") then
                    local part = original:Clone()
                    for _, child in ipairs(part:GetChildren()) do
                        if child:IsA("SpecialMesh") and child.MeshType == Enum.MeshType.FileMesh then
                            child.Scale *= 0.5
                        elseif not child:IsA("DataModelMesh") and not child:IsA("SurfaceAppearance") then
                            child:Destroy()
                        end
                    end
                    local offset = handle.CFrame:ToObjectSpace(original.CFrame)
                    part.Size = original.Size * 0.5
                    part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
                    part.Transparency, part.CastShadow = 1, false
                    part.Parent = model
                    table.insert(self.Parts, part)
                    table.insert(self.Bucket, { Part = part, Offset = offset.Rotation + offset.Position * 0.5 })
                end
            end
        end
    else
        self.Peel = self:Part("BakersPeel", Vector3.new(1.5, 0.07, 1.5), wood)
        self.Peel.Material = Enum.Material.Wood
        self.Handle = self:Part("PeelHandle", Vector3.new(0.12, 0.1, 2.1), wood)
        self.Handle.Material = Enum.Material.Wood
        self.Cuts = {}
        for index = 1, 3 do
            self.Cuts[index] = self:Part("LoafScore", Vector3.new(0.67, 0.025, 0.055), flour)
        end
        self.Heat = self:Part("OvenHeat", Vector3.new(0.05, 0.05, 0.05), cream)
        self.Light = Instance.new("PointLight")
        self.Light.Color = Color3.fromRGB(255, 155, 71)
        self.Light.Range = 8
        self.Light.Brightness = 0
        self.Light.Shadows = true
        self.Light.Parent = self.Heat
        self.Steam = Instance.new("ParticleEmitter")
        self.Steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
        self.Steam.Color = ColorSequence.new(Color3.fromRGB(235, 219, 188))
        self.Steam.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.86), NumberSequenceKeypoint.new(1, 1),
        })
        self.Steam.Size = NumberSequence.new(0.15, 0.55)
        self.Steam.Lifetime = NumberRange.new(0.8, 1.3)
        self.Steam.Speed = NumberRange.new(0.2, 0.4)
        self.Steam.Acceleration = Vector3.new(0, 0.35, 0)
        self.Steam.SpreadAngle = Vector2.new(8, 8)
        self.Steam.Rate = 0
        self.Steam.Parent = self.Heat
    end
end

function Bakery:Table(elapsed, busy)
    local anchor = self.Root:FindFirstChild("DoughPoint")
    local point = anchor and anchor:IsA("Attachment") and anchor.CFrame or CFrame.new(0, 3.02, 0.55)
    local frame = self.Root.CFrame * point
    self:Show(self.Board, frame * CFrame.new(0, -0.13, 0))
    self:Show(self.Dusting, frame * CFrame.new(0, -0.077, 0), nil, 0.65)
    local height, width, depth, z, fold = 0.48, 1.1, 0.8, 0, 0
    local left = Vector3.new(-0.4, 0.65, 0.55)
    local right = Vector3.new(0.4, 0.65, 0.55)
    local lean = 0.12
    if busy and elapsed < 2 then
        local pour = math.sin(math.pi * smooth(elapsed / 2))
        local sack = frame * CFrame.new(-0.25, 1.05, 0.1) * CFrame.Angles(0, 0, -pour * 2.1)
        self:Show(self.Sack, sack)
        self:Show(self.SackTie, sack * CFrame.new(0, 0.39, 0))
        self:Pour((sack * CFrame.new(0, 0.4, 0)).Position, (frame * CFrame.new(0.05, 0.16, 0)).Position, smooth((pour - 0.6) / 0.4) * 0.8)
        height, width, depth = 0.12 + 0.18 * smooth(elapsed / 2), 1.15, 0.85
        left = frame:PointToObjectSpace((sack * CFrame.new(-0.32, 0, 0)).Position)
        right = frame:PointToObjectSpace((sack * CFrame.new(0.32, 0.1, 0)).Position)
    elseif busy and elapsed < 4 then
        local pour = math.sin(math.pi * smooth((elapsed - 2) / 2))
        local bucket = frame * CFrame.new(0.45, 1.15, 0.08) * CFrame.Angles(0, 0, -pour * 1.2)
        for _, entry in ipairs(self.Bucket) do self:Show(entry.Part, bucket * entry.Offset) end
        self.Stream.Color = flour
        self:Pour((bucket * CFrame.new(0.3, -0.32, 0)).Position, (frame * CFrame.new(0.05, 0.2, 0.05)).Position, smooth((pour - 0.55) / 0.45))
        height = 0.3
        left = frame:PointToObjectSpace((bucket * CFrame.new(-0.25, -0.65, 0)).Position)
        right = frame:PointToObjectSpace(bucket.Position)
    elseif busy and elapsed < 5.5 then
        local progress = (elapsed - 4) / 1.5
        local crack = smooth((progress % 0.5) * 2)
        local egg = frame * CFrame.new(0, 0.6 - math.sin(crack * math.pi) * 0.22, 0)
        self:Show(self.Eggs[progress < 0.5 and 1 or 2], egg, nil, 1 - smooth((crack - 0.75) * 4))
        self:Show(self.Yolk, frame * CFrame.new(0.06, 0.24, 0), nil, smooth(progress * 3))
        left = Vector3.new(-0.16 - crack * 0.15, 0.6, 0)
        right = Vector3.new(0.16 + crack * 0.15, 0.6, 0)
        height = 0.35
    elseif busy then
        local cycle = ((elapsed - 5.5) / 2.2) % 1
        local press = smooth(cycle / 0.3) * (1 - smooth((cycle - 0.3) / 0.22))
        fold = smooth((cycle - 0.3) / 0.22) * (1 - smooth((cycle - 0.57) / 0.19))
        local release = smooth((cycle - 0.76) / 0.12) * (1 - smooth((cycle - 0.9) / 0.1))
        local finish = smooth((elapsed - 18) / 2)
        press *= 1 - finish
        fold *= 1 - finish
        width, height, depth = 1.1 + press * 0.25 - fold * 0.08, 0.48 - press * 0.23, 0.8 + press * 0.35
        z = -press * 0.18 + fold * 0.11
        local handY = height * 0.68 + 0.06 + fold * 0.2 + release * 0.33 + finish * 0.4
        local handZ = z + 0.12 - press * 0.15 + fold * 0.15
        left = Vector3.new(-0.32 - release * 0.12, handY, handZ)
        right = Vector3.new(0.32 + release * 0.12, handY, handZ + fold * 0.06)
        lean += press * 0.08
    end
    self.Dough.Color = busy and elapsed < 2 and flour or cream
    self:Show(self.Dough, frame * CFrame.new(0, height / 2 - 0.065, z), Vector3.new(width, height, depth))
    self:Show(self.Fold, frame * CFrame.new(0, height * 0.67 - 0.025, z + 0.12),
        Vector3.new(width * 0.84, 0.21 + fold * 0.12, 0.38), fold * 0.85)
    if busy then
        local palm = CFrame.Angles(math.pi / 2, 0, 0)
        self:Pose(frame * CFrame.new(left) * palm, frame * CFrame.new(right) * palm, smooth(elapsed / 0.3) * self.Fade, lean)
    end
end

function Bakery:Oven(elapsed, duration, phase, busy)
    local anchor = self.Root:FindFirstChild("OvenTrayPoint")
    local tray = anchor and anchor:IsA("Attachment") and anchor.CFrame or CFrame.new(0, 2.18, 0.8)
    local frame = self.Root.CFrame * tray
    local progress = busy and phase == "Processing" and math.clamp(elapsed / duration, 0, 1) or 1
    local rise = smooth(progress / 0.55)
    if busy and phase == "Loading" then
        progress, rise = 0, 0
        local loading = math.clamp(elapsed / duration, 0, 1)
        local insert = smooth((loading - 0.15) / 0.48)
        local withdraw = smooth((loading - 0.69) / 0.26)
        local distance = 1.75 * (1 - insert)
        frame *= CFrame.new(0, math.sin(insert * math.pi) * 0.08, distance)
        local peel = self.Root.CFrame * tray * CFrame.new(0, -0.03 - withdraw * 0.12, distance + withdraw * 1.7)
        self:Show(self.Peel, peel, nil, 1 - smooth((loading - 0.9) * 10))
        self:Show(self.Handle, peel * CFrame.new(0, 0, 1.7), nil, 1 - smooth((loading - 0.9) * 10))
        local palm = CFrame.Angles(math.pi / 2, 0, 0)
        local gripSlide = insert - withdraw * 1.7
        local gripWeight = smooth(elapsed / 0.25) * (1 - smooth((loading - 0.72) / 0.22)) * self.Fade
        self:Pose(peel * CFrame.new(-0.07, 0.13, 0.75 + gripSlide) * palm,
            peel * CFrame.new(0.07, 0.13, 1 + gripSlide) * palm, gripWeight, 0.16 + insert * 0.08)
    end
    local height = 0.37 + rise * 0.24
    local width = 0.85 + rise * 0.16
    local browning = smooth((progress - 0.36) / 0.64)
    self.Dough.Color = cream:Lerp(crust, browning)
    self:Show(self.Dough, frame * CFrame.new(0, height / 2 + 0.02, 0), Vector3.new(width, height, 1.23 + rise * 0.13))
    for index, cut in ipairs(self.Cuts) do
        cut.Color = flour:Lerp(Color3.fromRGB(232, 166, 86), browning)
        self:Show(cut, frame * CFrame.new(0, height - 0.015, (index - 2) * 0.3) * CFrame.Angles(0, -0.33, 0),
            Vector3.new(width * 0.61, 0.025, 0.045 + rise * 0.028))
    end
    self.Heat.CFrame = self.Root.CFrame * tray * CFrame.new(0, 0.5, 0.2)
    self.Light.Brightness = busy and phase == "Processing" and (1.1 + math.sin(elapsed * 2.3) * 0.07) * self.Fade or 0
    self.Steam.Rate = busy and phase == "Processing" and 1.5 * self.Fade or 0
end

function Bakery:Update(now, dt)
    if self.Destroyed then return end
    if not self.Station.Parent or not self.Root.Parent then self:Destroy(); return end
    local house = self.Station:FindFirstAncestor("StarterHouse")
    local repaired = not house or (house:GetAttribute("HouseLevel") or -1) >= 0
    local busy = repaired and self.Station:GetAttribute("Busy") == true
    local expected = self.Kind == "KitchenTable" and "MakeDough" or "BakeBread"
    busy = busy and self.Station:GetAttribute("ActiveRecipe") == expected
    if not busy or (self.Kind == "KitchenOven" and self.Station:GetAttribute("ProductionPhase") ~= "Loading") then
        self:RestoreTool()
    end
    local output = self.Station:FindFirstChild("OutputInventory")
    local item = output and output:FindFirstChild(self.Kind == "KitchenTable" and "Dough" or "Bread")
    local ready = repaired and item and item:IsA("IntValue") and item.Value > 0
    local visible = busy or ready
    self.Fade = math.clamp(self.Fade + (visible and 1 or -1) * dt * 5, 0, 1)
    if not repaired then self.Fade = 0 end
    if not self.Model then
        if self.Fade == 0 then return end
        self:Build()
    end
    for _, part in ipairs(self.Parts) do part.Transparency = 1 end
    if self.Light then self.Light.Brightness = 0; self.Steam.Rate = 0 end
    if self.Fade == 0 then
        self:ResetPose()
        self.Character, self.Left, self.Right, self.Waist = nil, nil, nil, nil
        if self.Steam then self.Steam:Clear() end
        table.clear(self.Frames)
        return
    end
    local elapsed = math.max(0, now - (self.Station:GetAttribute("ProductionStartedAt") or now))
    local duration = math.max(0.1, self.Station:GetAttribute("ProductionDuration") or 20)
    local phase = self.Station:GetAttribute("ProductionPhase")
    if busy or ready then
        self.Elapsed, self.Duration, self.Phase, self.WasBusy = elapsed, duration, phase, busy
    end
    if self.Kind == "KitchenTable" then
        self:Table(self.Elapsed or elapsed, busy or (not ready and self.WasBusy and self.Fade > 0))
    else
        self:Oven(self.Elapsed or elapsed, self.Duration or duration, self.Phase, busy or (not ready and self.WasBusy and self.Fade > 0))
    end
end

function Bakery:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self:RestoreTool()
    self:ResetPose()
    if self.Model then self.Model:Destroy() end
    table.clear(self.Frames)
    table.clear(self.Parts)
end

function Bakery.new(station)
    local root = station:FindFirstChild("PlacementRoot")
    if not root or not root:IsA("BasePart") then return nil end
    return setmetatable({
        Station = station, Root = root, Kind = station:GetAttribute("ProductionVisual"),
        Frames = {}, Parts = {}, HiddenParts = {}, Fade = 0,
    }, Bakery)
end

return Bakery
