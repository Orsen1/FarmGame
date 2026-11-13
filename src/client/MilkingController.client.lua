local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local PromptView = require(script.Parent:WaitForChild("AnimalShopPromptView"))
local Config = require(ReplicatedStorage.Configs.AnimalConfig)
local definitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local event = ReplicatedStorage.RemoteEvents:WaitForChild("MilkingEvent")
local controls = require(player.PlayerScripts:WaitForChild("PlayerModule")):GetControls()
local views = {}
local current
local restore
local cameraTween
local generation = 0

local function make(class, parent, properties)
    local instance = Instance.new(class)
    for name, value in pairs(properties) do instance[name] = value end
    instance.Parent = parent
    return instance
end

local function rounded(instance, radius)
    make("UICorner", instance, {CornerRadius = UDim.new(0, radius)})
end

local gui = make("ScreenGui", playerGui, {Name = "MilkingGui", ResetOnSpawn = false, DisplayOrder = 35,
    ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, Enabled = false})
local panel = make("CanvasGroup", gui, {Name = "Progress", AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -100), Size = UDim2.fromOffset(270, 86),
    BackgroundColor3 = Color3.fromRGB(255, 220, 150), BorderSizePixel = 0})
rounded(panel, 14)
make("UISizeConstraint", panel, {MaxSize = Vector2.new(320, 100)})
make("UIStroke", panel, {Color = Color3.fromRGB(169, 111, 50), Thickness = 2,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
local title = make("TextLabel", panel, {Name = "Status", BackgroundTransparency = 1,
    Position = UDim2.fromOffset(50, 8), Size = UDim2.new(1, -90, 0, 30), Text = "Milking...",
    Font = Enum.Font.FredokaOne, TextSize = 21, TextColor3 = Color3.fromRGB(89, 55, 26)})
local icon = make("ImageLabel", panel, {Name = "MilkIcon", BackgroundTransparency = 1,
    Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(38, 38), Image = definitions.MilkBucket.Icon})
local close = make("TextButton", panel, {Name = "Cancel", AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -3, 0, 3), Size = UDim2.fromOffset(44, 44), BackgroundTransparency = 1,
    Text = "X", Font = Enum.Font.FredokaOne, TextSize = 20, TextColor3 = Color3.fromRGB(145, 67, 40)})
local track = make("Frame", panel, {Name = "Track", Position = UDim2.fromOffset(14, 48),
    Size = UDim2.new(1, -28, 0, 17), BackgroundColor3 = Color3.fromRGB(211, 165, 103), BorderSizePixel = 0})
rounded(track, 8)
local fill = make("Frame", track, {Name = "Fill", Size = UDim2.fromScale(0, 1),
    BackgroundColor3 = Color3.fromRGB(255, 249, 226), BorderSizePixel = 0})
rounded(fill, 8)

local function hidePrompt(prompt)
    if views[prompt] then views[prompt].destroy();views[prompt] = nil end
end

local function finishRestore()
    if not restore then return end
    local saved = restore
    restore = nil
    if saved.Camera.Parent then
        local subject = saved.Subject
        if not subject or not subject.Parent then subject = player.Character and player.Character:FindFirstChildOfClass("Humanoid") end
        saved.Camera.CFrame = saved.CFrame
        saved.Camera.Focus = saved.Focus
        saved.Camera.CameraSubject = subject
        saved.Camera.FieldOfView = saved.FieldOfView
        saved.Camera.CameraType = saved.Type
    end
    local behavior = saved.MouseBehavior
    if behavior == Enum.MouseBehavior.LockCurrentPosition and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        behavior = Enum.MouseBehavior.Default
    end
    UserInputService.MouseBehavior = behavior
    UserInputService.MouseIconEnabled = saved.MouseIconEnabled
end

local function closeMode(immediate, message)
    if not current then
        if immediate then
            generation += 1
            if cameraTween then cameraTween:Cancel();cameraTween = nil end
            finishRestore()
        end
        return
    end
    local old = current
    current = nil
    generation += 1
    local token = generation
    ContextActionService:UnbindAction("MilkingInput")
    ProximityPromptService.Enabled = old.PromptsEnabled
    if old.ControlsEnabled then controls:Enable() end
    for other, enabled in pairs(old.Guis) do if other.Parent then other.Enabled = enabled end end
    for _, connection in ipairs(old.Connections) do connection:Disconnect() end
    if cameraTween then cameraTween:Cancel();cameraTween = nil end
    restore = old.Camera
    title.Text = message or ""
    if immediate then
        gui.Enabled = false
        finishRestore()
    else
        TweenService:Create(panel, TweenInfo.new(0.3), {GroupTransparency = 1}):Play()
        cameraTween = TweenService:Create(restore.Camera, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
            CFrame = restore.CFrame, Focus = restore.Focus, FieldOfView = restore.FieldOfView})
        cameraTween:Play()
        task.delay(0.35, function()
            if token == generation then gui.Enabled = false;finishRestore() end
        end)
    end
end

local function cancel(immediate)
    if not current then return end
    event:FireServer("Cancel")
    closeMode(immediate ~= false)
end

local function open(folder, startedAt, duration, frame)
    closeMode(true)
    if not folder or not folder:IsDescendantOf(workspace) then event:FireServer("Cancel");return end
    local camera = workspace.CurrentCamera
    if not camera then event:FireServer("Cancel");return end
    local home = folder.Parent.Parent
    local settings = Config.Coops[home:GetAttribute("ItemName") or home.Name].Milking
    current = {Folder = folder, Home = home, StartedAt = startedAt, Duration = duration, Settings = settings, Frame = frame,
        PromptsEnabled = ProximityPromptService.Enabled, ControlsEnabled = controls.controlsEnabled, Connections = {}, Guis = {},
        Camera = {Camera = camera, CFrame = camera.CFrame, Focus = camera.Focus, Subject = camera.CameraSubject,
            Type = camera.CameraType, FieldOfView = camera.FieldOfView,
            MouseBehavior = UserInputService.MouseBehavior, MouseIconEnabled = UserInputService.MouseIconEnabled}}
    controls:Disable()
    ProximityPromptService.Enabled = false
    for prompt in pairs(views) do hidePrompt(prompt) end
    for _, name in ipairs({"InventoryGui", "BuyGui", "SellGui"}) do
        local other = playerGui:FindFirstChild(name)
        if other then current.Guis[other] = other.Enabled;other.Enabled = false end
    end
    ContextActionService:BindActionAtPriority("MilkingInput", function(_, state, input)
        if input.KeyCode == Enum.KeyCode.Q and state == Enum.UserInputState.Begin then cancel(false) end
        return Enum.ContextActionResult.Sink
    end, false, 3100, Enum.KeyCode.Q, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three,
        Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six)
    camera.CameraType = Enum.CameraType.Scriptable
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = true
    local side = folder:GetAttribute("MilkingSide") or 1
    local offset = settings.CameraOffset
    local viewport = camera.ViewportSize
    local cameraScale = math.max(1, 0.9 / math.max(0.3, viewport.X / viewport.Y))
    offset *= cameraScale
    local focus = settings.CameraTarget
    local target = frame:PointToWorldSpace(Vector3.new(focus.X * side, focus.Y, focus.Z))
    local position = frame:PointToWorldSpace(Vector3.new(offset.X * side, offset.Y, offset.Z))
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances = {player.Character}
    ray.RespectCanCollide = true
    for _, candidate in ipairs({Vector3.new(offset.X * side, offset.Y, offset.Z),
        Vector3.new(offset.X * side, offset.Y, -offset.Z), Vector3.new(offset.X * side, 5 * cameraScale, 0),
        Vector3.new(6 * side, 8, -6) * cameraScale}) do
        local point = frame:PointToWorldSpace(candidate)
        if not workspace:Raycast(target, point - target, ray) then position = point;break end
    end
    cameraTween = TweenService:Create(camera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
        CFrame = CFrame.lookAt(position, target), Focus = CFrame.new(target), FieldOfView = settings.FieldOfView})
    cameraTween:Play()
    panel.GroupTransparency = 1
    fill.Size = UDim2.fromScale(0, 1)
    title.Text = "Milking..."
    gui.Enabled = true
    TweenService:Create(panel, TweenInfo.new(0.2), {GroupTransparency = 0}):Play()
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then table.insert(current.Connections, humanoid.Died:Connect(cancel)) end
    table.insert(current.Connections, folder.AncestryChanged:Connect(function()
        if not folder:IsDescendantOf(workspace) then cancel() end
    end))
end

ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
    if prompt.Name ~= "MilkPrompt" or not prompt:FindFirstChild("Animal") then return end
    hidePrompt(prompt)
    views[prompt] = PromptView.show(playerGui, prompt, inputType)
end)
ProximityPromptService.PromptHidden:Connect(hidePrompt)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
    if prompt.Name == "MilkPrompt" and prompt:FindFirstChild("Animal") and not current then
        event:FireServer("Start", prompt.Animal.Value)
    end
end)
event.OnClientEvent:Connect(function(action, value, startedAt, duration, frame)
    if action == "Started" then open(value, startedAt, duration, frame)
    elseif action == "Finished" then closeMode(false, value)
    elseif action == "Rejected" then
        for _, view in pairs(views) do view.message(value, false) end
    end
end)
close.Activated:Connect(function() cancel(false) end)
player.CharacterRemoving:Connect(cancel)
player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
    if player:GetAttribute("DataLoaded") ~= true then cancel() end
end)
RunService.RenderStepped:Connect(function()
    if not current then return end
    local now = workspace:GetServerTimeNow()
    if now > current.StartedAt + current.Duration + 2 or not current.Home:IsDescendantOf(workspace) or
        current.Home:GetAttribute("OwnerUserId") ~= player.UserId then cancel();return end
    local alpha = math.clamp((now - current.StartedAt) / current.Duration, 0, 1)
    fill.Size = UDim2.fromScale(alpha, 1)
    title.Text = string.format("Milking... %ds", math.max(0, math.ceil(current.Duration - now + current.StartedAt)))
    local viewport = workspace.CurrentCamera.ViewportSize
    panel.Size = UDim2.fromOffset(math.min(270, viewport.X - 24), 86)
    panel.Position = UDim2.new(0.5, 0, 1, viewport.X < viewport.Y and -120 or -34)
end)
