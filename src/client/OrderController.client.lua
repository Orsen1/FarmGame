local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("OrderGui")
local panel = gui.Root.Panel
local body = panel.Body
local details = body.Details
local list = body.ItemList
local effects = gui.Root.Effects
local inventory = player:WaitForChild("Inventory")
local definitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local config = require(ReplicatedStorage.Configs.OrderConfig)
local event = ReplicatedStorage.RemoteEvents:WaitForChild("OrderEvent")
local current
local pending = false
local generation = 0
local visibilityTween
local scaleTween
local shownOrderId
local cards = {}
local hiddenPrompts = {}
local random = Random.new()
local ink = Color3.fromRGB(89, 55, 26)
local green = Color3.fromRGB(87, 147, 62)
local border = Color3.fromRGB(169, 111, 50)

local function money(cents)
    return string.format("$%.2f", cents / 100)
end

local function inventoryAmounts()
    local amounts = {}
    for _, slot in ipairs(inventory:GetChildren()) do
        local name = slot.ItemName.Value
        amounts[name] = (amounts[name] or 0) + slot.Amount.Value
    end
    return amounts
end

local function layout()
    local size = gui.Root.AbsoluteSize
    if size.X < 1 or size.Y < 1 then
        return
    end
    local count = math.max(1, #cards)
    local portrait = size.X < 560
    local short = not portrait and size.Y < 500
    local desiredWidth = portrait and 380 or math.max(480, count * 154 + 36 + (count - 1) * 12)
    local width = math.min(size.X - 28, desiredWidth)
    local contentWidth = width - 36
    local gridWidth = contentWidth - 8
    local minWidth = short and 120 or 150
    local columns = math.min(count, math.max(1, math.floor((gridWidth + 12) / (minWidth + 12))))
    if portrait then
        columns = math.min(columns, 2)
    end
    local rows = math.ceil(count / columns)
    local cardHeight = short and 124 or portrait and 148 or 230
    local cardWidth = math.min(240, (gridWidth - (columns - 1) * 12) / columns)
    local top = short and 58 or 76
    local actionHeight = short and 48 or 58
    local gridHeight = rows * cardHeight + (rows - 1) * 12 + 8
    local desiredHeight = top + gridHeight + actionHeight + 58
    local height = math.min(size.Y - (short and 24 or 28), desiredHeight)
    local listHeight = height - top - actionHeight - 58
    panel.Size = UDim2.fromOffset(width, height)
    panel.Header.TitleLabel.TextSize = portrait and 28 or short and 28 or 34
    panel.Header.Size = UDim2.new(1, -36, 0, 48)
    body.Position = UDim2.fromOffset(18, top)
    body.Size = UDim2.fromOffset(contentWidth, listHeight + 12 + actionHeight)
    list.Size = UDim2.fromOffset(contentWidth, listHeight)
    list.Grid.FillDirectionMaxCells = columns
    list.Grid.CellSize = UDim2.fromOffset(cardWidth, cardHeight)
    list.ScrollBarThickness = gridHeight > listHeight + 1 and 4 or 0
    details.Position = UDim2.fromOffset(0, listHeight + 12)
    details.Size = UDim2.fromOffset(contentWidth, actionHeight)
    details.RewardFrame.Position = UDim2.fromOffset(0, 0)
    details.RewardFrame.Size = UDim2.new(0.44, -6, 1, 0)
    details.RewardFrame.AmountLabel.TextSize = short and 28 or 32
    details.DeliverButton.Position = UDim2.new(0.44, 6, 0, 0)
    details.DeliverButton.Size = UDim2.new(0.56, -6, 1, 0)
    details.DeliverButton.TextSize = short and 24 or 26
    panel.StatusLabel.Position = UDim2.new(0, 18, 1, -30)
    panel.StatusLabel.Size = UDim2.new(1, -36, 0, 24)
    panel.StatusLabel.TextSize = short and 18 or 20
    for _, card in ipairs(cards) do
        local iconSize = short and 48 or portrait and 64 or math.min(112, cardWidth - 20)
        local iconTop = short and 6 or portrait and 8 or 12
        card.Frame.ItemIcon.Size = UDim2.fromOffset(iconSize, iconSize)
        card.Frame.ItemIcon.Position = UDim2.new(0.5, 0, 0, iconTop)
        card.Frame.ItemName.Position = UDim2.fromOffset(8, short and 58 or iconTop + iconSize + 8)
        card.Frame.ItemName.Size = UDim2.new(1, -16, 0, short and 24 or portrait and 26 or 30)
        card.Frame.ItemName.TextSize = short and 18 or cardWidth < 180 and 21 or 24
        card.Frame.CountLabel.Position = UDim2.new(0, 8, 1, -40)
        card.Frame.CountLabel.Size = UDim2.new(1, -16, 0, 30)
        card.Frame.CountLabel.TextSize = short and 24 or 28
        card.Frame.ProgressBar.Position = UDim2.new(0, 8, 1, -7)
        card.Frame.ProgressBar.Size = UDim2.new(1, -16, 0, 5)
    end
end

local function refresh()
    if not current then
        return
    end
    local order = current.Order
    if shownOrderId ~= order.Id then
        for _, card in ipairs(cards) do
            card.Frame:Destroy()
        end
        table.clear(cards)
        shownOrderId = order.Id
        list.CanvasPosition = Vector2.zero
        for index, item in ipairs(order.Items) do
            local frame = gui.Templates.ItemCard:Clone()
            frame.Name = "Item" .. index
            frame.LayoutOrder = index
            frame.ItemIcon.Image = definitions[item.ItemName].Icon or ""
            frame.ItemName.Text = definitions[item.ItemName].DisplayName or item.ItemName
            frame.Visible = true
            frame.Parent = list
            cards[index] = {Frame = frame}
        end
        layout()
    end
    local available = inventoryAmounts()
    local canDeliver = false
    for index, item in ipairs(order.Items) do
        local card = cards[index]
        local complete = item.Delivered == item.Amount
        local ready = not complete and (available[item.ItemName] or 0) > 0
        canDeliver = canDeliver or ready
        card.Frame.CountLabel.Text = string.format("%d / %d", item.Delivered, item.Amount)
        card.Frame.CountLabel.TextColor3 = complete and green or ink
        card.Frame.BackgroundColor3 = complete and Color3.fromRGB(225, 238, 188) or Color3.fromRGB(255, 240, 202)
        card.Frame.Outline.Color = (ready or complete) and green or border
        if card.ProgressTween then
            card.ProgressTween:Cancel()
        end
        card.ProgressTween = TweenService:Create(card.Frame.ProgressBar.Fill, TweenInfo.new(0.22), {
            Size = UDim2.fromScale(item.Delivered / item.Amount, 1),
        })
        card.ProgressTween:Play()
    end
    details.RewardFrame.AmountLabel.Text = "+" .. money(order.RewardCents)
    details.DeliverButton.Text = pending and "..." or "Deliver"
    details.DeliverButton.Interactable = canDeliver and not pending
    details.DeliverButton.AutoButtonColor = canDeliver and not pending
    details.DeliverButton.BackgroundColor3 = canDeliver and green or Color3.fromRGB(170, 151, 109)
end

local function pulse(card)
    local scale = card.Frame.ItemIcon.PulseScale
    local grow = TweenService:Create(scale, TweenInfo.new(0.13), {Scale = 1.14})
    grow:Play()
    grow.Completed:Once(function()
        if scale.Parent then
            TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back), {Scale = 1}):Play()
        end
    end)
end

local function celebrate(reward)
    local point = details.DeliverButton.AbsolutePosition + details.DeliverButton.AbsoluteSize / 2 - effects.AbsolutePosition
    local duration = config.Effects.Duration
    local colors = {Color3.fromRGB(250, 191, 64), Color3.fromRGB(255, 241, 181), green}
    for index = 1, config.Effects.Particles do
        local particle = Instance.new("Frame")
        particle.Name = "Confetti"
        particle.BorderSizePixel = 0
        particle.BackgroundColor3 = colors[(index - 1) % #colors + 1]
        particle.Size = UDim2.fromOffset(random:NextInteger(5, 9), random:NextInteger(8, 13))
        particle.AnchorPoint = Vector2.new(0.5, 0.5)
        particle.Position = UDim2.fromOffset(point.X, point.Y)
        particle.Rotation = random:NextNumber(-90, 90)
        particle.ZIndex = 51
        particle.Parent = effects
        TweenService:Create(particle, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.fromOffset(point.X + random:NextNumber(-150, 150), point.Y - random:NextNumber(80, 210)),
            Rotation = random:NextNumber(-360, 360), BackgroundTransparency = 1,
        }):Play()
        Debris:AddItem(particle, duration)
    end
    local rewardLabel = Instance.new("TextLabel")
    rewardLabel.Name = "RewardPopup"
    rewardLabel.BackgroundTransparency = 1
    rewardLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    rewardLabel.Position = UDim2.fromOffset(point.X, point.Y - 35)
    rewardLabel.Size = UDim2.fromOffset(240, 46)
    rewardLabel.Font = panel.Header.TitleLabel.Font
    rewardLabel.Text = "+" .. money(reward)
    rewardLabel.TextSize = 34
    rewardLabel.TextColor3 = Color3.fromRGB(255, 222, 117)
    rewardLabel.TextStrokeColor3 = ink
    rewardLabel.TextStrokeTransparency = 0.15
    rewardLabel.ZIndex = 52
    rewardLabel.Parent = effects
    TweenService:Create(rewardLabel, TweenInfo.new(duration), {
        Position = UDim2.fromOffset(point.X, point.Y - 115),
        TextTransparency = 1, TextStrokeTransparency = 1,
    }):Play()
    Debris:AddItem(rewardLabel, duration)
end

local function restorePrompts()
    for prompt, enabled in pairs(hiddenPrompts) do
        if prompt.Parent then
            prompt.Enabled = enabled
        end
    end
    table.clear(hiddenPrompts)
end

local function close(immediate)
    generation += 1
    local version = generation
    current, pending = nil, false
    restorePrompts()
    effects:ClearAllChildren()
    if visibilityTween then
        visibilityTween:Cancel()
    end
    if scaleTween then
        scaleTween:Cancel()
    end
    if immediate then
        gui.Enabled = false
        return
    end
    visibilityTween = TweenService:Create(panel, TweenInfo.new(0.16), {GroupTransparency = 1})
    visibilityTween:Play()
    task.delay(0.16, function()
        if generation == version then
            gui.Enabled = false
        end
    end)
end

local messages = {
    NoItems = "Bring the items shown above.",
    OrderChanged = "A new order is ready.",
    BalanceLimit = "Balance limit reached.",
    DataNotReady = "Loading...",
    TooFarAway = "Move closer.",
    BoardUnavailable = "Board unavailable.",
}

event.OnClientEvent:Connect(function(action, state, success, reason, value)
    if action == "Close" then
        close(true)
        return
    end
    if action == "Update" and (not current or current.BoardId ~= state.BoardId) then
        return
    end
    local previous = current and current.Order
    if action == "Open" then
        close(true)
        generation += 1
        for _, name in ipairs({"BuyGui", "SellGui"}) do
            local shop = playerGui:FindFirstChild(name)
            if shop then
                shop.MainFrame.Visible = false
            end
        end
        for _, object in ipairs(workspace.OrderBoards:GetDescendants()) do
            if object:IsA("ProximityPrompt") then
                hiddenPrompts[object] = object.Enabled
                object.Enabled = false
            end
        end
        gui.Enabled = true
        panel.GroupTransparency = 1
        panel.OpenScale.Scale = 0.96
        visibilityTween = TweenService:Create(panel, TweenInfo.new(0.2), {GroupTransparency = 0})
        scaleTween = TweenService:Create(panel.OpenScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Scale = 1})
        visibilityTween:Play()
        scaleTween:Play()
    end
    current, pending = state, false
    panel.Header.TitleLabel.Text = config.Boards[state.BoardId].DisplayName
    panel.StatusLabel.Text = ""
    if reason == "Completed" then
        panel.StatusLabel.Text = "Complete! +" .. money(value)
    elseif reason == "Delivered" then
        panel.StatusLabel.Text = "Delivered +" .. value
    elseif reason then
        panel.StatusLabel.Text = messages[reason] or "Please try again."
    end
    panel.StatusLabel.TextColor3 = success == false and Color3.fromRGB(166, 63, 38) or green
    refresh()
    layout()
    if reason == "Completed" then
        celebrate(value)
    elseif reason == "Delivered" and previous and previous.Id == state.Order.Id then
        for index, item in ipairs(state.Order.Items) do
            if item.Delivered > previous.Items[index].Delivered then
                pulse(cards[index])
            end
        end
    end
end)

details.DeliverButton.Activated:Connect(function()
    if not current or pending then
        return
    end
    pending = true
    generation += 1
    local version = generation
    refresh()
    event:FireServer(current.BoardId, current.Order.Id)
    task.delay(5, function()
        if current and pending and generation == version then
            pending = false
            panel.StatusLabel.Text = "Please try again."
            refresh()
        end
    end)
end)

panel.Header.CloseButton.Activated:Connect(function() close() end)
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and current and (input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Escape) then
        close()
    end
end)
gui.Root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
for _, slot in ipairs(inventory:GetChildren()) do
    slot.ItemName.Changed:Connect(refresh)
    slot.Amount.Changed:Connect(refresh)
end
player.CharacterRemoving:Connect(function() close(true) end)
player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
    if player:GetAttribute("DataLoaded") ~= true then
        close(true)
    end
end)
local elapsed = 0
RunService.Heartbeat:Connect(function(delta)
    elapsed += delta
    if elapsed < 0.25 or not current then
        return
    end
    elapsed = 0
    local board = workspace.OrderBoards:FindFirstChild(config.Boards[current.BoardId].ModelName)
    local root = board and board:FindFirstChild("InteractionRoot")
    local character = player.Character
    local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not playerRoot or not humanoid or humanoid.Health <= 0
        or (playerRoot.Position - root.Position).Magnitude > config.InteractionDistance + 1 then
        close(true)
    end
end)
layout()
