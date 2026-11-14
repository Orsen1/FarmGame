local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local View = {}
View.__index = View
local ink = Color3.fromRGB(89, 55, 26)
local green = Color3.fromRGB(91, 148, 57)
local muted = Color3.fromRGB(191, 174, 130)

local function make(class, parent, properties)
    local object = Instance.new(class)
    for name, value in pairs(properties) do object[name] = value end
    object.Parent = parent
    return object
end

local function round(object, radius)
    make("UICorner", object, {CornerRadius = UDim.new(0, radius)})
end

local function label(parent, name, position, size, textSize)
    return make("TextLabel", parent, {Name = name, Position = position, Size = size,
        BackgroundTransparency = 1, Text = "", TextColor3 = ink, Font = Enum.Font.FredokaOne,
        TextSize = textSize, TextXAlignment = Enum.TextXAlignment.Left})
end

local function button(parent, name, text)
    local object = make("TextButton", parent, {Name = name, Text = text, Font = Enum.Font.FredokaOne,
        TextSize = 16, TextColor3 = Color3.fromRGB(255, 246, 221), BackgroundColor3 = green,
        BorderSizePixel = 0, AutoButtonColor = true})
    round(object, 10)
    local scale = make("UIScale", object, {})
    object.Activated:Connect(function()
        scale.Scale = 0.95
        TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), {Scale = 1}):Play()
    end)
    return object
end

local function enabled(object, value)
    object.Interactable = value
    object.AutoButtonColor = value
    object.BackgroundColor3 = value and green or muted
end

local function card(parent, name, title, height, order)
    local frame = make("Frame", parent, {Name = name, Size = UDim2.new(1, -6, 0, height),
        BackgroundColor3 = Color3.fromRGB(255, 239, 199), BorderSizePixel = 0, LayoutOrder = order})
    round(frame, 12)
    local icon = make("ImageLabel", frame, {Name = "Icon", BackgroundTransparency = 1,
        Position = UDim2.fromOffset(8, 7), Size = UDim2.fromOffset(36, 36), ScaleType = Enum.ScaleType.Fit})
    local caption = label(frame, "Title", UDim2.fromOffset(52, 5), UDim2.new(1, -158, 0, 23), 18)
    caption.Text = title
    local detail = label(frame, "Detail", UDim2.fromOffset(52, 29), UDim2.new(1, -158, 0, 20), 13)
    return {Frame = frame, Icon = icon, Title = caption, Detail = detail}
end

function View.new(playerGui)
    local self = setmetatable({}, View)
    self.Gui = make("ScreenGui", playerGui, {Name = "AnimalHomeGui", ResetOnSpawn = false,
        Enabled = false, DisplayOrder = 26, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets})
    self.Panel = make("CanvasGroup", self.Gui, {Name = "Panel", BackgroundColor3 = Color3.fromRGB(255, 221, 151),
        BorderSizePixel = 0, Size = UDim2.fromOffset(360, 425)})
    round(self.Panel, 16)
    make("UIStroke", self.Panel, {Color = Color3.fromRGB(126, 79, 39), Thickness = 2,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
    self.Icon = make("ImageLabel", self.Panel, {Name = "HomeIcon", BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 9), Size = UDim2.fromOffset(38, 38), ScaleType = Enum.ScaleType.Fit})
    self.Title = label(self.Panel, "Title", UDim2.fromOffset(60, 12), UDim2.new(1, -122, 0, 28), 22)
    self.Title.TextScaled = true
    make("UITextSizeConstraint", self.Title, {MinTextSize = 14, MaxTextSize = 22})
    self.Close = button(self.Panel, "Close", "X")
    self.Close.Position, self.Close.Size = UDim2.new(1, -54, 0, 8), UDim2.fromOffset(44, 44)
    self.Close.BackgroundColor3 = Color3.fromRGB(176, 69, 47)
    self.Summary = label(self.Panel, "Summary", UDim2.fromOffset(14, 55), UDim2.new(1, -28, 0, 20), 15)
    self.Actions = make("ScrollingFrame", self.Panel, {Name = "Actions", BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 80), Size = UDim2.new(1, -24, 1, -120), BorderSizePixel = 0,
        Active = true, ScrollingDirection = Enum.ScrollingDirection.Y, AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(), ScrollBarThickness = 4, ScrollBarImageColor3 = Color3.fromRGB(169, 111, 50)})
    make("UIListLayout", self.Actions, {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})
    self.Feed = card(self.Actions, "Feed", "Feed", 94, 1)
    self.Feed.Title.Size = UDim2.new(1, -62, 0, 22)
    self.Feed.Detail.Size = UDim2.new(1, -62, 0, 18)
    self.Feed.Detail.Position = UDim2.fromOffset(52, 27)
    self.FeedButtons = {}
    for _, amount in ipairs({1, 10, "Max"}) do
        local control = button(self.Feed.Frame, "Feed" .. amount, tostring(amount))
        control.Position, control.Size = UDim2.fromOffset(8, 44), UDim2.fromOffset(90, 44)
        self.FeedButtons[amount] = control
    end
    self.Eggs = card(self.Actions, "Eggs", "Eggs", 58, 2)
    self.Collect = button(self.Eggs.Frame, "Collect", "Collect")
    self.Collect.Position, self.Collect.Size = UDim2.new(1, -102, 0, 7), UDim2.fromOffset(94, 44)
    self.Chickens = card(self.Actions, "Chickens", "Chickens", 58, 3)
    self.Add = button(self.Chickens.Frame, "Add", "Add 1")
    self.Add.Position, self.Add.Size = UDim2.new(1, -102, 0, 7), UDim2.fromOffset(94, 44)
    self.Products = card(self.Actions, "Products", "Products", 82, 2)
    self.Products.Icon.Visible, self.Products.Detail.Visible = false, false
    self.Products.Title.Position = UDim2.fromOffset(10, 4)
    self.ProductItems = make("Frame", self.Products.Frame, {Name = "Items", BackgroundTransparency = 1,
        Position = UDim2.fromOffset(8, 32), Size = UDim2.new(1, -116, 0, 40)})
    make("UIListLayout", self.ProductItems, {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8)})
    self.CollectProducts = button(self.Products.Frame, "Collect", "Collect")
    self.CollectProducts.Position, self.CollectProducts.Size = UDim2.new(1, -102, 0, 29), UDim2.fromOffset(94, 44)
    self.ProductLabels = {}
    self.Recipes = card(self.Actions, "Recipes", "Recipes", 82, 3)
    self.Recipes.Detail.Size = UDim2.new(1, -62, 0, 20)
    self.Recipes.Title.Size = UDim2.new(1, -158, 0, 23)
    self.Work = button(self.Recipes.Frame, "Work", "Open")
    self.Work.Position, self.Work.Size = UDim2.new(1, -102, 0, 7), UDim2.fromOffset(94, 44)
    self.Track = make("Frame", self.Recipes.Frame, {Name = "Progress", Position = UDim2.fromOffset(10, 64),
        Size = UDim2.new(1, -20, 0, 8), BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(216, 173, 107)})
    round(self.Track, 4)
    self.Fill = make("Frame", self.Track, {Name = "Fill", Size = UDim2.fromScale(0, 1),
        BorderSizePixel = 0, BackgroundColor3 = green})
    round(self.Fill, 4)
    self.More = make("Frame", self.Actions, {Name = "More", Size = UDim2.new(1, -6, 0, 50),
        BackgroundTransparency = 1, LayoutOrder = 4})
    self.Shop = button(self.More, "Shop", "Buy chickens")
    self.Upgrade = button(self.More, "Upgrade", "Upgrade")
    self.Confirm = make("ScrollingFrame", self.Panel, {Name = "ConfirmUpgrade", BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 80), Size = UDim2.new(1, -28, 1, -120), Visible = false,
        BorderSizePixel = 0, Active = true, CanvasSize = UDim2.fromOffset(0, 172), ScrollBarThickness = 4,
        ScrollBarImageColor3 = Color3.fromRGB(169, 111, 50), ScrollingDirection = Enum.ScrollingDirection.Y})
    local question = label(self.Confirm, "Question", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 26), 20)
    question.Text = "Pack this coop?"
    local explanation = label(self.Confirm, "Explanation", UDim2.fromOffset(0, 30), UDim2.new(1, -6, 0, 72), 14)
    explanation.Text = "Place it again to expand. Animals, eggs and progress stay inside."
    explanation.TextWrapped = true
    explanation.TextYAlignment = Enum.TextYAlignment.Top
    self.Back = button(self.Confirm, "Back", "Back")
    self.Pack = button(self.Confirm, "Pack", "Pack coop")
    self.Back.Position, self.Back.Size = UDim2.fromOffset(0, 118), UDim2.new(0.5, -4, 0, 44)
    self.Pack.Position, self.Pack.Size = UDim2.new(0.5, 4, 0, 118), UDim2.new(0.5, -4, 0, 44)
    self.Status = label(self.Panel, "Status", UDim2.new(0, 14, 1, -34), UDim2.new(1, -28, 0, 28), 13)
    self.Status.TextWrapped = true
    self.Generation = 0
    return self
end

function View:Layout()
    local size = self.Gui.AbsoluteSize
    local touch = UserInputService.TouchEnabled
    local portrait = size.Y > size.X
    local width = math.min(360, size.X - 24)
    local height = math.min(self.DesiredHeight or 405, size.Y - 24)
    if touch and portrait then
        height = math.min(self.DesiredHeight or 405, size.Y * 0.57)
        self.Panel.AnchorPoint = Vector2.new(0.5, 1)
        self.OpenPosition = UDim2.new(0.5, 0, 1, -152)
    elseif touch then
        width = math.min(320, size.X * 0.44)
        height = math.max(180, size.Y - 108)
        self.Panel.AnchorPoint = Vector2.new(1, 0)
        self.OpenPosition = UDim2.new(1, -12, 0, 12)
    else
        self.Panel.AnchorPoint = Vector2.new(1, 0.5)
        self.OpenPosition = UDim2.new(1, -16, 0.5, 0)
    end
    self.Panel.Size = UDim2.fromOffset(width, height)
    if not self.Transitioning then self.Panel.Position = self.OpenPosition end
end

function View:Update(data)
    self.DesiredHeight = data.HasOutput and 405 or 342
    self.Products.Frame.Visible, self.Recipes.Frame.Visible = false, false
    self.Feed.Title.Text = "Feed"
    self.Chickens.Frame.Visible, self.More.Visible = true, true
    self.Title.Text, self.Icon.Image = data.Title, data.Icon
    self.Summary.Text = string.format("%s %d / %d  |  Hungry %d", data.PluralName, data.Count, data.Capacity, data.Hungry)
    self.Feed.Icon.Image, self.Eggs.Icon.Image, self.Chickens.Icon.Image = data.FeedIcon, data.EggIcon, data.AnimalIcon
    self.Feed.Detail.Text = data.FeedCapacity > 0 and string.format("%s %d  |  Stock %d / %d", data.FeedName, data.Wheat, data.Stock, data.FeedCapacity) or
        string.format("%s in inventory: %d", data.FeedName, data.Wheat)
    self.Eggs.Detail.Text = string.format("Ready: %d / %d", data.Eggs, data.EggCapacity)
    self.Chickens.Detail.Text = string.format("In inventory: %d", data.Owned)
    self.Chickens.Title.Text = data.PluralName
    self.Eggs.Frame.Visible = data.HasOutput
    self.Shop.Text = "Buy " .. string.lower(data.PluralName)
    local reserve = data.FeedCapacity > 0
    local amounts = reserve and {1, 10, "Max"} or {1, "Max"}
    self.FeedButtons[10].Visible = reserve
    for index, amount in ipairs(amounts) do
        local control = self.FeedButtons[amount]
        control.Position = UDim2.new((index - 1) / #amounts, 8, 0, 44)
        control.Size = UDim2.new(1 / #amounts, -16, 0, 44)
        control.Text = reserve and (amount == "Max" and "Max" or "+" .. amount) or (amount == "Max" and "Feed hungry" or "Feed 1")
        enabled(control, not data.Pending and data.Wheat > 0 and (reserve or data.Count > 0) and
            (reserve and data.Stock < data.FeedCapacity or not reserve and data.Hungry > 0))
    end
    enabled(self.Collect, not data.Pending and data.Eggs > 0)
    enabled(self.Add, not data.Pending and data.Owned > 0 and data.Count < data.Capacity)
    enabled(self.Shop, not data.Pending)
    enabled(self.Upgrade, not data.Pending)
    enabled(self.Pack, not data.Pending and data.UpgradeOwned > 0)
    self.Upgrade.Text = data.UpgradeOwned > 0 and "Upgrade" or "Buy upgrade"
    self.Upgrade.Visible = data.HasUpgrade
    self.Shop.Position, self.Shop.Size = UDim2.fromOffset(0, 3), UDim2.new(data.HasUpgrade and 0.5 or 1, data.HasUpgrade and -4 or 0, 0, 44)
    self.Upgrade.Position, self.Upgrade.Size = UDim2.new(0.5, 4, 0, 3), UDim2.new(0.5, -4, 0, 44)
end

function View:UpdateWorkshop(data)
    self.DesiredHeight = 405
    self.Title.Text, self.Icon.Image = data.Title, data.Icon
    self.Summary.Text = string.format("Milk %d / %d", data.Stock, data.Capacity)
    self.Feed.Title.Text, self.Feed.Icon.Image = "Milk tank", data.MilkIcon
    self.Feed.Detail.Text = string.format("Milk buckets in inventory: %d", data.Owned)
    self.Eggs.Frame.Visible, self.Chickens.Frame.Visible, self.More.Visible = false, false, false
    self.Products.Frame.Visible, self.Recipes.Frame.Visible = true, true
    self.FeedButtons[10].Visible = true
    for index, amount in ipairs({1, 10, "Max"}) do
        local control = self.FeedButtons[amount]
        control.Position, control.Size = UDim2.new((index - 1) / 3, 8, 0, 44), UDim2.new(1 / 3, -16, 0, 44)
        control.Text = amount == "Max" and "Max" or "+" .. amount
        enabled(control, not data.Pending and data.Owned > 0 and data.Stock < data.Capacity)
    end
    local total = 0
    for _, item in ipairs(data.Outputs) do
        local value = self.ProductLabels[item.Id]
        if not value then
            local frame = make("Frame", self.ProductItems, {Name = item.Id, BackgroundTransparency = 1, Size = UDim2.fromOffset(78, 40)})
            make("ImageLabel", frame, {Name = "Icon", Image = item.Icon, BackgroundTransparency = 1,
                Size = UDim2.fromOffset(36, 36), ScaleType = Enum.ScaleType.Fit})
            value = label(frame, "Amount", UDim2.fromOffset(37, 0), UDim2.fromOffset(41, 36), 16)
            self.ProductLabels[item.Id] = value
        end
        value.Text = "x" .. item.Amount
        total += item.Amount
    end
    enabled(self.CollectProducts, not data.Pending and total > 0)
    self.Recipes.Icon.Image = data.ResultIcon or data.Icon
    self.Recipes.Detail.Text = data.Busy and string.format("%s - %ds", data.ResultName, data.Remaining) or "Choose what to make"
    self.Track.Visible = data.Busy
    self.Fill.Size = UDim2.fromScale(data.Progress, 1)
    self.Work.Text = data.Busy and "View" or "Open"
    enabled(self.Work, not data.Pending)
end

function View:ShowConfirm(value)
    self.Confirm.Visible = value
    self.Actions.Visible = not value
    self.Confirm.CanvasPosition = Vector2.zero
end

function View:Message(text, success)
    self.Status.Text = text == "InventoryFull" and "Your inventory is full." or text
    self.Status.TextColor3 = success and Color3.fromRGB(75, 115, 47) or Color3.fromRGB(170, 55, 38)
end

function View:Show()
    self.Generation += 1
    local generation = self.Generation
    if self.Tween then self.Tween:Cancel() end
    self.Gui.Enabled = true
    self.Transitioning = true
    self:Layout()
    self.Panel.Position = self.OpenPosition + UDim2.fromOffset(24, 0)
    self.Panel.GroupTransparency = 1
    self.Tween = TweenService:Create(self.Panel, TweenInfo.new(0.18), {Position = self.OpenPosition, GroupTransparency = 0})
    self.Tween.Completed:Once(function()
        if self.Generation == generation then self.Transitioning = false;self:Layout() end
    end)
    self.Tween:Play()
end

function View:Hide(immediate)
    self.Generation += 1
    local generation = self.Generation
    self.Transitioning = false
    if self.Tween then self.Tween:Cancel() end
    if immediate then self.Gui.Enabled = false;return end
    self.Tween = TweenService:Create(self.Panel, TweenInfo.new(0.12), {GroupTransparency = 1})
    self.Tween:Play()
    task.delay(0.12, function() if self.Generation == generation then self.Gui.Enabled = false end end)
end

return View
