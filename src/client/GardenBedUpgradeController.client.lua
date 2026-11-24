local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local money = player:WaitForChild("PlayerData"):WaitForChild("MoneyCents")
local definitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local config = require(ReplicatedStorage.Configs.GardenBedConfig)
local placement = require(ReplicatedStorage.PlacementScripts.PlacementRules)
local remote = ReplicatedStorage.RemoteEvents:WaitForChild("GardenBedUpgrade")
local plots = workspace:WaitForChild("Plots")

local ink, paper = Color3.fromRGB(94, 59, 32), Color3.fromRGB(255, 236, 190)
local green, red = Color3.fromRGB(83, 143, 67), Color3.fromRGB(180, 69, 48)
local disabled = Color3.fromRGB(180, 150, 113)
local current, pending, message
local elapsed = 0

local function make(class, parent, properties)
    local instance = Instance.new(class)
    for key, value in pairs(properties) do instance[key] = value end
    instance.Parent = parent
    return instance
end

local function trim(parent, radius)
    make("UICorner", parent, {CornerRadius = UDim.new(0, radius)})
    make("UIStroke", parent, {Color = ink, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end

local gui = make("ScreenGui", playerGui, {Name = "GardenBedUpgradeGui", ResetOnSpawn = false, Enabled = false,
    DisplayOrder = 45, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets})
local card = make("Frame", gui, {Name = "Panel", Size = UDim2.new(.94, 0, 0, 152), BorderSizePixel = 0,
    BackgroundColor3 = paper, AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, 0, 8)})
make("UISizeConstraint", card, {MaxSize = Vector2.new(398, 152)})
trim(card, 12)

local function label(name, y, height, fontSize, right)
    return make("TextLabel", card, {Name = name, Text = "", Position = UDim2.fromOffset(14, y),
        Size = UDim2.new(1, -right, 0, height), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
        BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextSize = fontSize, TextColor3 = ink})
end

local title = label("Title", 7, 31, 21, 64)
local capacity = label("Capacity", 37, 21, 16, 28)
local status = label("Status", 61, 29, 14, 28)
local close = make("TextButton", card, {Name = "Close", Size = UDim2.fromOffset(44, 44),
    Position = UDim2.new(1, -50, 0, 5), BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(232, 196, 144),
    Text = "X", Font = Enum.Font.FredokaOne, TextSize = 18, TextColor3 = ink})
trim(close, 8)

local confirm = make("TextButton", card, {Name = "Confirm", Size = UDim2.new(1, -28, 0, 44),
    Position = UDim2.fromOffset(14, 96), BorderSizePixel = 0, BackgroundColor3 = green,
    Text = "", Font = Enum.Font.FredokaOne, TextSize = 18, TextColor3 = paper})
trim(confirm, 8)
local marker = make("Part", nil, {Name = "GardenBedExpansionPreview", Anchored = true, CanCollide = false,
    CanTouch = false, CanQuery = false, CastShadow = false, Transparency = .55, Material = Enum.Material.SmoothPlastic})
local border = make("SelectionBox", marker, {Adornee = marker, LineThickness = .045, SurfaceTransparency = 1})

local function hide(text)
    current, pending = nil, nil
    message = text
    marker.Parent = nil
    player:SetAttribute("BedUpgradeOpen", false)
    gui.Enabled = text ~= nil
    if text then
        status.Text, status.TextColor3 = text, green
        confirm.Interactable = false
        confirm.Text, confirm.BackgroundColor3 = "Complete", disabled
        task.delay(1.25, function()
            if not current and message == text then hide() end
        end)
    end
end

local function refresh()
    local offer = current
    if not offer then return end
    local bed, level = offer.Bed, offer.Level
    local plot = plots:FindFirstChild(player:GetAttribute("PlotName") or "")
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local prompt = bed:FindFirstChild("ActionPrompt", true)
    if not plot or bed.Parent ~= plot:FindFirstChild("PlacedObjects") or not root or not humanoid or humanoid.Health <= 0 or
        not prompt or (root.Position - prompt.Parent.WorldPosition).Magnitude > prompt.MaxActivationDistance + .15 or
        (bed:GetAttribute("BedLevel") or 1) > level and not pending or player:GetAttribute("DataLoaded") ~= true then
        hide()
        return
    end

    local box, size, valid, reason = placement.getBedExpansion(plot, bed, offer.Item, level + 1, character)
    marker.Size = Vector3.new(size.X, .13, size.Z)
    marker.CFrame = box * CFrame.new(0, size.Y / 2 + .08, 0)
    marker.Color = valid and green or red
    border.Color3 = marker.Color
    marker.Parent = workspace

    local canPay = money.Value >= offer.Price
    confirm.Interactable = valid and canPay and not pending
    confirm.BackgroundColor3 = confirm.Interactable and green or disabled
    confirm.Text = pending and "Expanding..." or string.format("Expand for $%.2f", offer.Price / 100)
    status.Text = pending and "Checking space..." or not valid and reason or message or not canPay and "Not enough money." or
        "Your planted crops will keep growing."
    status.TextColor3 = (not valid or not canPay or message) and red or ink
end

remote.OnClientEvent:Connect(function(action, bed, level, success, result)
    if action == "Preview" and bed then
        local item = bed:GetAttribute("ItemName") or bed.Name
        local definition = config.Types[item]
        local price = definition and definition.UpgradePrices[level]
        if not price then return end
        current, pending, message = {Bed = bed, Item = item, Level = level, Price = price}, nil, nil
        title.Text = "Expand " .. definitions[item].DisplayName
        capacity.Text = string.format("%d to %d planting spots", level * definition.SpotsPerRow,
            (level + 1) * definition.SpotsPerRow)
        gui.Enabled = true
        player:SetAttribute("BedUpgradeOpen", true)
        refresh()
    elseif action == "Result" and current and current.Bed == bed and current.Level == level then
        if success then
            hide(result)
        else
            pending, message = nil, result
            refresh()
        end
    end
end)

confirm.Activated:Connect(function()
    refresh()
    if not current or not confirm.Interactable then return end
    local offer = current
    pending, message = true, nil
    remote:FireServer(offer.Bed, offer.Level)
    refresh()
    task.delay(5, function()
        if current == offer and pending then
            pending, message = nil, "No response. Check the bed before trying again."
            refresh()
        end
    end)
end)
close.Activated:Connect(function() hide() end)
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and current and input.KeyCode == Enum.KeyCode.Q then hide() end
end)
RunService.Heartbeat:Connect(function(dt)
    if not current then return end
    elapsed += dt
    if elapsed < .12 then return end
    elapsed = 0
    refresh()
end)
