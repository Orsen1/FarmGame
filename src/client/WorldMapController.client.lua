local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local plots = workspace:WaitForChild("Plots")
local zones = workspace:WaitForChild("PublicZones")
local config = require(ReplicatedStorage.Configs.WorldTravelConfig).FastTravel
local HudMenu = require(ReplicatedStorage:WaitForChild("HudMenu"))
local placement = require(ReplicatedStorage.PlacementScripts.PlacementController)
local remote = ReplicatedStorage.RemoteEvents:WaitForChild("MapTravelEvent")
local ink = Color3.fromRGB(96, 62, 34)
local paper = Color3.fromRGB(255, 237, 191)
local green = Color3.fromRGB(96, 139, 69)
local gold = Color3.fromRGB(237, 182, 63)
local entries, thumbnails = {}, {}
local opened, pending = false, nil
local previousPrompts, previousInventory
local generation = 0
local layout

local function make(class, parent, properties)
    local object = Instance.new(class)
    for name, value in pairs(properties) do object[name] = value end
    object.Parent = parent
    return object
end

local function round(object, radius)
    make("UICorner", object, {CornerRadius = UDim.new(0, radius or 10)})
end

local function outline(object, color, width)
    return make("UIStroke", object, {Color = color or ink, Thickness = width or 2,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end

local function label(parent, name, value, size)
    return make("TextLabel", parent, {Name = name, Text = value, TextSize = size or 16,
        BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextColor3 = ink,
        TextTruncate = Enum.TextTruncate.AtEnd})
end

local function block(parent, name, color)
    return make("Frame", parent, {Name = name, BorderSizePixel = 0, BackgroundColor3 = color})
end

local function tween(object, duration, properties)
    local animation = TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out), properties)
    animation:Play()
    return animation
end

local gui = make("ScreenGui", playerGui, {Name = "WorldMapGui", ResetOnSpawn = false,
    DisplayOrder = 40, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
local backdrop = make("TextButton", gui, {Name = "Backdrop", Text = "", Visible = false,
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = ink, BackgroundTransparency = .68,
    AutoButtonColor = false, BorderSizePixel = 0})
local panel = make("CanvasGroup", backdrop, {Name = "Panel", AnchorPoint = Vector2.new(.5, .5),
    Position = UDim2.fromScale(.5, .5), BackgroundColor3 = Color3.fromRGB(242, 207, 146),
    BorderSizePixel = 0, GroupTransparency = 1})
round(panel, 16)
outline(panel, ink, 3)
local title = label(panel, "Title", "World Map", 28)
title.TextXAlignment = Enum.TextXAlignment.Left
local close = make("TextButton", panel, {Name = "Close", Text = "X", TextSize = 22,
    Font = Enum.Font.FredokaOne, BackgroundColor3 = Color3.fromRGB(170, 78, 52),
    TextColor3 = paper, BorderSizePixel = 0})
round(close)
outline(close, ink)
local map = block(panel, "Map", Color3.fromRGB(154, 177, 110))
map.ClipsDescendants = true
round(map, 12)
outline(map, Color3.fromRGB(145, 119, 66))
local status = label(panel, "Status", "Choose a destination to travel.", 15)
status.Font = Enum.Font.GothamMedium
local fade = block(gui, "TravelFade", paper)
fade.Size = UDim2.fromScale(1, 1)
fade.BackgroundTransparency = 1
fade.Visible = false
fade.ZIndex = 20
local openButton = HudMenu.Add("OpenMap", "Map", 5)

local function hideFade()
    local animation = tween(fade, .18, {BackgroundTransparency = 1})
    animation.Completed:Once(function()
        if not pending then fade.Visible = false end
    end)
end

local function closeMap()
    if not opened then return end
    generation += 1
    opened = false
    pending = nil
    backdrop.Visible = false
    panel.GroupTransparency = 1
    player:SetAttribute("WorldMapOpen", false)
    if previousPrompts ~= nil then ProximityPromptService.Enabled = previousPrompts end
    previousPrompts = nil
    local inventory = playerGui:FindFirstChild("InventoryGui")
    if previousInventory ~= nil and inventory then inventory.Enabled = previousInventory end
    previousInventory = nil
    hideFade()
end

local function travel(entry)
    if not opened or pending then return end
    pending = entry.Id
    status.Text = "Travelling..."
    status.TextColor3 = ink
    fade.Visible = true
    tween(fade, .12, {BackgroundTransparency = .12})
    local version = generation
    task.delay(.13, function()
        if opened and pending == entry.Id and version == generation then remote:FireServer(entry.Id) end
    end)
    task.delay(6, function()
        if opened and pending == entry.Id and version == generation then
            pending = nil
            status.Text = "Travel timed out. Please try again."
            hideFade()
        end
    end)
end

local artwork = make("ImageLabel", map, {Name = "Artwork", BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1), Image = config.MapImage, ScaleType = Enum.ScaleType.Stretch})
round(artwork, 12)

local function buildEntry(id, instance, kind, color)
    local button = make("TextButton", map, {Name = id, Text = "", BorderSizePixel = 0,
        BackgroundTransparency = kind == "Plot" and 1 or .03,
        BackgroundColor3 = paper, AutoButtonColor = true})
    round(button, 10)
    local entry = {Id = id, Instance = instance, Kind = kind, Button = button}
    entries[id] = entry
    if kind == "Plot" then
        local card = block(button, "Owner", paper)
        round(card, 9)
        card.Size = UDim2.fromScale(1, 1)
        card.BackgroundTransparency = 1
        entry.Card = card
        entry.Title = label(card, "Title", "", 14)
        entry.Title.BackgroundColor3 = paper
        entry.Title.BackgroundTransparency = .12
        round(entry.Title, 5)
        local avatar = make("ImageLabel", card, {Name = "Avatar", Image = "", BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(223, 203, 157), ScaleType = Enum.ScaleType.Fit})
        round(avatar, 30)
        entry.Stroke = outline(avatar, ink, 1.5)
        entry.Avatar = avatar
        entry.Fallback = label(avatar, "Initial", "", 18)
        entry.Fallback.Size = UDim2.fromScale(1, 1)
        entry.Name = label(card, "OwnerName", "", 12)
        entry.Name.Font = Enum.Font.GothamMedium
        entry.Name.BackgroundColor3 = paper
        entry.Name.BackgroundTransparency = .12
        round(entry.Name, 5)
        instance:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
            if entry.Refresh then entry.Refresh() end
        end)
    else
        entry.Stroke = outline(button, ink, 1.5)
        entry.Title = label(button, "Title", id, 16)
        entry.Title.Size = UDim2.fromScale(1, 1)
        local dot = block(button, "Dot", color)
        round(dot, 5)
        dot.Size = UDim2.fromOffset(6, 6)
        dot.Position = UDim2.new(.5, -3, 1, -9)
    end
    button.Activated:Connect(function() travel(entry) end)
    return entry
end

for _, location in ipairs(config.Locations) do
    local entry = buildEntry(location.Id, zones:WaitForChild(location.Id), "Zone", location.Color)
    entry.Title.Text = location.DisplayName
end
for index = 1, 4 do
    buildEntry("Plot" .. index, plots:WaitForChild("Plot" .. index), "Plot", Color3.fromRGB(170, 151, 95))
end

local function refreshOwner(entry)
    local ownerId = entry.Instance:GetAttribute("OwnerUserId") or 0
    local owner = ownerId > 0 and Players:GetPlayerByUserId(ownerId)
    local mine = ownerId == player.UserId
    entry.Title.Text = mine and "Your farm" or "Farm " .. entry.Id:sub(-1)
    entry.Title.TextColor3 = mine and green or ink
    entry.Stroke.Color = mine and gold or ink
    entry.Stroke.Thickness = mine and 3 or 1.5
    entry.Name.Text = owner and "@" .. owner.Name or ownerId > 0 and "Player " .. ownerId or "Available"
    entry.Avatar.Image = thumbnails[ownerId] or ""
    entry.Fallback.Text = owner and owner.DisplayName:sub(1, 1) or ownerId > 0 and "?" or "-"
    entry.Fallback.Visible = entry.Avatar.Image == ""
    if ownerId > 0 and not thumbnails[ownerId] then
        task.spawn(function()
            local ok, image = pcall(Players.GetUserThumbnailAsync, Players, ownerId,
                Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
            if ok and image ~= "" then
                thumbnails[ownerId] = image
                if entry.Instance:GetAttribute("OwnerUserId") == ownerId then
                    entry.Avatar.Image = image
                    entry.Fallback.Visible = false
                end
            end
        end)
    end
end

local function refreshOwners()
    for _, entry in pairs(entries) do if entry.Kind == "Plot" then refreshOwner(entry) end end
end
for _, entry in pairs(entries) do
    if entry.Kind == "Plot" then entry.Refresh = function() refreshOwner(entry) end end
end

layout = function()
    local screen = gui.AbsoluteSize
    if screen.X < 1 or screen.Y < 1 then return end
    local short = screen.Y < 450
    local top = short and 50 or 62
    local bottom = 36
    local mapHeight = math.min((screen.X - 48) / 1.5, screen.Y - 24 - top - bottom, 570)
    local mapWidth = mapHeight * 1.5
    local width, height = mapWidth + 24, mapHeight + top + bottom
    panel.Size = UDim2.fromOffset(width, height)
    title.Position = UDim2.fromOffset(16, short and 3 or 10)
    title.Size = UDim2.new(1, -78, 0, short and 36 or 40)
    title.TextSize = short and 23 or 27
    close.Position = UDim2.new(1, -52, 0, short and 4 or 9)
    close.Size = UDim2.fromOffset(42, 38)
    map.Position = UDim2.fromOffset(12, top)
    map.Size = UDim2.fromOffset(mapWidth, mapHeight)
    status.Position = UDim2.new(0, 12, 1, -30)
    status.Size = UDim2.new(1, -24, 0, 23)
    status.TextSize = mapWidth < 450 and 12 or 14
    for id, entry in pairs(entries) do
        local position
        if entry.Kind == "Plot" then
            position = config.PlotMarkers[tonumber(id:sub(-1))]
        else
            for _, location in ipairs(config.Locations) do
                if location.Id == id then position = location.MapPosition end
            end
        end
        entry.Button.AnchorPoint = Vector2.new(.5, .5)
        entry.Button.Position = UDim2.fromScale(position.X, position.Y)
        if entry.Kind == "Plot" then
            local small = mapWidth < 450
            local cardWidth = math.clamp(mapWidth * .18, 60, 120)
            local cardHeight = small and (mapHeight < 185 and 50 or 54) or 78
            local avatarSize = small and 23 or 34
            entry.Button.Size = UDim2.fromOffset(cardWidth, cardHeight)
            entry.Title.Position = UDim2.fromOffset(2, 1)
            entry.Title.Size = UDim2.new(1, -4, 0, small and 14 or 19)
            entry.Title.TextSize = small and 11 or 13
            entry.Avatar.Position = UDim2.new(.5, -avatarSize / 2, 0, small and 15 or 22)
            entry.Avatar.Size = UDim2.fromOffset(avatarSize, avatarSize)
            entry.Name.Position = UDim2.new(0, 2, 1, small and -15 or -20)
            entry.Name.Size = UDim2.new(1, -4, 0, small and 14 or 18)
            entry.Name.TextSize = small and 11 or 12
        else
            entry.Button.Size = UDim2.fromOffset(math.clamp(mapWidth * .16, 56, 110), 44)
            entry.Title.Position = UDim2.fromOffset(2, -3)
            entry.Title.Size = UDim2.new(1, -4, 1, 0)
            entry.Title.TextSize = mapWidth < 450 and 12 or 16
        end
    end
end

local function openMap()
    if opened then closeMap();return end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if player:GetAttribute("DataLoaded") ~= true or not humanoid or humanoid.Health <= 0 or
        player:GetAttribute("ProductionMode") or player:GetAttribute("Milking") or
        character:GetAttribute("GatherStartedAt") then return end
    for _, attribute in ipairs({"LaboratoryOpen", "AnimalMenuOpen", "FeederOpen", "FarmJournalOpen", "Teleporting"}) do
        if player:GetAttribute(attribute) then return end
    end
    HudMenu.CloseStorage()
    if not ProximityPromptService.Enabled then return end
    for _, name in ipairs({"BuyGui", "SellGui"}) do
        local other = playerGui:FindFirstChild(name)
        if other and other.Enabled and other.MainFrame.Visible then return end
    end
    placement.cancelPlacement()
    generation += 1
    opened, pending = true, nil
    previousPrompts = ProximityPromptService.Enabled
    ProximityPromptService.Enabled = false
    local inventory = playerGui:FindFirstChild("InventoryGui")
    previousInventory = inventory and inventory.Enabled
    if inventory then inventory.Enabled = false end
    player:SetAttribute("WorldMapOpen", true)
    status.Text, status.TextColor3 = "Choose a destination to travel.", ink
    refreshOwners()
    layout()
    backdrop.Visible = true
    tween(panel, .18, {GroupTransparency = 0})
end

openButton.Activated:Connect(openMap)
close.Activated:Connect(closeMap)
remote.OnClientEvent:Connect(function(destination, success, message)
    if pending ~= destination then return end
    pending = nil
    if success then closeMap()
    else
        status.Text = message or "Could not travel. Try again."
        status.TextColor3 = Color3.fromRGB(167, 69, 44)
        hideFade()
    end
end)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.M then openMap()
    elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Escape then closeMap() end
end)
player.CharacterRemoving:Connect(closeMap)
for _, attribute in ipairs({"DataLoaded", "ProductionMode", "Milking", "Teleporting", "StorageOpen", "AnimalMenuOpen", "LaboratoryOpen"}) do
    player:GetAttributeChangedSignal(attribute):Connect(function()
        if attribute == "DataLoaded" and player:GetAttribute(attribute) ~= true or
            attribute ~= "DataLoaded" and player:GetAttribute(attribute) == true then closeMap() end
    end)
end
player:GetAttributeChangedSignal("PlotName"):Connect(refreshOwners)
Players.PlayerAdded:Connect(refreshOwners)
Players.PlayerRemoving:Connect(function() task.defer(refreshOwners) end)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
refreshOwners()
layout()
script.Destroying:Connect(function()
    closeMap()
    gui:Destroy()
end)
