local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Config = require(ReplicatedStorage.Configs.AnimalConfig)
local Motion = require(ReplicatedStorage.Animals.AnimalMotion)
local templates = ReplicatedStorage:WaitForChild("AnimalModels")
local definitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local plots = workspace:WaitForChild("Plots")
local visuals = {}
local coops = {}
local container = Instance.new("Folder")
container.Name = "AnimalVisuals"
container.Parent = workspace

local function bindCoop(object)
    if not object:IsA("Model") or coops[object] or not Config.Coops[object:GetAttribute("ItemName") or object.Name] then return end
    local basket, feeder = object:FindFirstChild("EggBasket"), object:FindFirstChild("Feeder")
    local output = object:FindFirstChild("OutputInventory")
    local egg = output and output:FindFirstChild("Egg")
    local slots = basket and basket:FindFirstChild("EggSlots")
    local settings = Config.Coops[object:GetAttribute("ItemName") or object.Name]
    if not feeder or (settings.EggItem and (not egg or not slots)) then return end
    local function update()
        for _, shell in ipairs(slots and slots:GetChildren() or {}) do
            if shell:IsA("BasePart") then
                local index = tonumber(shell.Name:match("^Egg(%d+)$")) or math.huge
                shell.Transparency = index <= egg.Value and 0 or 1
            end
        end
        for _, grain in ipairs(feeder:GetChildren()) do
            if grain.Name == "Wheat" or grain.Name:match("^Grain") then
                local settings = Config.Coops[object:GetAttribute("ItemName") or object.Name]
                local filled = settings.FeedCapacity > 0 and (object:GetAttribute("FeedStock") or 0) > 0 or
                    settings.FeedCapacity == 0 and (object:GetAttribute("HungryCount") or 0) < (object:GetAttribute("AnimalCount") or 0)
                grain.Transparency = filled and 0 or 1
            end
        end
    end
    local changed = egg and egg.Changed:Connect(update)
    local eggsAdded = slots and slots.ChildAdded:Connect(update)
    local grainAdded = feeder.ChildAdded:Connect(update)
    local feeding = object.AttributeChanged:Connect(function(name)
        if name == "FeedStock" or name == "HungryCount" or name == "AnimalCount" then update() end
    end)
    local effect = object:GetAttributeChangedSignal("FeedEffectAt"):Connect(function()
        local attachment = object.PlacementRoot:FindFirstChild("FeedAttachment")
        local camera = workspace.CurrentCamera
        if not attachment or not camera or (camera.CFrame.Position - attachment.WorldPosition).Magnitude > 60 then return end
        for index = 1, 5 do
            local gui = Instance.new("BillboardGui")
            gui.Adornee = attachment
            gui.Size = UDim2.fromOffset(25, 25)
            gui.StudsOffsetWorldSpace = Vector3.new((index - 3) * 0.16, 0, 0)
            local image = Instance.new("ImageLabel")
            image.Size = UDim2.fromScale(1, 1)
            image.BackgroundTransparency = 1
            image.Image = definitions.Wheat.Icon
            image.Rotation = (index - 3) * 12
            image.Parent = gui
            gui.Parent = object.PlacementRoot
            TweenService:Create(gui, TweenInfo.new(0.65), {StudsOffsetWorldSpace = Vector3.new((index - 3) * 0.5, 1.4, 0)}):Play()
            TweenService:Create(image, TweenInfo.new(0.65), {ImageTransparency = 1, Rotation = image.Rotation + 30}):Play()
            Debris:AddItem(gui, 0.7)
        end
    end)
    coops[object] = true
    object.Destroying:Once(function()
        if changed then changed:Disconnect() end
        if eggsAdded then eggsAdded:Disconnect() end
        grainAdded:Disconnect();feeding:Disconnect();effect:Disconnect()
        coops[object] = nil
    end)
    update()
end

local function makeTimer(model, quadruped)
    local gui = Instance.new("BillboardGui")
    gui.Name = "EggTimer"
    gui.Adornee = model.PrimaryPart
    gui.Size = UDim2.fromOffset(100, 32)
    gui.StudsOffsetWorldSpace = Vector3.new(0, quadruped and 4.5 or 2.2, 0)
    gui.MaxDistance = 55
    gui.Enabled = false
    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.Size = UDim2.fromScale(1, 1)
    panel.BackgroundColor3 = Color3.fromRGB(255, 224, 160)
    panel.BorderSizePixel = 0
    panel.Parent = gui
    local text = Instance.new("TextLabel")
    text.Name = "Time"
    text.Position = UDim2.fromOffset(6, 0)
    text.Size = UDim2.new(1, -36, 1, 0)
    text.BackgroundTransparency = 1
    text.TextColor3 = Color3.fromRGB(89, 55, 26)
    text.Font = Enum.Font.FredokaOne
    text.TextSize = 18
    text.BorderSizePixel = 0
    local icon = Instance.new("ImageLabel")
    icon.Name = "StatusIcon"
    icon.Size = UDim2.fromOffset(22, 22)
    icon.AnchorPoint = Vector2.new(1, 0.5)
    icon.Position = UDim2.new(1, -5, 0.5, 0)
    icon.BackgroundTransparency = 1
    icon.Image = definitions.Egg.Icon
    icon.Parent = panel
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = panel
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.fromRGB(169, 111, 50)
    stroke.Thickness = 1.5
    stroke.Parent = panel
    text.Parent = panel
    gui.Parent = model.PrimaryPart
    return gui, text, icon, panel
end

local function bind(folder)
    if visuals[folder] or not folder:IsA("Folder") or not folder.Parent or folder.Parent.Name ~= "Animals" then return end
    local itemName = folder:GetAttribute("ItemName")
    local template = templates:FindFirstChild(itemName or "")
    local coop = folder.Parent.Parent
    if not template or not coop:IsA("Model") then return end
    local model = template:Clone()
    local root = model:GetPivot()
    local body, head = model.Body, model.Body.Head
    local quadruped = Config.Animals[itemName].Rig == "Quadruped"
    local state = {Model = model, Coop = coop, Motion = Motion.read(folder), Body = body, Head = head,
        Quadruped = quadruped, Legs = {}, BodyOffset = root:ToObjectSpace(body:GetPivot()),
        HeadOffset = body:GetPivot():ToObjectSpace(head:GetPivot()),
        Settings = Config.Animals[itemName], Sit = 0, Stride = 0}
    local legNames = quadruped and {"FrontLeftLeg", "FrontRightLeg", "BackLeftLeg", "BackRightLeg"} or {"LeftLeg", "RightLeg"}
    for index, name in ipairs(legNames) do
        table.insert(state.Legs, {Model = model[name], Offset = root:ToObjectSpace(model[name]:GetPivot()),
            Phase = (index == 1 or index == 4) and 0 or math.pi})
    end
    if quadruped then
        state.Tail = body.Tail
        state.TailOffset = body:GetPivot():ToObjectSpace(state.Tail:GetPivot())
    end
    state.Connection = folder:GetAttributeChangedSignal("Revision"):Connect(function() state.Motion = Motion.read(folder) end)
    state.Timer, state.TimerText, state.TimerIcon, state.TimerPanel = makeTimer(model, quadruped)
    visuals[folder] = state
    model.Parent = container
end

plots.DescendantAdded:Connect(function(object)
    if object:IsA("Folder") then task.defer(bind, object) end
    if object:IsA("Model") then task.defer(bindCoop, object) end
    local coop = object:FindFirstAncestorOfClass("Model")
    if coop then task.defer(bindCoop, coop) end
end)
for _, object in ipairs(plots:GetDescendants()) do
    if object:IsA("Folder") then bind(object)
    elseif object:IsA("Model") then bindCoop(object) end
end

RunService.RenderStepped:Connect(function(dt)
    local camera = workspace.CurrentCamera
    if not camera then return end
    local now = workspace:GetServerTimeNow()
    for folder, state in pairs(visuals) do
        if not folder:IsDescendantOf(plots) or not state.Coop.Parent then
            state.Connection:Disconnect();state.Model:Destroy();visuals[folder] = nil
        else
            local motion = state.Motion
            local position = state.Coop:GetPivot():PointToWorldSpace(Motion.position(motion, now))
            local visible = motion.Activity ~= "Waiting" and (position - camera.CFrame.Position).Magnitude <= Config.VisualDistance
            if not visible then
                state.Model.Parent = nil
            else
                local age = math.max(0, now - motion.StartedAt)
                local alpha = 1 - math.exp(-dt * 12)
                state.Sit += ((motion.Activity == "Sit" and 1 or 0) - state.Sit) * alpha
                state.Stride += ((motion.Activity == "Walk" and 1 or 0) - state.Stride) * alpha
                local step = math.sin(age * state.Settings.StepRate + motion.Phase) * state.Stride
                local frame = state.Coop:GetPivot() * CFrame.new(Motion.position(motion, now)) * CFrame.Angles(0, Motion.yaw(motion, now), 0)
                state.Model:PivotTo(frame)
                local body = frame * state.BodyOffset * CFrame.new(0, math.abs(step) * 0.035 - state.Sit *
                    (state.Quadruped and 1 or 0.32), 0) * CFrame.Angles(0, 0, step * (state.Quadruped and 0.015 or 0.045))
                state.Body:PivotTo(body)
                local look = math.sin(age * 1.6 + motion.Phase) * (motion.Activity == "Look" and 0.55 or 0.12)
                local peck = motion.Activity == "Eat" and (state.Quadruped and
                    0.18 + math.sin(age * 4) * 0.06 or -0.65 + math.sin(age * 12) * 0.25) or step * 0.06
                state.Head:PivotTo(body * state.HeadOffset * CFrame.Angles(peck, look, 0))
                for index, leg in ipairs(state.Legs) do
                    local swing = math.sin(age * state.Settings.StepRate + motion.Phase + leg.Phase) * state.Stride
                    local fold = state.Quadruped and (index <= 2 and 1.2 or -1.2) or -1.2
                    leg.Model:PivotTo(frame * leg.Offset * CFrame.new(0, state.Quadruped and -state.Sit * 0.65 or 0, 0) *
                        CFrame.Angles(swing * (state.Quadruped and 0.35 or 0.55) + state.Sit * fold, 0, 0))
                end
                if state.Tail then
                    state.Tail:PivotTo(body * state.TailOffset * CFrame.Angles(0, 0, math.sin(age * 1.7 + motion.Phase) * 0.16))
                end
                state.Model.Parent = container
                local readyAt = folder:GetAttribute("EggReadyAt")
                local fedUntil = folder:GetAttribute("FedUntil") or 0
                local hungry = folder:GetAttribute("Hungry") == true or fedUntil <= now
                local remaining = readyAt and readyAt - math.min(now, fedUntil) or folder:GetAttribute("WorkRemaining") or 0
                if state.Quadruped then remaining = math.max(0, fedUntil - now) end
                local seconds = math.max(0, math.ceil(remaining))
                local text = string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
                if not hungry and folder:GetAttribute("WaitingForSpace") then text = "Full" end
                state.Timer.Enabled = true
                state.TimerPanel.BackgroundColor3 = hungry and Color3.fromRGB(177, 65, 47) or Color3.fromRGB(255, 224, 160)
                state.TimerText.TextColor3 = hungry and Color3.fromRGB(255, 242, 214) or Color3.fromRGB(89, 55, 26)
                state.TimerIcon.Image = (hungry or state.Quadruped) and definitions.Wheat.Icon or definitions.Egg.Icon
                if state.TimerText.Text ~= text then state.TimerText.Text = text end
            end
        end
    end
end)
