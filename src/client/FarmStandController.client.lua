local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local inventory = player:WaitForChild("Inventory")
local config = require(ReplicatedStorage.Configs.FarmStandConfig)
local definitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local crops = require(ReplicatedStorage.Configs.CropConfig).Crops
local menu = require(ReplicatedStorage.HudMenu)
local event = ReplicatedStorage.RemoteEvents:WaitForChild("FarmStandEvent")

local paper = Color3.fromRGB(255, 237, 197)
local ink = Color3.fromRGB(91, 55, 30)
local tan = Color3.fromRGB(247, 218, 159)
local green = Color3.fromRGB(83, 123, 52)
local white = Color3.fromRGB(255, 248, 220)

local function make(class, parent, properties)
    local object = Instance.new(class)
    for name, value in pairs(properties) do object[name] = value end
    object.Parent = parent
    return object
end

local function edge(object, radius, stroke)
    make("UICorner", object, {CornerRadius = UDim.new(0, radius)})
    make("UIStroke", object, {ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = stroke or Color3.fromRGB(158, 105, 56), Thickness = 1.5})
end

local function label(parent, value, size, position, bounds, color)
    return make("TextLabel", parent, {Text = value, Position = position, Size = bounds,
        BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextSize = size, TextColor3 = color or ink,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd})
end

local function button(parent, value, position, size, color)
    local control = make("TextButton", parent, {Text = value, Position = position, Size = size,
        BackgroundColor3 = color or tan, BorderSizePixel = 0, Font = Enum.Font.FredokaOne, TextSize = 17,
        TextColor3 = color == green and white or ink})
    edge(control, 9)
    return control
end

local gui = make("ScreenGui", playerGui, {Name = "FarmStandGui", ResetOnSpawn = false, Enabled = false,
    ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, DisplayOrder = 27})
local panel = make("CanvasGroup", gui, {Name = "MainFrame", AnchorPoint = Vector2.new(.5, .5),
    Position = UDim2.fromScale(.5, .5), BackgroundColor3 = paper, BorderSizePixel = 0})
edge(panel, 16)
make("Frame", panel, {Position = UDim2.fromOffset(14, 50), Size = UDim2.new(1, -28, 0, 2),
    BackgroundColor3 = Color3.fromRGB(191, 155, 102), BorderSizePixel = 0})
local title = label(panel, "Farm Stand", 24, UDim2.fromOffset(14, 4), UDim2.new(1, -72, 0, 44))
local closeButton = button(panel, "×", UDim2.new(1, -52, 0, 7), UDim2.fromOffset(44, 44))
closeButton.TextSize = 24

local list = make("ScrollingFrame", panel, {Name = "Crops", Position = UDim2.fromOffset(12, 54),
    Size = UDim2.new(1, -24, 1, -195), BackgroundTransparency = 1, BorderSizePixel = 0,
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 5,
    ScrollBarImageColor3 = Color3.fromRGB(174, 119, 64)})
make("UIListLayout", list, {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 7)})
make("UIPadding", list, {PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 3)})

local controls = make("Frame", panel, {Name = "Actions", Position = UDim2.new(0, 12, 1, -111),
    Size = UDim2.new(1, -24, 0, 102), BackgroundTransparency = 1})
local minus = button(controls, "−", UDim2.fromOffset(0, 0), UDim2.fromOffset(44, 44))
local quantity = make("TextBox", controls, {Name = "Quantity", Text = "1", Position = UDim2.fromOffset(52, 0),
    Size = UDim2.new(1, -170, 0, 44), BorderSizePixel = 0, BackgroundColor3 = white,
    Font = Enum.Font.FredokaOne, TextSize = 18, TextColor3 = ink, ClearTextOnFocus = false})
edge(quantity, 9)
local plus = button(controls, "+", UDim2.new(1, -110, 0, 0), UDim2.fromOffset(44, 44))
local maximum = button(controls, "Max", UDim2.new(1, -58, 0, 0), UDim2.fromOffset(58, 44))
local stockButton = button(controls, "Stock", UDim2.fromOffset(0, 52), UDim2.new(.5, -4, 0, 44), green)
local returnButton = button(controls, "Take back", UDim2.new(.5, 4, 0, 52), UDim2.new(.5, -4, 0, 44))
local status = label(panel, "", 14, UDim2.new(0, 14, 1, -141), UDim2.new(1, -28, 0, 26))

local stand, selected, stock = nil, nil, {}
local rows = {}
local inBag = {}
local refreshQueued = false
local messageUntil = 0
local hiddenInventory
local visibleCount = 0
local panelTween, statusTween
local refresh
local layout

local function available(item)
    local row = item and stock[item]
    local onStand = row and row.Amount or 0
    local canStock = math.min(inBag[item] or 0, config.StockLimit - onStand)
    if player:GetAttribute("TutorialStep") ~= "Complete" then
        canStock = item == player:GetAttribute("TutorialCropItem") and
            math.min(canStock, (player:GetAttribute("TutorialRemaining") or 0) - onStand) or 0
    end
    return math.max(0, canStock), onStand - (row and row.Reserved or 0)
end

local function setAmount(value)
    local deposit, withdraw = available(selected)
    quantity.Text = value == "Max" and "Max" or tostring(math.clamp(math.floor(tonumber(value) or 1), 1, math.max(1, deposit, withdraw)))
end

local function animatePanel(open)
    if panelTween then panelTween:Cancel() end
    if open then
        panel.GroupTransparency = 1
        panel.Position = UDim2.new(.5, 0, .5, 8)
        panel.Visible, gui.Enabled = true, true
    end
    local tween = TweenService:Create(panel, TweenInfo.new(open and .22 or .16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {GroupTransparency = open and 0 or 1, Position = UDim2.new(.5, 0, .5, open and 0 or 8)})
    panelTween = tween
    tween.Completed:Once(function(result)
        if panelTween ~= tween or result ~= Enum.PlaybackState.Completed then return end
        panelTween = nil
        if not open then gui.Enabled = false end
    end)
    tween:Play()
end

local function showMessage(message)
    if statusTween then statusTween:Cancel() end
    status.Text = message
    status.TextTransparency = .6
    messageUntil = os.clock() + 4
    statusTween = TweenService:Create(status, TweenInfo.new(.18), {TextTransparency = 0})
    statusTween:Play()
end

local function close(tellServer)
    if not stand then return end
    stand = nil
    animatePanel(false)
    if hiddenInventory then
        hiddenInventory.Enabled = true
        hiddenInventory = nil
    end
    player:SetAttribute("FarmStandOpen", nil)
    if tellServer then event:FireServer("Close") end
end

local function addRow(item, index)
    local definition = definitions[item]
    local row = button(list, "", UDim2.new(), UDim2.new(1, -10, 0, 51), tan)
    row.LayoutOrder = index
    make("ImageLabel", row, {Size = UDim2.fromOffset(41, 41), Position = UDim2.fromOffset(7, 5),
        BackgroundTransparency = 1, Image = definition.Icon, ScaleType = Enum.ScaleType.Fit})
    label(row, definition.DisplayName, 17, UDim2.fromOffset(55, 4), UDim2.new(1, -66, 0, 23))
    local tally = label(row, "", 13, UDim2.fromOffset(55, 27), UDim2.new(1, -66, 0, 19))
    row.Activated:Connect(function()
        selected = item
        setAmount(1)
        refresh()
    end)
    return {Button = row, Tally = tally}
end

refresh = function()
    table.clear(inBag)
    for _, slot in ipairs(inventory:GetChildren()) do
        local name = slot.ItemName.Value
        if crops[name] then inBag[name] = (inBag[name] or 0) + slot.Amount.Value end
    end
    local visible = {}
    for item in pairs(crops) do
        if (inBag[item] or 0) > 0 or stock[item] then table.insert(visible, item) end
    end
    table.sort(visible, function(a, b) return definitions[a].DisplayName < definitions[b].DisplayName end)
    visibleCount = #visible
    layout()
    if not table.find(visible, selected) then selected = visible[1];quantity.Text = "1" end
    for item, row in pairs(rows) do
        if not table.find(visible, item) then row.Button:Destroy();rows[item] = nil end
    end
    for i, item in ipairs(visible) do
        local row = rows[item] or addRow(item, i)
        rows[item] = row
        row.Button.LayoutOrder = i
        row.Button.BackgroundColor3 = item == selected and Color3.fromRGB(229, 210, 141) or tan
        local data = stock[item]
        local held = data and data.Reserved or 0
        row.Tally.Text = string.format("Bag %d  ·  Stand %d%s", inBag[item] or 0, data and data.Amount or 0,
            held > 0 and "  ·  Reserved " .. held or "")
    end
    controls.Visible = selected ~= nil
    local deposit, withdraw = available(selected)
    stockButton.Interactable, returnButton.Interactable = deposit > 0, withdraw > 0
    stockButton.BackgroundColor3 = deposit > 0 and green or Color3.fromRGB(145, 135, 103)
    returnButton.BackgroundColor3 = withdraw > 0 and tan or Color3.fromRGB(215, 203, 172)
    if os.clock() >= messageUntil then
        status.Text = #visible == 0 and "Harvest crops to stock your stand." or "Buyers shop while you farm."
    end
end

local function scheduleRefresh()
    if refreshQueued then return end
    refreshQueued = true
    task.defer(function()
        refreshQueued = false
        if stand then refresh() end
    end)
end

for i = 1, 6 do
    local slot = inventory:WaitForChild("Slot" .. i)
    slot:WaitForChild("ItemName").Changed:Connect(scheduleRefresh)
    slot:WaitForChild("Amount").Changed:Connect(scheduleRefresh)
end
player:GetAttributeChangedSignal("TutorialStep"):Connect(scheduleRefresh)
player:GetAttributeChangedSignal("TutorialRemaining"):Connect(scheduleRefresh)

local function send(action, takeBack)
    if not stand or not selected then return end
    local deposit, withdraw = available(selected)
    local limit = takeBack and withdraw or deposit
    local value = quantity.Text == "Max" and limit or tonumber(quantity.Text)
    if not value or value < 1 or value % 1 ~= 0 or value > limit then
        showMessage("Choose an amount from 1 to " .. limit .. ".")
        return
    end
    event:FireServer(action, selected, value)
end

minus.Activated:Connect(function() setAmount((tonumber(quantity.Text) or 1) - 1) end)
plus.Activated:Connect(function() setAmount((tonumber(quantity.Text) or 0) + 1) end)
maximum.Activated:Connect(function() setAmount("Max") end)
quantity.FocusLost:Connect(function() setAmount(quantity.Text) end)
stockButton.Activated:Connect(function() send("Stock", false) end)
returnButton.Activated:Connect(function() send("Return", true) end)
closeButton.Activated:Connect(function() close(true) end)
player.CharacterRemoving:Connect(function() close(true) end)
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.Q then close(true) end
end)

layout = function()
    local bounds = gui.AbsoluteSize
    local height = visibleCount == 0 and 128 or math.min(385, 209 + visibleCount * 58)
    panel.Size = UDim2.fromOffset(math.min(470, math.max(0, bounds.X - 18)), math.min(height, math.max(0, bounds.Y - 14)))
    status.Position = visibleCount == 0 and UDim2.fromOffset(14, 58) or UDim2.new(0, 14, 1, -141)
    title.TextSize = bounds.Y < 400 and 21 or 24
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
layout()

event.OnClientEvent:Connect(function(action, data, info)
    if action == "Close" then close(false);return end
    if action == "Open" then
        menu.CloseStorage()
        local shop = playerGui:FindFirstChild("BuyGui")
        if shop then shop.MainFrame.Visible = false end
        local hotbar = playerGui:FindFirstChild("InventoryGui")
        if hotbar and hotbar.Enabled then hiddenInventory = hotbar;hotbar.Enabled = false end
        stand, selected, messageUntil = info, nil, 0
        list.CanvasPosition = Vector2.zero
        player:SetAttribute("FarmStandOpen", true)
        animatePanel(true)
    elseif not stand then
        return
    elseif info then
        showMessage(info)
    end
    stock = data
    refresh()
end)

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
    if not stand then return end
    elapsed += dt
    if elapsed < .15 then return end
    elapsed = 0
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root or not stand.Parent or not player:GetAttribute("DataLoaded") or
        (root.Position - stand.PrimaryPart.Position).Magnitude > config.MaxDistance or not panel.Visible then
        panel.Visible = true
        close(true)
    elseif messageUntil > 0 and os.clock() >= messageUntil then
        messageUntil = 0
        refresh()
    end
end)
