local UserInputService = game:GetService("UserInputService")

local ShopQuantityControls = {}

local buttons = {
    { Name = "MinusTenButton", Step = -10, Color = Color3.fromRGB(154, 73, 50) },
    { Name = "MinusButton", Step = -1, Color = Color3.fromRGB(180, 85, 60) },
    { Name = "PlusButton", Step = 1, Color = Color3.fromRGB(87, 135, 61) },
    { Name = "PlusTenButton", Step = 10, Color = Color3.fromRGB(68, 112, 48) },
}
local disabledColor = Color3.fromRGB(194, 165, 108)
local holdDelay = 0.36
local initialInterval = 0.17
local minimumInterval = 0.065
local touchTolerance = 12

function ShopQuantityControls.setSpacing(row, desktop)
    local gap = desktop and 0.036 or 0.016
    local countWidth = desktop and 0.20 or 0.212
    local width = (1 - countWidth - 4 * gap) / 4
    local position = 0
    for index, entry in ipairs(buttons) do
        local button = row[entry.Name]
        button.Position = UDim2.fromScale(position, 0)
        button.Size = UDim2.fromScale(width, 1)
        position += width + gap
        if index == 2 then
            row.SelectedAmountFrame.Position = UDim2.fromScale(position, 0)
            row.SelectedAmountFrame.Size = UDim2.fromScale(countWidth, 1)
            position += countWidth + gap
        end
    end
end

function ShopQuantityControls.update(row, canDecrease, canIncrease)
    for _, entry in ipairs(buttons) do
        local button = row[entry.Name]
        local enabled = (entry.Step < 0 and canDecrease) or (entry.Step > 0 and canIncrease)
        button.Interactable = enabled
        button.Selectable = enabled
        button.AutoButtonColor = enabled
        button.BackgroundColor3 = enabled and entry.Color or disabledColor
        local stroke = button:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke.Color = button.BackgroundColor3:Lerp(Color3.new(), 0.28)
        end
    end
end

function ShopQuantityControls.bind(row, canUse, changeAmount)
    local active
    local suppressed = setmetatable({}, { __mode = "k" })

    local function cancel()
        if active then
            suppressed[active.Input] = true
            active = nil
        end
    end

    local ended = UserInputService.InputEnded:Connect(function(input)
        if active and active.Input == input then
            active = nil
        end
    end)
    local changed = UserInputService.InputChanged:Connect(function(input)
        if active and active.Input == input and input.UserInputType == Enum.UserInputType.Touch
            and (input.Position - active.StartPosition).Magnitude > touchTolerance then
            cancel()
        end
    end)
    local focus = UserInputService.WindowFocusReleased:Connect(cancel)
    row.Destroying:Once(function()
        cancel()
        ended:Disconnect()
        changed:Disconnect()
        focus:Disconnect()
    end)

    for _, entry in ipairs(buttons) do
        local button = row[entry.Name]
        local function enabled()
            return button.Interactable and canUse()
        end

        button.Activated:Connect(function(input)
            if not suppressed[input] and enabled() then
                changeAmount(entry.Step)
            end
        end)
        button.MouseLeave:Connect(function()
            if active and active.Button == button and active.Input.UserInputType == Enum.UserInputType.MouseButton1 then
                cancel()
            end
        end)
        button.InputBegan:Connect(function(input)
            local kind = input.UserInputType
            if (kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch) or not enabled() then
                return
            end

            cancel()
            local press = { Input = input, Button = button, StartPosition = input.Position }
            active = press
            task.delay(holdDelay, function()
                local interval = initialInterval
                while active == press and enabled() and input.UserInputState ~= Enum.UserInputState.End
                    and input.UserInputState ~= Enum.UserInputState.Cancel do
                    suppressed[input] = true
                    changeAmount(entry.Step)
                    task.wait(interval)
                    interval = math.max(minimumInterval, interval * 0.84)
                end
                if active == press then
                    active = nil
                end
            end)
        end)
    end
    return cancel
end

return ShopQuantityControls
