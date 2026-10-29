local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local command = remotes:WaitForChild("ProductionCommand")
local View = require(ReplicatedStorage:WaitForChild("Production"):WaitForChild("ProductionGuiView"))
local view = View.new(playerGui:WaitForChild("ProductionGui"))
local controls = require(player.PlayerScripts:WaitForChild("PlayerModule")):GetControls()
local placement = require(ReplicatedStorage.PlacementScripts.PlacementController)
local inventory = player:WaitForChild("Inventory")
local current
local cameraSnapshot
local returnTween
local cameraGeneration = 0
local eDown = false
local pointerInput
local lastHeld = false
local pendingSelect = false

local function send(action, value)
    if current then command:FireServer(action, current.SessionId, value) end
end

local function updateHeld()
    local held = eDown or pointerInput ~= nil
    if held == lastHeld then return end
    lastHeld = held
    send("Hold", held)
end

local function releaseHold()
    eDown, pointerInput = false, nil
    if lastHeld then lastHeld = false; send("Hold", false) end
end

local function refresh()
    if not current then return end
    view:UpdateMaterials(inventory)
    view:UpdateState(current)
end

local function cameraTarget()
    local station = current and current.Station
    local root = station and station:FindFirstChild("PlacementRoot")
    if not root then return end
    local portrait = view.Portrait
    local point = root:FindFirstChild(portrait and "CameraPointPortrait" or "CameraPoint") or root:FindFirstChild("CameraPoint")
    local target = root:FindFirstChild("CameraTarget")
    if not point or not target then return end
    local camera = workspace.CurrentCamera
    local frame = CFrame.lookAt(point.WorldPosition, target.WorldPosition)
    local distance = (point.WorldPosition - target.WorldPosition).Magnitude
    local fov = station:GetAttribute("ProductionFieldOfView") or 50
    local halfHeight = distance * math.tan(math.rad(fov / 2))
    -- Оставляем место панели: действие слева на ПК, сверху в портретном режиме.
    local offset
    if portrait then
        offset = -frame.UpVector * halfHeight * 0.35
    else
        local aspect = camera.ViewportSize.X / math.max(camera.ViewportSize.Y, 1)
        offset = frame.RightVector * halfHeight * aspect * 0.30
    end
    return frame + offset, fov
end

local function finishCameraRestore()
    if not cameraSnapshot then return end
    local snapshot = cameraSnapshot
    cameraSnapshot = nil
    local camera = snapshot.Camera
    if camera and camera.Parent then
        camera.CFrame, camera.Focus, camera.FieldOfView = snapshot.CFrame, snapshot.Focus, snapshot.FieldOfView
        local subject = snapshot.Subject
        if not subject or not subject.Parent then
            subject = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        end
        camera.CameraSubject = subject
        camera.CameraType = snapshot.Type
    end
    UserInputService.MouseBehavior = snapshot.MouseBehavior
    UserInputService.MouseIconEnabled = snapshot.MouseIconEnabled
end

local function restoreCamera(immediate)
    cameraGeneration = cameraGeneration + 1
    local generation = cameraGeneration
    RunService:UnbindFromRenderStep("ProductionCamera")
    if returnTween then returnTween:Cancel(); returnTween = nil end
    if immediate or not cameraSnapshot or not cameraSnapshot.Camera.Parent then
        finishCameraRestore()
        return
    end
    returnTween = TweenService:Create(cameraSnapshot.Camera, TweenInfo.new(0.3, Enum.EasingStyle.Quad),
        {CFrame = cameraSnapshot.CFrame, Focus = cameraSnapshot.Focus, FieldOfView = cameraSnapshot.FieldOfView})
    returnTween:Play()
    task.delay(0.3, function() if generation == cameraGeneration then finishCameraRestore() end end)
end

local function closeMode(immediate, notifyServer)
    if not current then
        if immediate then restoreCamera(true) end
        return
    end
    local old = current
    releaseHold()
    if notifyServer then send("Close") end
    current, pendingSelect = nil, false
    ContextActionService:UnbindAction("ProductionBlockSlots")
    ProximityPromptService.Enabled = old.PromptsEnabled
    if old.ControlsEnabled then controls:Enable() end
    for gui, enabled in pairs(old.OtherGuis) do if gui.Parent then gui.Enabled = enabled end end
    for _, connection in ipairs(old.Connections) do connection:Disconnect() end
    view:Hide(immediate)
    restoreCamera(immediate)
end

local function openMode(data)
    if current then closeMode(true, false) end
    if cameraSnapshot then restoreCamera(true) end
    local station = data.Station
    if not station or not station:IsDescendantOf(workspace) then return end
    current = {
        SessionId = data.SessionId, Station = station, Busy = false, Held = false,
        StartedAt = 0, Duration = 0, OtherGuis = {}, Connections = {},
        PromptsEnabled = ProximityPromptService.Enabled, ControlsEnabled = controls.controlsEnabled,
    }
    placement.cancelPlacement()
    controls:Disable()
    ProximityPromptService.Enabled = false
    for _, name in ipairs({"InventoryGui", "BuyGui", "SellGui", "DeleteConfirmGui"}) do
        local gui = playerGui:FindFirstChild(name)
        if gui and gui:IsA("ScreenGui") then current.OtherGuis[gui] = gui.Enabled; gui.Enabled = false end
    end
    ContextActionService:BindActionAtPriority("ProductionBlockSlots", function() return Enum.ContextActionResult.Sink end,
        false, 3000, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three,
        Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six)
    eDown, pointerInput, lastHeld, pendingSelect = false, nil, false, false
    -- Нажатие E, открывшее prompt, уже началось до этой сессии.
    current.EArmed = not UserInputService:IsKeyDown(Enum.KeyCode.E)
    view:ShowRecipes(station, function(recipeId)
        if not current or current.Busy or pendingSelect then return end
        releaseHold()
        pendingSelect = true
        send("Select", recipeId)
    end)
    view:SetRecipe(nil)
    view:Show()
    local camera = workspace.CurrentCamera
    cameraSnapshot = {
        Camera = camera, Type = camera.CameraType, Subject = camera.CameraSubject,
        CFrame = camera.CFrame, Focus = camera.Focus, FieldOfView = camera.FieldOfView,
        MouseBehavior = UserInputService.MouseBehavior, MouseIconEnabled = UserInputService.MouseIconEnabled,
    }
    camera.CameraType = Enum.CameraType.Scriptable
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = true
    RunService:BindToRenderStep("ProductionCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
        if not current then return end
        local frame, fov = cameraTarget()
        if frame then
            camera.CFrame = camera.CFrame:Lerp(frame, 1 - math.exp(-dt * 10))
            camera.FieldOfView = camera.FieldOfView + (fov - camera.FieldOfView) * (1 - math.exp(-dt * 10))
        end
        view:UpdateProgress(current)
    end)
    table.insert(current.Connections, station.AncestryChanged:Connect(function()
        if current and not station:IsDescendantOf(workspace) then closeMode(true, true) end
    end))
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then table.insert(current.Connections, humanoid.Died:Connect(function() closeMode(true, true) end)) end
    refresh()
end

remotes.ProductionState.OnClientEvent:Connect(function(action, data)
    if action == "Opened" then
        openMode(data)
    elseif action == "State" and current and data.SessionId == current.SessionId then
        pendingSelect = false
        if current.RecipeId ~= data.RecipeId then view:SetRecipe(data.RecipeId) end
        for _, name in ipairs({"RecipeId", "Busy", "Held", "StartedAt", "Duration", "Message"}) do current[name] = data[name] end
        refresh()
    elseif action == "Closed" and current and data.SessionId == current.SessionId then
        closeMode(data.Reason ~= "Exit", false)
    elseif action == "Error" then
        warn("[Production mode]", data.Message)
    end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if not current or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.Q then closeMode(false, true); return end
    if input.KeyCode == Enum.KeyCode.E and not processed and current.EArmed
        and current.RecipeId and not pendingSelect and not eDown then
        eDown = true
        updateHeld()
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.E then
        if current then current.EArmed = true end
        eDown = false
        updateHeld()
    elseif input == pointerInput or (pointerInput and input.UserInputType == Enum.UserInputType.MouseButton1
        and pointerInput.UserInputType == Enum.UserInputType.MouseButton1) then
        pointerInput = nil
        updateHeld()
    end
end)
view.Work.StartButton.InputBegan:Connect(function(input)
    if not current or not current.RecipeId or pendingSelect or pointerInput then return end
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        pointerInput = input
        updateHeld()
    end
end)
view.Work.StartButton.MouseLeave:Connect(function()
    if pointerInput and pointerInput.UserInputType == Enum.UserInputType.MouseButton1 then pointerInput = nil; updateHeld() end
end)
view.Work.BackButton.Activated:Connect(function()
    if not current or current.Busy or pendingSelect then return end
    releaseHold()
    pendingSelect = true
    send("Select", nil)
end)
view.Root.CloseButton.Activated:Connect(function() closeMode(false, true) end)
UserInputService.WindowFocusReleased:Connect(releaseHold)
player.CharacterRemoving:Connect(function() closeMode(true, true) end)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() closeMode(true, true) end)

local function watchValue(value)
    if value:IsA("ValueBase") then value.Changed:Connect(refresh) end
end
for _, value in ipairs(inventory:GetDescendants()) do watchValue(value) end
inventory.DescendantAdded:Connect(function(value) watchValue(value); refresh() end)
inventory.DescendantRemoving:Connect(function() task.defer(refresh) end)
script.Destroying:Connect(function() closeMode(true, true) end)
