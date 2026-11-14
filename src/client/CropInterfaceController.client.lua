local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Items = require(ReplicatedStorage.CropItems)
local definitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local config = require(ReplicatedStorage.Configs.CropConfig)
local player = Players.LocalPlayer
local inventory = player:WaitForChild("Inventory")
local inventoryGui = player:WaitForChild("PlayerGui"):WaitForChild("InventoryGui")
local remote = ReplicatedStorage.RemoteEvents:WaitForChild("CropRecords")
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "CropInfoGui", false, 24
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")
local ink = Color3.fromRGB(89, 55, 26)

local function make(class, parent, properties)
    local object = Instance.new(class)
    for name, value in pairs(properties) do object[name] = value end
    object.Parent = parent
    return object
end
local function round(object)
    make("UICorner", object, {CornerRadius = UDim.new(0, 10)})
end
local function label(parent, text, position, size, fontSize)
    return make("TextLabel", parent, {Text = text, Position = position, Size = size, BackgroundTransparency = 1,
        Font = Enum.Font.FredokaOne, TextSize = fontSize, TextColor3 = ink, TextXAlignment = Enum.TextXAlignment.Left})
end
local function button(parent, name, text, position, size)
    local object = make("TextButton", parent, {Name = name, Text = text, Position = position, Size = size,
        BackgroundColor3 = Color3.fromRGB(109, 153, 65), TextColor3 = Color3.fromRGB(255, 245, 219),
        Font = Enum.Font.FredokaOne, TextSize = 17, BorderSizePixel = 0})
    round(object)
    return object
end
local openRecords = button(gui, "Records", "Crop records", UDim2.new(1, -150, 0, 74), UDim2.fromOffset(138, 44))
local sizes = button(gui, "Sizes", "Crop sizes", UDim2.new(0.5, -62, 1, -150), UDim2.fromOffset(124, 44))
local panel = make("Frame", gui, {Name = "Panel", Visible = false, BorderSizePixel = 0,
    BackgroundColor3 = Color3.fromRGB(255, 221, 151), AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(390, 390)})
round(panel)
make("UIStroke", panel, {Color = Color3.fromRGB(126, 79, 39), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
local title = label(panel, "Crop records", UDim2.fromOffset(14, 12), UDim2.new(1, -78, 0, 30), 23)
local close = button(panel, "Close", "X", UDim2.new(1, -54, 0, 8), UDim2.fromOffset(44, 44))
close.BackgroundColor3 = Color3.fromRGB(176, 69, 47)
local server = button(panel, "Server", "This server", UDim2.fromOffset(12, 60), UDim2.new(0.5, -18, 0, 44))
local global = button(panel, "Global", "Global", UDim2.new(0.5, 6, 0, 60), UDim2.new(0.5, -18, 0, 44))
local list = make("ScrollingFrame", panel, {Name = "List", Position = UDim2.fromOffset(12, 114),
    Size = UDim2.new(1, -24, 1, -152), BackgroundTransparency = 1, BorderSizePixel = 0, Active = true,
    ScrollingDirection = Enum.ScrollingDirection.Y, AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(), ScrollBarThickness = 4, ScrollBarImageColor3 = Color3.fromRGB(169, 111, 50)})
make("UIListLayout", list, {Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder})
local status = label(panel, "", UDim2.new(0, 14, 1, -30), UDim2.new(1, -28, 0, 24), 13)
status.TextWrapped = true
local mode, boards, key = "Server", nil, nil
local snapshot
local moneyGui, moneyEnabled
local desiredHeight = 260

local function hide()
    panel.Visible = false
    if snapshot ~= nil then game.ProximityPromptService.Enabled = snapshot;snapshot = nil end
    if moneyGui and moneyGui.Parent then moneyGui.Enabled = moneyEnabled end
    moneyGui = nil
end
local function show(nextMode)
    mode, key = nextMode, nil
    if not panel.Visible then
        snapshot = game.ProximityPromptService.Enabled
        game.ProximityPromptService.Enabled = false
        moneyGui = player.PlayerGui:FindFirstChild("MoneyGui")
        if moneyGui then moneyEnabled = moneyGui.Enabled;moneyGui.Enabled = false end
    end
    panel.Visible = true
    list.CanvasPosition = Vector2.zero
    if mode ~= "Sizes" then remote:FireServer() end
end
local function row(icon, caption, detail, order)
    local frame = make("Frame", list, {Name = "Entry", LayoutOrder = order, Size = UDim2.new(1, -6, 0, 62),
        BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(255, 239, 199)})
    round(frame)
    make("ImageLabel", frame, {Name = "Icon", Image = icon, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(44, 44), ScaleType = Enum.ScaleType.Fit})
    local top = label(frame, caption, UDim2.fromOffset(60, 4), UDim2.new(1, -70, 0, 28), 18)
    top.TextScaled = true
    make("UITextSizeConstraint", top, {MinTextSize = 12, MaxTextSize = 18})
    label(frame, detail, UDim2.fromOffset(60, 33), UDim2.new(1, -70, 0, 24), 16)
end
local function refresh()
    if not panel.Visible then return end
    local slot = inventory:FindFirstChild("Slot" .. (player:GetAttribute("SelectedSlot") or 1))
    local data = {ItemName = slot.ItemName.Value, Amount = slot.Amount.Value, Variants = Items.Read(slot)}
    local nextKey = mode .. (mode == "Sizes" and data.ItemName .. data.Amount .. tostring(slot:GetAttribute("Variants")) or
        game.HttpService:JSONEncode(boards or {}))
    if nextKey == key then return end
    key = nextKey
    for _, object in ipairs(list:GetChildren()) do if object:IsA("Frame") then object:Destroy() end end
    server.Visible, global.Visible = mode ~= "Sizes", mode ~= "Sizes"
    server.BackgroundColor3 = mode == "Server" and Color3.fromRGB(91, 148, 57) or Color3.fromRGB(153, 119, 65)
    global.BackgroundColor3 = mode == "Global" and Color3.fromRGB(91, 148, 57) or Color3.fromRGB(153, 119, 65)
    list.Position = UDim2.fromOffset(12, mode == "Sizes" and 60 or 114)
    list.Size = UDim2.new(1, -24, 1, mode == "Sizes" and -98 or -152)
    if mode == "Sizes" then
        if not config.Crops[data.ItemName] or not Items.Valid(data) then hide();return end
        title.Text = definitions[data.ItemName].DisplayName .. " x" .. data.Amount
        local groups = Items.Groups(data)
        desiredHeight = math.max(180, math.min(390, 98 + #groups * 69))
        for index, group in ipairs(groups) do
            row(definitions[data.ItemName].Icon, group.Size .. "%  x" .. group.Amount,
                string.format("$%.2f each", Items.UnitPrice(definitions[data.ItemName].SellPriceCents, group.Size) / 100), index)
        end
        status.Text = "Smaller crops are used first."
    else
        title.Text = "Crop records"
        local rows = boards and boards[mode] or {}
        desiredHeight = math.min(390, 152 + math.max(1, #rows) * 69)
        for index, record in ipairs(rows) do
            row(definitions[record.Crop].Icon, index .. ". " .. record.Name,
                definitions[record.Crop].DisplayName .. "  " .. record.Size .. "%", index)
        end
        status.Text = mode == "Global" and (not boards and "Loading..." or boards.Unavailable and "Global ranking is temporarily unavailable." or "Updates every " .. config.LeaderboardRefreshSeconds .. "s.") or
            (#rows == 0 and "Harvest a crop to set your first record." or "Best harvest for each player.")
    end
end
openRecords.Activated:Connect(function() show("Server");refresh() end)
sizes.Activated:Connect(function() show("Sizes");refresh() end)
server.Activated:Connect(function() show("Server");refresh() end)
global.Activated:Connect(function() show("Global");refresh() end)
close.Activated:Connect(hide)
remote.OnClientEvent:Connect(function(data) boards = data;refresh() end)
UserInputService.InputBegan:Connect(function(input) if input.KeyCode == Enum.KeyCode.Q then hide() end end)
player.CharacterRemoving:Connect(hide)
script.Destroying:Connect(function() hide();gui:Destroy() end)
local elapsed, requested = 0, 0
RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    requested += dt
    if elapsed < 0.2 then return end
    elapsed = 0
    local other = player:GetAttribute("ProductionMode") == true or player:GetAttribute("AnimalMenuOpen") == true or
        player:GetAttribute("Milking") == true or player:GetAttribute("StorageOpen") == true or player:GetAttribute("FeederOpen") == true
    for _, name in ipairs({"BuyGui", "SellGui"}) do
        local shop = player.PlayerGui:FindFirstChild(name)
        if shop and shop.Enabled and shop.MainFrame.Visible then other = true end
    end
    local active = player:GetAttribute("DataLoaded") == true and not other and player.Character and player.Character:FindFirstChildOfClass("Humanoid") and player.Character.Humanoid.Health > 0
    if not active then hide() end
    openRecords.Visible = active == true and not panel.Visible
    local slot = inventory:FindFirstChild("Slot" .. (player:GetAttribute("SelectedSlot") or 1))
    sizes.Visible = active == true and not panel.Visible and slot.Amount.Value > 0 and config.Crops[slot.ItemName.Value] ~= nil
    local size = gui.AbsoluteSize
    local touch, portrait = UserInputService.TouchEnabled, size.Y > size.X
    local bar = inventoryGui:FindFirstChild("HotbarFrame")
    local bottom = bar and bar.AbsolutePosition.Y - 8 or size.Y - 100
    sizes.Position = UDim2.new(0.5, -62, 0, math.max(60, bottom - 44))
    panel.AnchorPoint = touch and portrait and Vector2.new(0.5, 1) or Vector2.new(1, 0)
    local width = touch and not portrait and math.min(360, size.X * 0.47) or math.min(390, size.X - 24)
    panel.Size = UDim2.fromOffset(width, math.min(desiredHeight, bottom - 12))
    panel.Position = touch and portrait and UDim2.new(0.5, 0, 0, bottom) or UDim2.new(1, -12, 0, 12)
    if panel.Visible and mode ~= "Sizes" and requested > 15 then requested = 0;remote:FireServer() end
    refresh()
end)
