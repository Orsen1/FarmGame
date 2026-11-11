local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local AnimalShopPromptView = {}
local panelColor = Color3.fromRGB(255, 220, 150)
local ink = Color3.fromRGB(89, 55, 26)

local function make(class, parent, properties)
    local object = Instance.new(class)
    for property, value in pairs(properties) do object[property] = value end
    object.Parent = parent
    return object
end

local function decorate(object, radius)
    make("UICorner", object, {CornerRadius = UDim.new(0, radius)})
    make("UIStroke", object, {Color = Color3.fromRGB(169, 111, 50), Thickness = 2,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end

function AnimalShopPromptView.show(playerGui, prompt, inputType)
    local gui = make("ScreenGui", playerGui, {Name = "AnimalShopPromptGui", ResetOnSpawn = false,
        DisplayOrder = 10, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets})
    local group = make("CanvasGroup", gui, {Name = "Prompt", Size = UDim2.fromOffset(268, 76),
        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = panelColor, BorderSizePixel = 0,
        GroupTransparency = 1, Visible = false})
    decorate(group, 14)
    local scale = make("UIScale", group, {Scale = 1})
    local button = make("TextButton", group, {Name = "BuyAnimals", Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false})
    local key = make("TextLabel", button, {Name = "Key", Position = UDim2.fromOffset(12, 20),
        Size = UDim2.fromOffset(38, 36), BackgroundColor3 = Color3.fromRGB(232, 168, 69),
        TextColor3 = ink, Font = Enum.Font.FredokaOne, TextSize = 16, BorderSizePixel = 0})
    decorate(key, 9)
    if inputType == Enum.ProximityPromptInputType.Touch then
        key.Text = "Tap"
    elseif inputType == Enum.ProximityPromptInputType.Gamepad then
        key.Text = prompt.GamepadKeyCode.Name:gsub("^Button", "")
    else
        key.Text = prompt.KeyboardKeyCode.Name
    end
    local context = make("TextLabel", button, {Name = "Context", Position = UDim2.fromOffset(62, 10),
        Size = UDim2.fromOffset(192, 20), BackgroundTransparency = 1, Text = "Empty coop",
        TextColor3 = Color3.fromRGB(130, 83, 44), Font = Enum.Font.FredokaOne, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left})
    local action = make("TextLabel", button, {Name = "Action", Position = UDim2.fromOffset(62, 32),
        Size = UDim2.fromOffset(192, 30), BackgroundTransparency = 1, Text = prompt.ActionText,
        TextColor3 = ink, Font = Enum.Font.FredokaOne, TextSize = 21,
        TextXAlignment = Enum.TextXAlignment.Left})
    action.TextScaled = true
    make("UITextSizeConstraint", action, {MinTextSize = 12, MaxTextSize = 21})
    local messageUntil = 0
    local function update()
        if os.clock() >= messageUntil then
            context.TextScaled = false
            context.Text = prompt:GetAttribute("Context") or "Empty coop"
            context.TextColor3 = Color3.fromRGB(130, 83, 44)
        end
        action.Text = prompt.ActionText
    end
    update()
    TweenService:Create(group, TweenInfo.new(0.18), {GroupTransparency = 0}):Play()
    local pressed
    button.InputBegan:Connect(function(input)
        if not pressed and prompt.Enabled and (input.UserInputType == Enum.UserInputType.Touch or
            input.UserInputType == Enum.UserInputType.MouseButton1) then
            pressed = input
            group.BackgroundColor3 = Color3.fromRGB(255, 244, 209)
            TweenService:Create(group, TweenInfo.new(0.2), {BackgroundColor3 = panelColor}):Play()
            prompt:InputHoldBegin()
        end
    end)
    local released = UserInputService.InputEnded:Connect(function(input)
        if input == pressed then
            pressed = nil
            if prompt.Parent then prompt:InputHoldEnd() end
        end
    end)
    local function position()
        local camera = workspace.CurrentCamera
        local attachment = prompt.Parent
        local shop = playerGui:FindFirstChild("BuyGui")
        if not camera or not attachment or not attachment:IsA("Attachment") or not prompt.Enabled or
            (shop and shop.Enabled and shop.MainFrame.Visible) then
            group.Visible = false
            return
        end
        local point, visible = camera:WorldToScreenPoint(attachment.WorldPosition)
        local bounds = gui.AbsoluteSize
        local factor = math.min(1, (bounds.X - 16) / 268)
        local bottom = UserInputService.TouchEnabled and 116 or 90
        if not visible or factor <= 0 or bounds.Y < 76 * factor + bottom + 16 then
            group.Visible = false
            return
        end
        update()
        scale.Scale = factor
        local halfWidth, halfHeight = 134 * factor, 38 * factor
        local minY, maxY = halfHeight + 8, bounds.Y - halfHeight - bottom
        local x = math.clamp(point.X, halfWidth + 8, bounds.X - halfWidth - 8)
        local y = math.clamp(point.Y - 20, minY, maxY)
        local shopButton = shop and shop:FindFirstChild("ShopButton")
        if shopButton and shopButton.Visible then
            local start = shopButton.AbsolutePosition - gui.AbsolutePosition
            local finish = start + shopButton.AbsoluteSize
            if x + halfWidth > start.X - 8 and x - halfWidth < finish.X + 8 and
                y + halfHeight > start.Y - 8 and y - halfHeight < finish.Y + 8 then
                local below = finish.Y + halfHeight + 12
                local above = start.Y - halfHeight - 12
                if below <= maxY then y = below
                elseif above >= minY then y = above end
            end
        end
        group.Position = UDim2.fromOffset(x, y)
        group.Visible = true
    end
    position()
    local render = RunService.RenderStepped:Connect(position)
    return {
        update = update,
        message = function(text, success)
            context.Text = text
            context.TextColor3 = success and Color3.fromRGB(75, 115, 47) or Color3.fromRGB(160, 56, 39)
            context.TextScaled = true
            context.TextWrapped = true
            messageUntil = os.clock() + 2.5
        end,
        destroy = function()
            render:Disconnect()
            released:Disconnect()
            if pressed and prompt.Parent then prompt:InputHoldEnd() end
            gui:Destroy()
        end
    }
end

return AnimalShopPromptView
