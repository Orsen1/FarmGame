local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ConstructionPromptView = {}
local WIDTH = 367
local PROMPT_WIDTH = 133
local INK = Color3.fromRGB(68, 40, 25)
local BORDER = Color3.fromRGB(112, 69, 40)
local HONEY = Color3.fromRGB(244, 204, 121)
local family = Font.fromEnum(Enum.Font.Nunito).Family
local bold = Font.new(family, Enum.FontWeight.Bold)
local heavy = Font.new(family, Enum.FontWeight.ExtraBold)

local function create(class, parent, properties)
    local node = Instance.new(class)
    for property, value in pairs(properties) do
        node[property] = value
    end
    node.Parent = parent
    return node
end

local function frame(class, parent, name, size, position, color)
    return create(class, parent, {
        Name = name,
        Size = size,
        Position = position,
        BackgroundColor3 = color or INK,
        BackgroundTransparency = color and 0 or 1,
        BorderSizePixel = 0
    })
end

local function decorate(node, radius, border, thickness)
    create("UICorner", node, {CornerRadius = UDim.new(0, radius)})
    if border then
        create("UIStroke", node, {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Color = border,
            Thickness = thickness or 1
        })
    end
end

local function label(parent, name, text, size, position, width, height, color, align, font)
    return create("TextLabel", parent, {
        Name = name,
        Text = text,
        TextSize = size,
        FontFace = font or heavy,
        TextColor3 = color or INK,
        TextXAlignment = align or Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(width, height),
        Position = position
    })
end

local function makeMaterial(parent, itemName, definition, index)
    local card = frame("Frame", parent, itemName, UDim2.fromOffset(200, 79),
        UDim2.fromOffset(12, 61 + (index - 1) * 87), Color3.fromRGB(255, 239, 199))
    decorate(card, 10, Color3.fromRGB(197, 141, 77))

    local tile = frame("Frame", card, "IconTile", UDim2.fromOffset(30, 30), UDim2.fromOffset(9, 5),
        Color3.fromRGB(255, 230, 173))
    decorate(tile, 7, Color3.fromRGB(218, 181, 113))
    create("ImageLabel", tile, {
        Name = "ItemIcon",
        BackgroundTransparency = 1,
        Image = definition.Icon or "",
        ScaleType = Enum.ScaleType.Fit,
        Size = UDim2.fromOffset(26, 26),
        Position = UDim2.fromOffset(2, 2)
    })

    label(card, "Material", definition.DisplayName or itemName, 14, UDim2.fromOffset(46, 5), 74, 30)
    local count = label(card, "Count", "", 15, UDim2.fromOffset(122, 5), 69, 30, INK, Enum.TextXAlignment.Right)

    local track = frame("Frame", card, "Track", UDim2.fromOffset(182, 7), UDim2.fromOffset(9, 40),
        Color3.fromRGB(226, 192, 138))
    decorate(track, 4)
    local progress = frame("Frame", track, "Progress", UDim2.fromScale(0, 1), UDim2.fromOffset(0, 0),
        Color3.fromRGB(116, 154, 65))
    decorate(progress, 4)

    label(card, "Caption", "Deposited", 11, UDim2.fromOffset(9, 52), 85, 18, Color3.fromRGB(121, 84, 58), nil, bold)
    local remaining = label(card, "Remaining", "", 12, UDim2.fromOffset(96, 52), 95, 18, Color3.fromRGB(113, 69, 37),
        Enum.TextXAlignment.Right)

    return {Count = count, Progress = progress, Remaining = remaining}
end

local function inputLabel(prompt, inputType)
    if inputType == Enum.ProximityPromptInputType.Touch then
        return "Tap"
    end
    if inputType == Enum.ProximityPromptInputType.Gamepad then
        return prompt.GamepadKeyCode.Name:gsub("^Button", "")
    end
    return prompt.KeyboardKeyCode.Name
end

function ConstructionPromptView.show(playerGui, prompt, object, step, definitions, inputType)
    local materials = {}
    for itemName in pairs(step.Inputs) do
        table.insert(materials, itemName)
    end
    table.sort(materials)
    local height = 150 + math.max(0, #materials - 1) * 87
    local gui = create("ScreenGui", playerGui, {
        Name = "ConstructionPromptGui",
        ResetOnSpawn = false,
        ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
    })
    local group = frame("Frame", gui, "PromptAndMaterials", UDim2.fromOffset(WIDTH, height), UDim2.fromOffset(0, 0))
    group.Visible = false
    local scale = create("UIScale", group, {})

    local promptHeight = inputType == Enum.ProximityPromptInputType.Touch and 52 or 48
    local button = frame("TextButton", group, "AddMaterials", UDim2.fromOffset(PROMPT_WIDTH, promptHeight),
        UDim2.fromOffset(0, (height - promptHeight) / 2), Color3.fromRGB(81, 56, 36))
    button.Text = ""
    button.Selectable = false
    decorate(button, 13, Color3.fromRGB(152, 112, 70), 1.25)
    local key = frame("Frame", button, "Key", UDim2.fromOffset(26, 27), UDim2.fromOffset(10, (promptHeight - 27) / 2), HONEY)
    decorate(key, 7, BORDER)
    label(key, "Input", inputLabel(prompt, inputType), 13, UDim2.fromOffset(0, 0), 26, 27, INK, Enum.TextXAlignment.Center)
    label(button, "Action", "Add Materials", 12, UDim2.fromOffset(43, 0), 83, promptHeight, Color3.fromRGB(255, 241, 202))

    local sidebar = frame("Frame", group, "Materials", UDim2.fromOffset(224, height), UDim2.fromOffset(143, 0),
        Color3.fromRGB(255, 220, 150))
    decorate(sidebar, 15, BORDER, 2)
    label(sidebar, "Context", "BLUEPRINT", 10, UDim2.fromOffset(12, 10), 200, 13, Color3.fromRGB(130, 83, 44))
    label(sidebar, "Stage", step.DisplayName, 22, UDim2.fromOffset(12, 23), 200, 27)

    local rows = {}
    for index, itemName in ipairs(materials) do
        rows[itemName] = makeMaterial(sidebar, itemName, definitions[itemName] or {}, index)
    end

    local function update()
        for itemName, required in pairs(step.Inputs) do
            local deposited = math.clamp(object:GetAttribute("ConstructionDeposited_" .. itemName) or 0, 0, required)
            local row = rows[itemName]
            row.Count.Text = deposited .. " / " .. required
            row.Remaining.Text = (required - deposited) .. " left"
            row.Progress.Size = UDim2.fromScale(deposited / required, 1)
        end
    end

    local pressed
    button.InputBegan:Connect(function(input)
        if not pressed and prompt.Enabled and (input.UserInputType == Enum.UserInputType.MouseButton1 or
            input.UserInputType == Enum.UserInputType.Touch) then
            pressed = input
            prompt:InputHoldBegin()
        end
    end)
    local released = UserInputService.InputEnded:Connect(function(input)
        if input == pressed then
            pressed = nil
            prompt:InputHoldEnd()
        end
    end)

    local function placeGroup(point, bounds, factor, bottom)
        local width = WIDTH * factor
        local scaledHeight = height * factor
        local maxX = math.max(8, bounds.X - width - 8)
        local maxY = math.max(8, bounds.Y - scaledHeight - bottom)
        local x = math.clamp(point.X - PROMPT_WIDTH * factor / 2, 8, maxX)
        local y = math.clamp(point.Y - scaledHeight / 2, 8, maxY)
        local shopGui = playerGui:FindFirstChild("BuyGui")
        local shop = shopGui and shopGui.Enabled and shopGui:FindFirstChild("ShopButton")
        if shop and shop.Visible then
            local start = shop.AbsolutePosition - gui.AbsolutePosition - Vector2.new(8, 8)
            local finish = start + shop.AbsoluteSize + Vector2.new(16, 16)
            if x < finish.X and x + width > start.X and y < finish.Y and y + scaledHeight > start.Y then
                local above = start.Y - scaledHeight
                local below = finish.Y
                if finish.X <= maxX then
                    x = finish.X
                elseif above >= 8 and (below > maxY or y - above <= below - y) then
                    y = above
                elseif below <= maxY then
                    y = below
                end
            end
        end
        group.Position = UDim2.fromOffset(x, y)
    end

    local function position()
        local camera = workspace.CurrentCamera
        local attachment = prompt.Parent
        if not camera or not attachment or not attachment:IsA("Attachment") or not prompt.Enabled then
            group.Visible = false
            return
        end

        local point, visible = camera:WorldToScreenPoint(attachment.WorldPosition)
        local bounds = gui.AbsoluteSize
        local bottom = UserInputService.TouchEnabled and 72 or 12
        if not visible or bounds.X <= 20 or bounds.Y <= bottom + 12 then
            group.Visible = false
            return
        end

        local factor = math.min(1, (bounds.X - 20) / WIDTH, (bounds.Y - bottom - 12) / height)
        scale.Scale = factor
        placeGroup(point, bounds, factor, bottom)
        group.Visible = true
    end

    update()
    position()
    local render = RunService.RenderStepped:Connect(position)

    return {
        update = update,
        destroy = function()
            render:Disconnect()
            released:Disconnect()
            if pressed and prompt.Parent then
                prompt:InputHoldEnd()
            end
            gui:Destroy()
        end
    }
end

return ConstructionPromptView
