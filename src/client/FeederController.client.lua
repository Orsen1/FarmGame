local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local inventory = player:WaitForChild("Inventory")
local config = require(ReplicatedStorage.Configs.AnimalConfig)
local definitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local station, pending

local function make(class, parent, properties)
    local object = Instance.new(class)
    for name, value in pairs(properties) do object[name] = value end
    object.Parent = parent
    return object
end

local function round(object, radius)
    make("UICorner", object, {CornerRadius = UDim.new(0, radius)})
end

local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), {Name = "FeederGui", ResetOnSpawn = false,
    Enabled = false, DisplayOrder = 25, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets})
local panel = make("CanvasGroup", gui, {Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(380, 240),
    BackgroundColor3 = Color3.fromRGB(255, 221, 151), BorderSizePixel = 0})
round(panel, 18)
make("UIStroke", panel, {Color = Color3.fromRGB(126, 79, 39), Thickness = 3,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
local scale = make("UIScale", panel, {})
make("ImageLabel", panel, {Name = "WheatIcon", BackgroundTransparency = 1, Image = definitions.Wheat.Icon,
    Position = UDim2.fromOffset(18, 15), Size = UDim2.fromOffset(55, 55), ScaleType = Enum.ScaleType.Fit})
local function label(name, text, x, y, w, h, size)
    return make("TextLabel", panel, {Name = name, Text = text, Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(89, 55, 26),
        Font = Enum.Font.FredokaOne, TextSize = size, TextXAlignment = Enum.TextXAlignment.Left})
end
label("Title", "Feeder", 84, 17, 220, 30, 25)
local stock = label("Stock", "", 84, 48, 220, 24, 17)
local owned = label("Owned", "", 20, 102, 340, 24, 16)
local track = make("Frame", panel, {Name = "Track", Position = UDim2.fromOffset(20, 82),
    Size = UDim2.fromOffset(340, 9), BackgroundColor3 = Color3.fromRGB(216, 173, 107), BorderSizePixel = 0})
round(track, 5)
local fill = make("Frame", track, {Name = "Fill", Size = UDim2.fromScale(0, 1),
    BackgroundColor3 = Color3.fromRGB(114, 154, 68), BorderSizePixel = 0})
round(fill, 5)
local buttons = {}
local function close()
    station, pending = nil, nil
    gui.Enabled = false
    player:SetAttribute("FeederOpen", false)
end
local exit = make("TextButton", panel, {Name = "Close", Text = "X", Font = Enum.Font.FredokaOne, TextSize = 23,
    TextColor3 = Color3.fromRGB(255, 241, 208), BackgroundColor3 = Color3.fromRGB(176, 69, 47),
    BorderSizePixel = 0, Position = UDim2.fromOffset(318, 14), Size = UDim2.fromOffset(54, 54)})
round(exit, 12)
exit.Activated:Connect(close)
local status = label("Status", "Wheat cannot be taken back.", 20, 202, 340, 24, 14)

local function refresh()
    if not station then return end
    local settings = config.Coops[station:GetAttribute("ItemName") or station.Name]
    if not settings then close();return end
    local count = station:GetAttribute("FeedStock") or 0
    local wheat = 0
    for _, slot in ipairs(inventory:GetChildren()) do
        if slot.ItemName.Value == settings.FeedItem then wheat += slot.Amount.Value end
    end
    stock.Text = string.format("Wheat: %d / %d", count, settings.FeedCapacity)
    owned.Text = string.format("In your inventory: %d", wheat)
    TweenService:Create(fill, TweenInfo.new(0.15), {Size = UDim2.fromScale(count / settings.FeedCapacity, 1)}):Play()
    for _, button in ipairs(buttons) do
        local enabled = not pending and wheat > 0 and count < settings.FeedCapacity
        button.Active = enabled
        button.BackgroundColor3 = enabled and Color3.fromRGB(91, 148, 57) or Color3.fromRGB(173, 158, 113)
    end
end

for index, amount in ipairs({1, 10, "Max"}) do
    local button = make("TextButton", panel, {Name = "Add" .. amount, Text = amount == "Max" and "Max" or "+" .. amount,
        Font = Enum.Font.FredokaOne, TextSize = 23, TextColor3 = Color3.fromRGB(255, 246, 221),
        BackgroundColor3 = Color3.fromRGB(91, 148, 57), BorderSizePixel = 0,
        Position = UDim2.fromOffset(20 + (index - 1) * 116, 140), Size = UDim2.fromOffset(108, 54)})
    round(button, 12)
    local buttonScale = make("UIScale", button, {})
    table.insert(buttons, button)
    button.Activated:Connect(function()
        if not station or pending or not button.Active then return end
        pending = true
        buttonScale.Scale = 0.94
        TweenService:Create(buttonScale, TweenInfo.new(0.18, Enum.EasingStyle.Back), {Scale = 1}):Play()
        remotes.AnimalCommand:FireServer(station, amount)
        refresh()
    end)
end

remotes.AnimalFeedback.OnClientEvent:Connect(function(object, success, message)
    if success and message == "OpenFeeder" then
        local shop = player.PlayerGui:FindFirstChild("BuyGui")
        if shop and shop.Enabled and shop.MainFrame.Visible then return end
        station, pending = object, false
        status.Text = "Wheat cannot be taken back."
        status.TextColor3 = Color3.fromRGB(89, 55, 26)
        player:SetAttribute("FeederOpen", true)
        gui.Enabled = true
        panel.GroupTransparency = 1
        panel.Position = UDim2.fromScale(0.5, 0.5)
        TweenService:Create(panel, TweenInfo.new(0.2), {GroupTransparency = 0,
            Position = UDim2.fromScale(0.5, 0.46)}):Play()
        refresh()
    elseif station == object then
        pending = false
        status.Text = message
        status.TextColor3 = success and Color3.fromRGB(75, 115, 47) or Color3.fromRGB(170, 55, 38)
        refresh()
    end
end)

for _, slot in ipairs(inventory:GetChildren()) do
    slot.ItemName.Changed:Connect(refresh)
    slot.Amount.Changed:Connect(refresh)
end
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.Q then close() end
end)
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
    if not station then return end
    elapsed += dt
    if elapsed < 0.2 then return end
    elapsed = 0
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local prompt = station:FindFirstChild("FeedPrompt", true)
    local shop = player.PlayerGui:FindFirstChild("BuyGui")
    if not station:IsDescendantOf(workspace) or not root or not humanoid or humanoid.Health <= 0 or not prompt or
        player:GetAttribute("DataLoaded") ~= true or station:GetAttribute("OwnerUserId") ~= player.UserId or
        (root.Position - prompt.Parent.WorldPosition).Magnitude > prompt.MaxActivationDistance or
        (shop and shop.Enabled and shop.MainFrame.Visible) then close();return end
    scale.Scale = math.max(0.5, math.min(1, (gui.AbsoluteSize.X - 24) / 380, (gui.AbsoluteSize.Y - 120) / 240))
    refresh()
end)
