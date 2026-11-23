local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage.Configs.LaboratoryConfig)
local remote = ReplicatedStorage.RemoteEvents:WaitForChild("LaboratoryEvent")
local money = player:WaitForChild("PlayerData"):WaitForChild("MoneyCents")
local ink = Color3.fromRGB(91, 57, 34)
local paper = Color3.fromRGB(255, 237, 195)
local green = Color3.fromRGB(99, 145, 67)
local selected, current, pending = "Yield", nil, false
local generation = 0
local handled = 0
local tabs = {}
local refresh

local function make(class, parent, properties)
    local object = Instance.new(class)
    for name, value in pairs(properties) do object[name] = value end
    object.Parent = parent
    return object
end

local function round(object, radius)
    make("UICorner", object, {CornerRadius = UDim.new(0, radius or 12)})
end

local function outline(object, color, width)
    make("UIStroke", object, {Color = color or Color3.fromRGB(174, 122, 67),
        Thickness = width or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end

local function text(parent, name, value, size)
    return make("TextLabel", parent, {Name = name, Text = value, TextSize = size or 18,
        Font = Enum.Font.FredokaOne, TextColor3 = ink, TextWrapped = true,
        BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left})
end

local function frame(parent, name, color)
    local object = make("Frame", parent, {Name = name, BackgroundColor3 = color or paper, BorderSizePixel = 0})
    round(object)
    return object
end

local function button(parent, name, value, color)
    local object = make("TextButton", parent, {Name = name, Text = value, TextSize = 18,
        Font = Enum.Font.FredokaOne, TextColor3 = paper, BackgroundColor3 = color or green,
        BorderSizePixel = 0, AutoButtonColor = true})
    round(object)
    outline(object, ink)
    return object
end

local function tween(object, duration, properties)
    return TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
end

local function rect(object, x, y, width, height)
    object.Position = UDim2.fromOffset(x, y)
    object.Size = UDim2.fromOffset(width, height)
end

local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), {Name = "LaboratoryGui", ResetOnSpawn = false,
    DisplayOrder = 35, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
local backdrop = button(gui, "Backdrop", "", ink)
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundTransparency = .72
backdrop.Visible = false
backdrop.AutoButtonColor = false
backdrop.UIStroke:Destroy()
local panel = make("CanvasGroup", backdrop, {Name = "Panel", AnchorPoint = Vector2.new(.5, .5),
    Position = UDim2.fromScale(.5, .5), BackgroundColor3 = Color3.fromRGB(245, 208, 145),
    BorderSizePixel = 0, GroupTransparency = 1})
round(panel, 18)
outline(panel, ink, 3)
local title = text(panel, "Title", "Crop Laboratory", 27)
local close = button(panel, "Close", "X", Color3.fromRGB(169, 76, 53))
local tabBar = frame(panel, "Tracks", Color3.fromRGB(223, 182, 116))
for _, track in ipairs(Config.Tracks) do
    local tab = button(tabBar, track.Id, track.Name, paper)
    tab.TextColor3 = ink
    tab.TextSize = 16
    tabs[track.Id] = tab
    tab.Activated:Connect(function()
        if pending or selected == track.Id then return end
        selected = track.Id
        refresh()
    end)
end
local body = make("ScrollingFrame", panel, {Name = "Details", BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 4, ScrollBarImageColor3 = ink, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y})
local illustration = frame(body, "Experiment", Color3.fromRGB(236, 217, 176))
outline(illustration)
local flask = frame(illustration, "Flask", Color3.fromRGB(226, 244, 222))
flask.AnchorPoint = Vector2.new(.5, .5)
flask.Position = UDim2.fromScale(.5, .55)
flask.Size = UDim2.fromOffset(96, 108)
round(flask, 32)
outline(flask, Color3.fromRGB(108, 131, 106), 3)
local liquid = frame(flask, "Liquid", green)
liquid.Position = UDim2.fromOffset(8, 47)
liquid.Size = UDim2.new(1, -16, 0, 50)
round(liquid, 23)
local neck = frame(flask, "Neck", Color3.fromRGB(226, 244, 222))
rect(neck, 31, -30, 34, 53)
outline(neck, Color3.fromRGB(108, 131, 106), 3)
local lip = frame(flask, "Lip", Color3.fromRGB(163, 181, 138))
rect(lip, 25, -32, 46, 13)
local shine = frame(flask, "Shine", Color3.fromRGB(255, 253, 229))
rect(shine, 16, 26, 8, 31)
shine.Rotation = 15
local bubble = frame(liquid, "Bubble", Color3.fromRGB(242, 255, 218))
rect(bubble, 45, 18, 10, 10)
round(bubble, 10)
local flaskScale = make("UIScale", flask, {Scale = 1})
local trackTitle = text(body, "ResearchName", "", 24)
local levelText = text(body, "Level", "", 34)
local description = text(body, "Description", "", 16)
description.Font = Enum.Font.GothamMedium
local activeBonus = frame(body, "CurrentBonus")
outline(activeBonus)
local currentCaption = text(activeBonus, "Caption", "CURRENT", 12)
rect(currentCaption, 12, 6, 100, 16)
local currentValue = text(activeBonus, "Value", "", 18)
local nextBonus = frame(body, "NextBonus", Color3.fromRGB(227, 236, 182))
outline(nextBonus, green)
local nextCaption = text(nextBonus, "Caption", "NEXT LEVEL", 12)
rect(nextCaption, 12, 6, 120, 16)
local nextValue = text(nextBonus, "Value", "", 18)
local footer = frame(panel, "Attempt", Color3.fromRGB(255, 232, 184))
local chance = text(footer, "Chance", "", 22)
local price = text(footer, "Price", "", 21)
price.TextXAlignment = Enum.TextXAlignment.Right
local chanceCaption = text(footer, "ChanceCaption", "SUCCESS CHANCE", 11)
local priceCaption = text(footer, "PriceCaption", "PRICE PER ATTEMPT", 11)
priceCaption.TextXAlignment = Enum.TextXAlignment.Right
local attempt = button(footer, "AttemptUpgrade", "Try upgrade")
local status = text(footer, "Status", "Paid attempt. Failure keeps your level.", 13)
status.TextXAlignment = Enum.TextXAlignment.Center
status.Font = Enum.Font.GothamMedium

local function layout()
    local screen = gui.AbsoluteSize
    local width = math.min(720, screen.X - 24)
    local narrow = width < 560
    local compact = screen.Y < 450
    local short = screen.Y < 320
    local height = math.min(narrow and 620 or 540, screen.Y - 20)
    panel.Size = UDim2.fromOffset(width, height)
    rect(title, 18, 7, width - 82, 38)
    title.TextSize = narrow and 23 or 27
    rect(close, width - 54, 6, 44, 42)
    if short then
        rect(title, 18, 3, width - 82, 30)
        rect(close, width - 54, 2, 44, 38)
    end
    rect(tabBar, 12, short and 40 or compact and 50 or 59, width - 24, 46)
    for index, track in ipairs(Config.Tracks) do
        rect(tabs[track.Id], 4 + (index - 1) * (width - 32) / #Config.Tracks, 3, (width - 32) / #Config.Tracks - 5, 40)
        tabs[track.Id].TextSize = narrow and 14 or 16
    end
    local contentWidth = width - 36
    local footerWidth = width - 24
    trackTitle.TextSize, levelText.TextSize, description.TextSize = 24, 34, 16
    if compact then
        local split = math.floor(width * .67)
        contentWidth = split - 34
        footerWidth = width - split - 14
        local top = short and 92 or 105
        rect(body, 14, top, split - 26, height - top - 12)
        rect(illustration, 0, 0, 76, 110)
        flaskScale.Scale = .57
        rect(trackTitle, 88, 0, contentWidth - 88, 26)
        rect(levelText, 88, 27, contentWidth - 88, 32)
        rect(description, 88, 62, contentWidth - 88, 48)
        trackTitle.TextSize, levelText.TextSize, description.TextSize = 20, 25, 12
        local cardWidth = (contentWidth - 8) / 2
        rect(activeBonus, 0, 121, cardWidth, 61)
        rect(nextBonus, cardWidth + 8, 121, cardWidth, 61)
        body.CanvasSize = UDim2.fromOffset(0, 185)
        rect(footer, split, top, footerWidth, height - top - 12)
        rect(chanceCaption, 10, 8, footerWidth - 20, 14)
        rect(chance, 10, 23, footerWidth - 20, 27)
        rect(priceCaption, 10, 53, footerWidth - 20, 14)
        rect(price, 10, 68, footerWidth - 20, 25)
        rect(attempt, 8, 101, footerWidth - 16, 44)
        rect(status, 8, 149, footerWidth - 16, 34)
        chance.TextXAlignment = Enum.TextXAlignment.Left
        price.TextXAlignment = Enum.TextXAlignment.Left
        priceCaption.TextXAlignment = Enum.TextXAlignment.Left
        attempt.TextSize = 16
        status.TextSize = 12
        if short then
            rect(illustration, 0, 0, 64, 88)
            flaskScale.Scale = .46
            rect(trackTitle, 76, 0, contentWidth - 76, 23)
            rect(levelText, 76, 23, contentWidth - 76, 28)
            rect(description, 76, 52, contentWidth - 76, 42)
            description.TextSize = 12
            rect(activeBonus, 0, 103, cardWidth, 52)
            rect(nextBonus, cardWidth + 8, 103, cardWidth, 52)
            body.CanvasSize = UDim2.fromOffset(0, 156)
            rect(chanceCaption, 10, 3, footerWidth - 20, 12)
            rect(chance, 10, 15, footerWidth - 20, 24)
            rect(priceCaption, 10, 40, footerWidth - 20, 12)
            rect(price, 10, 52, footerWidth - 20, 24)
            rect(attempt, 8, 80, footerWidth - 16, 44)
            rect(status, 8, 127, footerWidth - 16, 26)
            status.TextSize = 11
        end
    else
        rect(body, 14, 119, width - 28, height - 267)
        if narrow then
            rect(illustration, 0, 0, 90, 105)
            flaskScale.Scale = .65
            rect(trackTitle, 104, 2, contentWidth - 104, 33)
            rect(levelText, 104, 38, contentWidth - 104, 48)
            rect(description, 0, 115, contentWidth, 51)
            rect(activeBonus, 0, 178, contentWidth, 62)
            rect(nextBonus, 0, 249, contentWidth, 62)
            body.CanvasSize = UDim2.fromOffset(0, 320)
        else
            rect(illustration, 0, 0, 180, 228)
            flaskScale.Scale = 1.1
            rect(trackTitle, 198, 0, contentWidth - 198, 32)
            rect(levelText, 198, 33, contentWidth - 198, 44)
            rect(description, 198, 78, contentWidth - 198, 49)
            rect(activeBonus, 198, 136, contentWidth - 198, 57)
            rect(nextBonus, 198, 201, contentWidth - 198, 57)
            body.CanvasSize = UDim2.fromOffset(0, 265)
        end
        rect(footer, 12, height - 140, footerWidth, 129)
        rect(chanceCaption, 12, 5, (width - 48) / 2, 16)
        rect(priceCaption, width / 2 - 12, 5, (width - 48) / 2, 16)
        rect(chance, 12, 21, (width - 48) / 2, 28)
        rect(price, width / 2 - 12, 21, (width - 48) / 2, 28)
        rect(attempt, 10, 53, width - 44, 46)
        rect(status, 8, 104, width - 40, 21)
        price.TextXAlignment = Enum.TextXAlignment.Right
        priceCaption.TextXAlignment = Enum.TextXAlignment.Right
        attempt.TextSize, status.TextSize = 18, 13
    end
    for _, value in ipairs({currentValue, nextValue}) do
        value.Position = UDim2.fromOffset(12, 24)
        value.Size = UDim2.new(1, -24, 0, short and 26 or compact and 33 or 28)
        value.TextSize = short and 12 or compact and 14 or narrow and 17 or 18
    end
end

refresh = function()
    if not current then return end
    local level = current.Levels[selected]
    local nextLevel = Config.Levels[level + 1]
    local chosen
    for _, track in ipairs(Config.Tracks) do
        local active = track.Id == selected
        tabs[track.Id].BackgroundColor3 = active and track.Color or paper
        tabs[track.Id].TextColor3 = active and paper or ink
        if active then chosen = track end
    end
    trackTitle.Text = chosen.Name
    levelText.Text = string.format("+%d / +%d", level, Config.MaxLevel)
    description.Text = chosen.Description .. " Applies to new plantings."
    currentValue.Text = Config.Describe(selected, level)
    nextValue.Text = nextLevel and Config.Describe(selected, level + 1) or "Fully researched"
    liquid.BackgroundColor3 = chosen.Color
    chance.Text = nextLevel and string.format("%d%%", nextLevel.Chance) or "MAX"
    price.Text = nextLevel and string.format("$%.2f", nextLevel.PriceCents / 100) or ""
    local affordable = nextLevel and money.Value >= nextLevel.PriceCents
    attempt.Text = pending and "Researching..." or not nextLevel and "Maximum level" or
        not affordable and "Not enough money" or "Try upgrade"
    attempt.Active = not pending and affordable ~= nil and affordable ~= false
    attempt.AutoButtonColor = attempt.Active
    attempt.BackgroundColor3 = attempt.Active and green or Color3.fromRGB(163, 145, 104)
end

local function closeMenu()
    if not current then return end
    remote:FireServer("Close", current.SessionId)
    current, pending = nil, false
    generation += 1
    player:SetAttribute("LaboratoryOpen", false)
    backdrop.Visible = false
    panel.GroupTransparency = 1
end

local function effect(success)
    local color = success and Color3.fromRGB(149, 207, 91) or Color3.fromRGB(209, 139, 77)
    tween(liquid, .16, {BackgroundColor3 = color, Position = UDim2.fromOffset(8, 31), Size = UDim2.new(1, -16, 0, 66)}):Play()
    tween(flask, .15, {Rotation = success and -6 or 5}):Play()
    for i = 1, success and 9 or 4 do
        local dot = frame(illustration, "Spark", color)
        dot.AnchorPoint = Vector2.new(.5, .5)
        dot.Position = UDim2.fromScale(.5, .5)
        dot.Size = UDim2.fromOffset(i % 2 == 0 and 8 or 5, 8)
        local angle = i * 2.4
        tween(dot, .65, {Position = UDim2.fromScale(.5 + math.cos(angle) * .44, .45 + math.sin(angle) * .42),
            BackgroundTransparency = 1, Rotation = 90}):Play()
        task.delay(.7, function() dot:Destroy() end)
    end
    local attachment = current and current.Station:FindFirstChild("ResearchEffect", true)
    if attachment then
        local light = make("PointLight", attachment, {Color = color, Range = 9, Brightness = 2.5})
        tween(light, .8, {Brightness = 0}):Play()
        task.delay(.9, function() light:Destroy() end)
    end
    task.delay(.2, function()
        tween(flask, .3, {Rotation = 0}):Play()
        tween(liquid, .4, {Position = UDim2.fromOffset(8, 47), Size = UDim2.new(1, -16, 0, 50)}):Play()
    end)
end

attempt.Activated:Connect(function()
    if not current or pending or not attempt.Active then return end
    pending = true
    status.Text = "Testing a new growing method..."
    status.TextColor3 = ink
    tween(bubble, .35, {Position = UDim2.fromOffset(30, -10)}):Play()
    remote:FireServer("Attempt", current.SessionId, current.Attempt, selected)
    refresh()
end)

remote.OnClientEvent:Connect(function(action, data)
    if action == "Open" then
        generation += 1
        current, pending, handled = data, false, 0
        selected = "Yield"
        player:SetAttribute("LaboratoryOpen", true)
        status.Text = "Paid attempt. Failure keeps your level."
        status.TextColor3 = ink
        body.CanvasPosition = Vector2.zero
        backdrop.Visible = true
        layout()
        refresh()
        tween(panel, .2, {GroupTransparency = 0}):Play()
    elseif action == "Result" and current and data.SessionId == current.SessionId then
        if data.Closed then closeMenu();return end
        if data.Request <= handled then return end
        handled = data.Request
        current = data
        local version = generation
        task.delay(data.Accepted and .45 or 0, function()
            if not current or version ~= generation then return end
            status.Text = data.Message
            status.TextColor3 = data.Success and green or ink
            if data.Accepted then effect(data.Success) end
        end)
        task.delay(Config.AttemptCooldown + .05, function()
            if not current or version ~= generation then return end
            pending = false
            bubble.Position = UDim2.fromOffset(45, 18)
            refresh()
        end)
    end
end)

close.Activated:Connect(closeMenu)
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and (input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Escape) then closeMenu() end
end)
player.CharacterRemoving:Connect(closeMenu)
player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
    if player:GetAttribute("DataLoaded") ~= true then closeMenu() end
end)
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
    if not current then return end
    elapsed += dt
    if elapsed < .2 then return end
    elapsed = 0
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local prompt = current.Station:FindFirstChild("ActionPrompt", true)
    local attachment = prompt and prompt.Parent
    if not root or not humanoid or humanoid.Health <= 0 or not current.Station:IsDescendantOf(workspace) or
        current.Station:GetAttribute("OwnerUserId") ~= player.UserId or not attachment or
        (root.Position - attachment.WorldPosition).Magnitude > Config.InteractionDistance or
        player:GetAttribute("ProductionMode") == true or player:GetAttribute("StorageOpen") == true then closeMenu() end
end)
money.Changed:Connect(refresh)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
layout()
script.Destroying:Connect(function()
    closeMenu()
    gui:Destroy()
end)


