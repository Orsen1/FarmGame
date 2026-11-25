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
local reputationBase = Color3.fromRGB(244, 222, 173)
local reputationFlash = Color3.fromRGB(255, 235, 155)
local reputationLevels = config.ReputationLevels

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
local title = label(panel, "Farm Stand", 24, UDim2.fromOffset(14, 4), UDim2.new(1, -72, 0, 44))
local closeButton = button(panel, "×", UDim2.new(1, -52, 0, 7), UDim2.fromOffset(44, 44))
closeButton.TextSize = 24

local reputation = make("Frame", panel, {Name = "Reputation", BackgroundColor3 = reputationBase, BorderSizePixel = 0})
edge(reputation, 10, Color3.fromRGB(175, 134, 80))
label(reputation, "Market reputation", 16, UDim2.fromOffset(10, 1), UDim2.new(1, -100, 0, 21))
local reputationRank = label(reputation, "", 15, UDim2.new(1, -87, 0, 1), UDim2.fromOffset(77, 21), green)
reputationRank.TextXAlignment = Enum.TextXAlignment.Right
local reputationDetail = label(reputation, "", 13, UDim2.fromOffset(10, 21), UDim2.new(1, -20, 0, 16))
local track = make("Frame", reputation, {Name = "Progress", Position = UDim2.new(0, 10, 1, -8),
    Size = UDim2.new(1, -20, 0, 5), BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(216, 184, 128)})
make("UICorner", track, {CornerRadius = UDim.new(1, 0)})
local fill = make("Frame", track, {Name = "Fill", Size = UDim2.fromScale(0, 1),
    BackgroundColor3 = green, BorderSizePixel = 0})
make("UICorner", fill, {CornerRadius = UDim.new(1, 0)})

local noticeGui = make("ScreenGui", playerGui, {Name = "MarketReputationNotice", ResetOnSpawn = false,
    DisplayOrder = 28, Enabled = false, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets})
local notice = make("CanvasGroup", noticeGui, {AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, 0, 12),
    Size = UDim2.fromOffset(245, 42), BorderSizePixel = 0, BackgroundColor3 = reputationFlash})
edge(notice, 12)
local noticeText = label(notice, "", 16, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
noticeText.TextXAlignment = Enum.TextXAlignment.Center

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
local waitingChanged
local visibleCount = 0
local panelTween, statusTween
local reputationTween, reputationGlow, noticeTween
local lastLevel
local refresh
local layout

local function canStockCrop(item, step)
    if step ~= "Complete" then return item == player:GetAttribute("TutorialCropItem") end
    local request = config.Requests[item]
    return request and request.Weight > 0 and (lastLevel or 1) >= request.Level
end

local function available(item)
    local row = item and stock[item]
    local onStand = row and row.Amount or 0
    local canStock = math.min(inBag[item] or 0, config.StockLimit - onStand)
    local step = player:GetAttribute("TutorialStep")
    if not canStockCrop(item, step) then
        canStock = 0
    elseif step ~= "Complete" then
        canStock = math.min(canStock, (player:GetAttribute("TutorialRemaining") or 0) - onStand)
    end
    return math.max(0, canStock), onStand - (row and row.Reserved or 0)
end

local function showLevelUp(level)
    if reputationGlow then reputationGlow:Cancel() end
    reputation.BackgroundColor3 = reputationFlash
    reputationGlow = TweenService:Create(reputation, TweenInfo.new(.85), {BackgroundColor3 = reputationBase})
    reputationGlow:Play()
    if stand then return end

    if noticeTween then noticeTween:Cancel() end
    noticeGui.Enabled = true
    noticeText.Text = string.format("Market reputation  ·  Level %d", level)
    notice.GroupTransparency = 1
    notice.Position = UDim2.new(.5, 0, 0, 4)
    local enter = TweenService:Create(notice, TweenInfo.new(.24), {
        GroupTransparency = 0, Position = UDim2.new(.5, 0, 0, 12)})
    noticeTween = enter
    enter:Play()
    task.delay(2.8, function()
        if noticeTween ~= enter then return end
        local leave = TweenService:Create(notice, TweenInfo.new(.22), {GroupTransparency = 1})
        noticeTween = leave
        leave.Completed:Once(function()
            if noticeTween == leave then noticeTween = nil; noticeGui.Enabled = false end
        end)
        leave:Play()
    end)
end

local function updateReputation()
    local units = player:GetAttribute("MarketUnitsSold")
    local total = units or 0
    local level = config.ReputationLevel(total)
    local nextLevel = reputationLevels[level + 1]
    local raised = units ~= nil and lastLevel ~= nil and level > lastLevel
    local progress = 1
    reputationRank.Text = string.format("Lv. %d / %d", level, #reputationLevels)
    if nextLevel then
        local start = reputationLevels[level].Sold
        progress = (total - start) / (nextLevel.Sold - start)
        reputationDetail.Text = string.format("%d sold  ·  %d to next level", total, nextLevel.Sold - total)
    else
        reputationDetail.Text = string.format("%d sold  ·  Max level  ·  %s", total,
            total >= config.FinalSoldGoal and "Goal reached" or "Goal " .. config.FinalSoldGoal)
    end
    track.Visible = nextLevel ~= nil
    if reputationTween then reputationTween:Cancel() end
    if raised then fill.Size = UDim2.fromScale(0, 1) end
    local size = UDim2.fromScale(progress, 1)
    if stand and lastLevel then
        reputationTween = TweenService:Create(fill, TweenInfo.new(.28, Enum.EasingStyle.Quad), {Size = size})
        reputationTween:Play()
    else
        fill.Size = size
    end
    if raised then showLevelUp(level) end
    lastLevel = units and level or lastLevel
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
    if waitingChanged then waitingChanged:Disconnect(); waitingChanged = nil end
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
        local waiting = stand and stand:GetAttribute("MarketWaitingFor")
        status.Text = waiting or (#visible == 0 and "Harvest crops to stock your stand." or "Buyers shop while you farm.")
        if not waiting and selected and player:GetAttribute("TutorialStep") == "Complete" and not canStockCrop(selected, "Complete") then
            local request = config.Requests[selected]
            status.Text = request and request.Weight > 0 and "Buyers request this crop at market level " .. request.Level .. "." or
                "Buyers do not request this crop."
        end
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
player:GetAttributeChangedSignal("MarketUnitsSold"):Connect(function()
    updateReputation()
    scheduleRefresh()
end)
updateReputation()

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
    local compact = bounds.Y < 350
    local listTop = compact and 103 or 116
    local footer = compact and 124 or 141
    local height = visibleCount == 0 and 156 or math.min(435, listTop + footer + 7 + visibleCount * 58)
    panel.Size = UDim2.fromOffset(math.min(470, math.max(0, bounds.X - 18)), math.min(height, math.max(0, bounds.Y - 14)))
    reputation.Position = UDim2.fromOffset(12, compact and 50 or 56)
    reputation.Size = UDim2.new(1, -24, 0, compact and 46 or 53)
    list.Position = UDim2.fromOffset(12, listTop)
    list.Size = UDim2.new(1, -24, 1, -listTop - footer)
    list.Visible = visibleCount > 0
    controls.Position = UDim2.new(0, 12, 1, compact and -98 or -111)
    stockButton.Position = UDim2.fromOffset(0, compact and 48 or 52)
    returnButton.Position = UDim2.new(.5, 4, 0, compact and 48 or 52)
    status.Position = visibleCount == 0 and UDim2.fromOffset(14, listTop + 4) or UDim2.new(0, 14, 1, -footer)
    title.TextSize = compact and 21 or 24
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
        if waitingChanged then waitingChanged:Disconnect() end
        waitingChanged = stand:GetAttributeChangedSignal("MarketWaitingFor"):Connect(scheduleRefresh)
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
