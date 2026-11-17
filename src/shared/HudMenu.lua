local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Menu = {}
local buttons = {}
local ink = Color3.fromRGB(104, 65, 34)
local paper = Color3.fromRGB(255, 236, 190)
local green = Color3.fromRGB(103, 146, 67)

local function make(class, parent, properties)
    local object = Instance.new(class)
    for name, value in pairs(properties) do object[name] = value end
    object.Parent = parent
    return object
end

local function outline(object, radius, thickness)
    make("UICorner", object, {CornerRadius = UDim.new(0, radius)})
    make("UIStroke", object, {Color = ink, Thickness = thickness or 2,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end

local gui = make("ScreenGui", playerGui, {Name = "FarmMenuGui", ResetOnSpawn = false,
    DisplayOrder = 4, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
local panel = make("Frame", gui, {Name = "LeftMenu", BackgroundColor3 = Color3.fromRGB(225, 180, 112),
    BorderSizePixel = 0, Visible = false, AnchorPoint = Vector2.new(0, .5)})
outline(panel, 14, 3)
local grid = make("UIGridLayout", panel, {SortOrder = Enum.SortOrder.LayoutOrder,
    FillDirectionMaxCells = 2})
make("UIPadding", panel, {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
    PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8)})
Menu.Panel = panel

local function shape(parent, x, y, width, height, color)
    return make("Frame", parent, {Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, height),
        BackgroundColor3 = color, BorderSizePixel = 0})
end

local function icon(parent, kind)
    local frame = make("Frame", parent, {Name = "Icon", AnchorPoint = Vector2.new(.5, 0),
        Position = UDim2.new(.5, 0, 0, 7), Size = UDim2.fromOffset(32, 32), BackgroundTransparency = 1})
    if kind == "Shop" then
        shape(frame, 4, 13, 24, 17, paper)
        shape(frame, 0, 5, 32, 5, ink)
        shape(frame, 0, 10, 32, 7, Color3.fromRGB(184, 94, 47))
        shape(frame, 6, 10, 5, 7, paper)
        shape(frame, 20, 10, 5, 7, paper)
        shape(frame, 6, 21, 8, 6, Color3.fromRGB(119, 174, 161))
        shape(frame, 21, 20, 6, 10, ink)
    elseif kind == "Farm" then
        local roof = shape(frame, 5, 3, 22, 22, Color3.fromRGB(179, 87, 47))
        roof.Rotation = 45
        shape(frame, 1, 19, 30, 13, paper)
        shape(frame, 9, 16, 14, 16, paper)
        shape(frame, 14, 21, 6, 11, ink)
        shape(frame, 4, 23, 5, 5, green)
        shape(frame, 25, 23, 5, 5, green)
    elseif kind == "Sell" then
        local coin = shape(frame, 3, 1, 26, 30, Color3.fromRGB(238, 182, 70))
        outline(coin, 13, 1.5)
        make("TextLabel", coin, {Size = UDim2.fromScale(1, 1), Text = "$", TextSize = 25,
            BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextColor3 = ink})
    elseif kind == "Map" then
        for index, color in ipairs({paper, Color3.fromRGB(225, 202, 149), paper}) do
            local fold = shape(frame, 2 + (index - 1) * 10, index == 2 and 5 or 2, 10, 27, color)
            outline(fold, 2, 1)
        end
        local pin = shape(frame, 12, 8, 10, 10, green)
        outline(pin, 5, 1)
        local stem = shape(frame, 15, 15, 4, 8, green)
        stem.Rotation = 15
    elseif kind == "Journal" then
        local book = shape(frame, 3, 2, 26, 29, paper)
        book.Rotation = -5
        outline(book, 4, 1.5)
        shape(book, 5, 0, 3, 29, Color3.fromRGB(184, 130, 69))
        shape(book, 17, 0, 5, 16, green)
    else
        shape(frame, 2, 27, 28, 3, ink)
        for index, height in ipairs({11, 18, 25}) do
            shape(frame, 4 + (index - 1) * 9, 27 - height, 6, height,
                index == 3 and Color3.fromRGB(201, 143, 49) or green)
        end
    end
end

local function layout()
    local size = gui.AbsoluteSize
    local compact = size.X < 600 or size.Y < 450
    local cell = compact and 52 or 76
    local gap = compact and 6 or 8
    panel.Position = UDim2.new(0, 12, size.Y < 450 and .42 or .5, 0)
    panel.Size = UDim2.fromOffset(16 + cell * 2 + gap, 16 + math.ceil(#buttons / 2) * cell + gap * math.max(0, math.ceil(#buttons / 2) - 1))
    grid.CellSize, grid.CellPadding = UDim2.fromOffset(cell, cell), UDim2.fromOffset(gap, gap)
    for _, button in ipairs(buttons) do
        button.Caption.TextSize = compact and 12 or 16
        button.Caption.Size = UDim2.new(1, -4, 0, compact and 18 or 23)
        button.Caption.Position = UDim2.new(0, 2, 1, compact and -20 or -26)
        button.Icon.Position = UDim2.new(.5, 0, 0, compact and 4 or 9)
        button.Icon.UIScale.Scale = compact and .72 or 1
    end
end

local blockingAttributes = {"ProductionMode", "AnimalMenuOpen", "Milking", "FeederOpen", "Teleporting", "FarmJournalOpen", "WorldMapOpen", "FarmOverviewOpen"}
local function refresh()
    local visible = player:GetAttribute("DataLoaded") == true
    for _, attribute in ipairs(blockingAttributes) do if player:GetAttribute(attribute) then visible = false end end
    for _, name in ipairs({"BuyGui", "SellGui", "CropInfoGui", "OrderGui"}) do
        local other = playerGui:FindFirstChild(name)
        local window = other and (other:FindFirstChild("MainFrame") or other:FindFirstChild("Panel"))
        if other and other.Enabled and (name == "OrderGui" or window and window.Visible) then visible = false end
    end
    panel.Visible = visible
end

local function watchGui(other)
    if not table.find({"BuyGui", "SellGui", "CropInfoGui", "OrderGui"}, other.Name) then return end
    other:GetPropertyChangedSignal("Enabled"):Connect(refresh)
    local function watchWindow(window)
        if window.Name == "MainFrame" or window.Name == "Panel" then window:GetPropertyChangedSignal("Visible"):Connect(refresh) end
    end
    for _, child in ipairs(other:GetChildren()) do watchWindow(child) end
    other.ChildAdded:Connect(function(child) watchWindow(child);refresh() end)
    refresh()
end

function Menu.Add(name, caption, order)
    local existing = panel:FindFirstChild(name)
    if existing then return existing end
    local button = make("TextButton", panel, {Name = name, Text = "", LayoutOrder = order,
        BackgroundColor3 = paper, BorderSizePixel = 0, AutoButtonColor = true})
    outline(button, 10)
    icon(button, caption)
    make("UIScale", button.Icon, {Scale = 1})
    make("TextLabel", button, {Name = "Caption", Text = caption, BackgroundTransparency = 1,
        Font = Enum.Font.FredokaOne, TextColor3 = ink})
    table.insert(buttons, button)
    layout()
    refresh()
    return button
end

function Menu.CloseStorage()
    local storage = playerGui:FindFirstChild("StorageGui")
    local close = storage and storage:FindFirstChild("CloseMenu")
    if close then close:Invoke() end
end

gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
player:GetAttributeChangedSignal("DataLoaded"):Connect(refresh)
for _, attribute in ipairs(blockingAttributes) do player:GetAttributeChangedSignal(attribute):Connect(refresh) end
for _, other in ipairs(playerGui:GetChildren()) do if other:IsA("ScreenGui") then watchGui(other) end end
playerGui.ChildAdded:Connect(function(other) if other:IsA("ScreenGui") then watchGui(other) end end)
layout()
refresh()
return Menu
