local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local definitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local recipes = require(ReplicatedStorage.Configs.ProductionRecipes)
local View = {}
View.__index = View

local colors = {
    Panel = Color3.fromRGB(255, 220, 150), Card = Color3.fromRGB(255, 239, 199),
    Ink = Color3.fromRGB(89, 55, 26), Border = Color3.fromRGB(169, 111, 50),
    Button = Color3.fromRGB(232, 168, 69), Green = Color3.fromRGB(116, 154, 65),
    Muted = Color3.fromRGB(192, 169, 131), Error = Color3.fromRGB(166, 63, 38),
}
local function make(class, name, parent, props)
    local object = Instance.new(class)
    object.Name = name
    for property, value in pairs(props or {}) do object[property] = value end
    object.Parent = parent
    return object
end
local function round(object, radius)
    make("UICorner", "Corner", object, {CornerRadius = UDim.new(0, radius or 12)})
    make("UIStroke", "Outline", object, {Color = colors.Border, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end
local function label(name, parent, props)
    local object = make("TextLabel", name, parent, {
        BackgroundTransparency = 1, TextColor3 = colors.Ink, Font = Enum.Font.FredokaOne,
        TextSize = 16, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    })
    for property, value in pairs(props or {}) do object[property] = value end
    return object
end
local function button(name, parent, text)
    local object = make("TextButton", name, parent, {
        BackgroundColor3 = colors.Button, BorderSizePixel = 0, Text = text,
        TextColor3 = colors.Ink, Font = Enum.Font.FredokaOne, TextSize = 16,
        TextWrapped = true, AutoButtonColor = true,
    })
    round(object, 10)
    return object
end
local function scroll(name, parent)
    return make("ScrollingFrame", name, parent, {
        BackgroundTransparency = 1, BorderSizePixel = 0, Active = true,
        ScrollingDirection = Enum.ScrollingDirection.Y, AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(), ScrollBarThickness = 5, ScrollBarImageColor3 = colors.Border,
        ClipsDescendants = true, ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
    })
end

function View.Build(parent)
    local gui = make("ScreenGui", "ProductionGui", parent, {
        Enabled = false, ResetOnSpawn = false, DisplayOrder = 30,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = false,
    })
    local root = make("Frame", "Root", gui, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1})
    local close = button("CloseButton", root, "X")
    close.Position, close.Size = UDim2.fromOffset(12, 12), UDim2.fromOffset(48, 48)
    close.TextSize = 30
    local panel = make("CanvasGroup", "Panel", root, {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.fromOffset(360, 540), BackgroundColor3 = colors.Panel, BorderSizePixel = 0,
    })
    round(panel, 16)
    label("Title", panel, {Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 28),
        Text = "Production", Font = Enum.Font.FredokaOne, TextSize = 22})
    label("Subtitle", panel, {Position = UDim2.fromOffset(16, 42), Size = UDim2.new(1, -32, 0, 22), Text = "Choose a recipe"})
    local body = make("CanvasGroup", "Body", panel, {BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 74), Size = UDim2.new(1, -24, 1, -86)})
    local list = scroll("RecipeList", body)
    list.Size = UDim2.fromScale(1, 1)
    make("UIListLayout", "ListLayout", list, {Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder})
    label("EmptyLabel", list, {Size = UDim2.new(1, -12, 0, 80), Text = "No recipes", Visible = false})
    local work = make("Frame", "WorkPanel", body, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false})
    scroll("RecipeSummary", work)
    label("StatusLabel", work, {Text = "Hold to work", TextSize = 15})
    local progress = make("Frame", "ProgressBar", work, {BackgroundColor3 = colors.Muted, BorderSizePixel = 0, ClipsDescendants = true})
    make("UICorner", "Corner", progress, {CornerRadius = UDim.new(0, 6)})
    local fill = make("Frame", "Fill", progress, {Size = UDim2.fromScale(0, 1), BackgroundColor3 = colors.Green, BorderSizePixel = 0})
    make("UICorner", "Corner", fill, {CornerRadius = UDim.new(0, 6)})
    label("TimeLabel", work, {Text = "0s", TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center})
    button("BackButton", work, "Recipes")
    button("StartButton", work, "Hold E")
    local templates = make("Folder", "Templates", gui)
    local card = button("RecipeCard", templates, "")
    card.BackgroundColor3 = colors.Card
    card.Visible = false
    card.Size = UDim2.new(1, -10, 0, 160)
    local content = make("Frame", "Content", card, {Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 1, -20), BackgroundTransparency = 1})
    make("UIListLayout", "ListLayout", content, {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder})
    local row = make("Frame", "ItemRow", templates, {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Visible = false})
    make("ImageLabel", "Icon", row, {Position = UDim2.fromOffset(0, 2), Size = UDim2.fromOffset(36, 36),
        BackgroundTransparency = 1, Image = "", ScaleType = Enum.ScaleType.Fit})
    label("ItemName", row, {Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -110, 1, 0), TextSize = 15})
    label("Amount", row, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
        Size = UDim2.fromOffset(66, 40), TextSize = 16, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Right})
    return gui
end

local function sortedKeys(items)
    local result = {}
    for name in pairs(items) do table.insert(result, name) end
    table.sort(result)
    return result
end

function View.new(gui)
    local self = setmetatable({}, View)
    self.Gui, self.Root, self.Panel = gui, gui.Root, gui.Root.Panel
    self.Root.CloseButton.Text = "X"
    self.Body, self.Templates = self.Panel.Body, gui.Templates
    self.Work, self.List = self.Body.WorkPanel, self.Body.RecipeList
    for _, object in ipairs(gui:GetDescendants()) do
        if object:IsA("TextLabel") or object:IsA("TextButton") then
            object.Font = Enum.Font.FredokaOne
        end
    end
    self.MaterialRows, self.Cards, self.CardLayouts = {}, {}, {}
    if not self.List:FindFirstChild("CardPadding") then
        make("UIPadding", "CardPadding", self.List, {
            PaddingLeft = UDim.new(0, 0), PaddingTop = UDim.new(0, 4),
            PaddingRight = UDim.new(0, 0), PaddingBottom = UDim.new(0, 4),
        })
    end
    self.List.ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    self.InputConnection = UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
        if self.LastState then self:UpdateState(self.LastState) end
    end)
    self.LayoutConnection = self.Root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:Layout() end)
    self:Layout()
    return self
end

function View:Layout()
    local size = self.Root.AbsoluteSize
    if size.X < 1 or size.Y < 1 then return end
    self.Portrait = size.Y > size.X
    self.Compact = not self.Portrait and size.Y < 420
    local width = self.Portrait and size.X - 24 or math.clamp(size.X * 0.33, 290, 380)
    for card, layout in pairs(self.CardLayouts) do
        if card.Parent then
            self:LayoutCard(card, layout, width - 56)
        else
            self.CardLayouts[card] = nil
        end
    end
    local contentHeight = self.RecipeId and 222 or 80
    if self.RecipeId then
        local card = self.Work.RecipeSummary:FindFirstChild(self.RecipeId)
        if card then contentHeight = card.Size.Y.Offset + 112 end
    elseif #self.Cards > 0 then
        contentHeight = 8
        for index, card in ipairs(self.Cards) do
            contentHeight += card.Size.Y.Offset + (index > 1 and 12 or 0)
        end
    end
    local maxHeight = self.Portrait and math.min(size.Y * 0.5, 420) or math.min(size.Y - 24, 420)
    local panelHeight = math.min(contentHeight + 66, maxHeight)
    if self.Portrait then
        self.OpenPosition = UDim2.new(0.5, 0, 1, -12)
        self.Panel.AnchorPoint = Vector2.new(0.5, 1)
        self.Panel.Size = UDim2.fromOffset(width, panelHeight)
    else
        self.OpenPosition = UDim2.new(1, -16, 0.5, 0)
        self.Panel.AnchorPoint = Vector2.new(1, 0.5)
        self.Panel.Size = UDim2.fromOffset(width, panelHeight)
    end
    if not self.Transitioning then self.Panel.Position = self.OpenPosition end
    self.Panel.Title.Position = UDim2.fromOffset(16, 10)
    self.Panel.Title.TextSize = 26
    self.Panel.Subtitle.Visible = false
    self.Body.Position = UDim2.fromOffset(12, 50)
    self.Body.Size = UDim2.new(1, -24, 1, -62)
    local height = self.Panel.Size.Y.Offset - 62
    local summaryHeight = math.max(54, height - 104)
    self.Work.RecipeSummary.Size = UDim2.new(1, 0, 0, summaryHeight)
    self.Work.StatusLabel.Position = UDim2.fromOffset(0, summaryHeight + 2)
    self.Work.StatusLabel.Size = UDim2.new(0.66, 0, 0, 22)
    self.Work.StatusLabel.TextSize = 17
    self.Work.ProgressBar.Position = UDim2.fromOffset(0, summaryHeight + 30)
    self.Work.ProgressBar.Size = UDim2.new(1, 0, 0, 10)
    self.Work.TimeLabel.AnchorPoint = Vector2.new(1, 0)
    self.Work.TimeLabel.Position = UDim2.new(1, 0, 0, summaryHeight + 2)
    self.Work.TimeLabel.Size = UDim2.new(0.34, 0, 0, 22)
    self.Work.TimeLabel.TextXAlignment = Enum.TextXAlignment.Right
    self.Work.TimeLabel.TextSize = 18
    self.Work.BackButton.Position = UDim2.new(0, 0, 1, -48)
    self.Work.BackButton.Size = UDim2.new(0.34, -6, 0, 48)
    self.Work.StartButton.Position = UDim2.new(0.34, 6, 1, -48)
    self.Work.StartButton.Size = UDim2.new(0.66, -6, 0, 48)
    self.Work.StartButton.TextSize = 20
end

function View:PressFeedback(button)
    local outline = button:FindFirstChild("Outline")
    if outline then
        outline.Color, outline.Thickness = colors.Green, 3
        TweenService:Create(outline, TweenInfo.new(0.28), {Color = colors.Border, Thickness = 2}):Play()
    end
    local original = button.BackgroundColor3
    button.BackgroundColor3 = Color3.fromRGB(255, 250, 225)
    TweenService:Create(button, TweenInfo.new(0.28), {BackgroundColor3 = original}):Play()
end

function View:LayoutCard(card, layout, availableWidth)
    local tileWidth, tileHeight, plusWidth = 76, 94, 18
    local inputColumns, outputColumns = 1, 1
    local function groupWidth(columns)
        return columns * tileWidth + (columns - 1) * plusWidth
    end
    while groupWidth(inputColumns) + groupWidth(outputColumns) + 56 + tileWidth + plusWidth <= availableWidth do
        local moreInputs = inputColumns < #layout.Inputs
        local moreOutputs = outputColumns < #layout.Outputs
        if moreInputs and (not moreOutputs or #layout.Inputs / inputColumns >= #layout.Outputs / outputColumns) then
            inputColumns += 1
        elseif moreOutputs then
            outputColumns += 1
        else
            break
        end
    end
    local function arrange(items, columns)
        local width = groupWidth(columns)
        local rows = math.ceil(#items / columns)
        local height = rows * tileHeight + math.max(0, rows - 1) * plusWidth
        for index, item in ipairs(items) do
            local row = math.floor((index - 1) / columns)
            local column = (index - 1) % columns
            local count = math.min(columns, #items - row * columns)
            local left = (width - groupWidth(count)) / 2
            item.Row.Position = UDim2.fromOffset(left + column * (tileWidth + plusWidth), row * (tileHeight + plusWidth))
            if item.Plus then
                if column + 1 < columns then
                    item.Plus.Position = UDim2.fromOffset(left + column * (tileWidth + plusWidth) + tileWidth, row * (tileHeight + plusWidth) + 22)
                else
                    item.Plus.Position = UDim2.fromOffset((width - plusWidth) / 2, row * (tileHeight + plusWidth) + tileHeight)
                end
            end
        end
        return width, height
    end
    local inputWidth, inputHeight = arrange(layout.Inputs, inputColumns)
    local outputWidth, outputHeight = arrange(layout.Outputs, outputColumns)
    local height = math.max(inputHeight, outputHeight)
    local left = (availableWidth - inputWidth - outputWidth - 56) / 2
    layout.InputGroup.Position = UDim2.fromOffset(left, (height - inputHeight) / 2)
    layout.InputGroup.Size = UDim2.fromOffset(inputWidth, inputHeight)
    layout.OutputGroup.Position = UDim2.fromOffset(left + inputWidth + 56, (height - outputHeight) / 2)
    layout.OutputGroup.Size = UDim2.fromOffset(outputWidth, outputHeight)
    layout.Direction.Position = UDim2.fromOffset(left + inputWidth + 14, (height - tileHeight) / 2 + 18)
    if layout.Duration then
        layout.Duration.Position = UDim2.fromOffset(left + inputWidth + 8, (height - tileHeight) / 2 + 64)
    end
    card.Size = UDim2.new(1, -8, 0, height + 20)
end

function View:CreateCard(recipeId, parent, showOwned)
    local recipe = recipes[recipeId]
    if not recipe then return end
    local card = self.Templates.RecipeCard:Clone()
    card.Name, card.Parent, card.Visible = recipeId, parent, true
    card.AutoButtonColor = false
    card.Content.ListLayout:Destroy()
    card.Content.Position = UDim2.fromOffset(12, 10)
    card.Content.Size = UDim2.new(1, -24, 1, -20)
    local layout = {Inputs = {}, Outputs = {}}
    local function group(items, input)
        local container = make("Frame", input and "Inputs" or "Outputs", card.Content, {BackgroundTransparency = 1})
        local keys = sortedKeys(items)
        local entries = input and layout.Inputs or layout.Outputs
        for index, name in ipairs(keys) do
            local row = self.Templates.ItemRow:Clone()
            local definition = definitions[name]
            row.Name, row.Parent, row.Visible = name, container, true
            row.Size = UDim2.fromOffset(76, 94)
            row.Icon.AnchorPoint = Vector2.new(0.5, 0)
            row.Icon.Position = UDim2.fromScale(0.5, 0)
            row.Icon.Size = UDim2.fromOffset(64, 64)
            row.Icon.BackgroundTransparency = 0
            row.Icon.BackgroundColor3 = input and Color3.fromRGB(255, 228, 174) or Color3.fromRGB(228, 231, 187)
            row.Icon.Image = definition.Icon or ""
            make("UICorner", "Corner", row.Icon, {CornerRadius = UDim.new(0, 10)})
            make("UIStroke", "Outline", row.Icon, {Color = colors.Border, Thickness = 1, Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
            row.ItemName.Position = UDim2.fromOffset(0, 68)
            row.ItemName.Size = UDim2.fromOffset(76, 24)
            row.ItemName.Text = definition.DisplayName or name
            row.ItemName.TextXAlignment = Enum.TextXAlignment.Center
            row.ItemName.TextScaled = true
            make("UITextSizeConstraint", "TextLimit", row.ItemName, {MinTextSize = 12, MaxTextSize = 16})
            row.Amount.AnchorPoint = Vector2.new(1, 1)
            row.Amount.Position = UDim2.new(0.5, 32, 0, 64)
            row.Amount.Size = UDim2.fromOffset(showOwned and input and 52 or 30, 22)
            row.Amount.BackgroundTransparency = 0
            row.Amount.BackgroundColor3 = colors.Card
            row.Amount.TextXAlignment = Enum.TextXAlignment.Center
            row.Amount.Text = tostring(items[name])
            row.Amount.TextScaled = true
            row.Amount.ZIndex = row.Icon.ZIndex + 1
            make("UICorner", "Corner", row.Amount, {CornerRadius = UDim.new(0, 6)})
            make("UIStroke", "Outline", row.Amount, {Color = colors.Border, Thickness = 1, Transparency = 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
            make("UITextSizeConstraint", "TextLimit", row.Amount, {MinTextSize = 10, MaxTextSize = 17})
            local entry = {Row = row}
            if index < #keys then
                entry.Plus = label("Plus" .. index, container, {Size = UDim2.fromOffset(18, 18), Text = "+", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center})
            end
            table.insert(entries, entry)
            if input and showOwned then
                table.insert(self.MaterialRows, {Row = row, Name = name, Required = items[name]})
            end
        end
        return container
    end
    layout.InputGroup = group(recipe.Inputs, true)
    layout.OutputGroup = group(recipe.Outputs, false)
    local arrow = make("Frame", "Direction", card.Content, {Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1})
    make("Frame", "Shaft", arrow, {Position = UDim2.fromOffset(0, 12), Size = UDim2.fromOffset(24, 4), BackgroundColor3 = colors.Ink, BorderSizePixel = 0})
    make("Frame", "Upper", arrow, {Position = UDim2.fromOffset(16, 8), Size = UDim2.fromOffset(12, 4), Rotation = 45, BackgroundColor3 = colors.Ink, BorderSizePixel = 0})
    make("Frame", "Lower", arrow, {Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(12, 4), Rotation = -45, BackgroundColor3 = colors.Ink, BorderSizePixel = 0})
    layout.Direction = arrow
    if not showOwned then
        layout.Duration = label("Duration", card.Content, {Size = UDim2.fromOffset(40, 24), Text = string.format("%gs", recipe.Duration), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center})
    end
    self.CardLayouts[card] = layout
    self:LayoutCard(card, layout, self.Panel.Size.X.Offset - 56)
    return card
end

function View:ShowRecipes(station, onSelect)
    self.Station = station
    for _, card in ipairs(self.Cards) do card:Destroy() end
    self.Cards = {}
    local definition = definitions[station:GetAttribute("ItemName") or station.Name] or {}
    for order, recipeId in ipairs(definition.Recipes or {}) do
        if recipes[recipeId] then
            local card = self:CreateCard(recipeId, self.List, false)
            card.LayoutOrder = order
            card.Activated:Connect(function()
                self:PressFeedback(card)
                onSelect(recipeId)
            end)
            table.insert(self.Cards, card)
        end
    end
    self.List.EmptyLabel.Visible = #self.Cards == 0
    self.List.CanvasPosition = Vector2.zero
    self.Panel.Title.Text = definition.DisplayName or station.Name
    self:Layout()
end

function View:SetRecipe(recipeId)
    if self.Body:IsA("CanvasGroup") then
        if self.BodyTween then self.BodyTween:Cancel() end
        self.Body.GroupTransparency = 0.3
        self.BodyTween = TweenService:Create(self.Body, TweenInfo.new(0.15), {GroupTransparency = 0})
        self.BodyTween:Play()
    end
    self.RecipeId = recipeId
    self.List.Visible, self.Work.Visible = recipeId == nil, recipeId ~= nil
    self.Work.BackButton.Text = "Recipes"
    self.MaterialRows = {}
    for _, child in ipairs(self.Work.RecipeSummary:GetChildren()) do child:Destroy() end
    if recipeId then
        local card = self:CreateCard(recipeId, self.Work.RecipeSummary, true)
        card.Position = UDim2.fromOffset(4, 4)
        card.Active, card.AutoButtonColor, card.Selectable = false, false, false
        self:PressFeedback(card)
        self.Work.RecipeSummary.CanvasPosition = Vector2.zero
    end
    self:Layout()
end

function View:UpdateMaterials(inventory)
    self.Inventory = inventory
    local counts = {}
    if inventory then
        for _, slot in ipairs(inventory:GetChildren()) do
            local name, amount = slot:FindFirstChild("ItemName"), slot:FindFirstChild("Amount")
            if name and amount then counts[name.Value] = (counts[name.Value] or 0) + amount.Value end
        end
    end
    local station = self.Station
    local definition = station and definitions[station:GetAttribute("ItemName") or station.Name]
    if definition and definition.AutomaticProduction then
        for _, value in ipairs(station.OutputInventory:GetChildren()) do
            if value:IsA("IntValue") then counts[value.Name] = (counts[value.Name] or 0) + value.Value end
        end
        counts[definition.MilkTank.Item] = station:GetAttribute("MilkStock") or 0
    end
    local enough = true
    for _, item in ipairs(self.MaterialRows) do
        local owned = counts[item.Name] or 0
        item.Row.Amount.Text = owned .. "/" .. item.Required
        item.Row.Amount.TextColor3 = owned >= item.Required and colors.Ink or colors.Error
        if owned < item.Required then enough = false end
    end
    self.Enough = enough
    return enough
end

function View:UpdateState(state)
    self.LastState = state
    self.Busy = state.Busy == true
    local touch = UserInputService.PreferredInput == Enum.PreferredInput.Touch
    self.Work.StartButton.Text = state.Automatic and (self.Busy and "Working..." or touch and "Start" or "Start E") or touch and "Hold" or "Hold E"
    self.Work.StartButton.BackgroundColor3 = (self.Enough or self.Busy) and colors.Button or colors.Muted
    self.Work.StartButton.Interactable = state.Automatic and not self.Busy and self.Enough or not state.Automatic and (self.Enough or self.Busy)
    self.Work.BackButton.Interactable = not self.Busy
    self.Work.BackButton.AutoButtonColor = not self.Busy
    self.Work.BackButton.BackgroundColor3 = self.Busy and colors.Muted or colors.Button
    local messages = {
        Working = "Working",
        Released = "Cancelled",
        Completed = "Ready to collect",
        NotEnoughItems = "Need materials",
        InvalidOutputInventory = "Storage error",
        MissingOutputInventory = "Storage missing",
        Ready = "",
        Processing = "Working. You can leave.",
    }
    self.Work.StatusLabel.Text = not self.Enough and not self.Busy and "Need materials" or (messages[state.Message] or "")
    if state.Automatic then
        if state.Phase == "Processing" then self.Work.StatusLabel.Text = "Working. You can leave."
        elseif state.Phase == "Loading" then self.Work.StatusLabel.Text = "Loading..."
        elseif state.Message == "Completed" then self.Work.StatusLabel.Text = "Ready to collect"
        elseif not self.Enough and self.RecipeId and recipes[self.RecipeId].Inputs[definitions[self.Station:GetAttribute("ItemName") or self.Station.Name].MilkTank.Item] then
            self.Work.StatusLabel.Text = "Fill the milk tank"
        elseif self.Enough then self.Work.StatusLabel.Text = string.format("Milk tank: %d / %d", self.Station:GetAttribute("MilkStock") or 0,
            definitions[self.Station:GetAttribute("ItemName") or self.Station.Name].MilkTank.Capacity) end
    end
end

function View:UpdateProgress(state)
    local fraction, remaining = 0, 0
    if state.Busy and state.Duration > 0 then
        local elapsed = workspace:GetServerTimeNow() - state.StartedAt
        fraction = math.clamp(elapsed / state.Duration, 0, 1)
        remaining = math.max(0, state.Duration - elapsed)
    end
    self.Work.ProgressBar.Fill.Size = UDim2.fromScale(fraction, 1)
    self.Work.TimeLabel.Text = state.Busy and string.format("%.1fs", remaining) or string.format("%gs", (self.RecipeId and recipes[self.RecipeId].Duration) or 0)
end

function View:Show()
    self.TransitionId = (self.TransitionId or 0) + 1
    self.Gui.Enabled, self.Transitioning = true, true
    self:Layout()
    self.Panel.Position = self.OpenPosition + (self.Portrait and UDim2.fromOffset(0, 36) or UDim2.fromOffset(36, 0))
    self.Panel.GroupTransparency = 1
    if self.Tween then self.Tween:Cancel() end
    self.Tween = TweenService:Create(self.Panel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = self.OpenPosition, GroupTransparency = 0})
    local id = self.TransitionId
    self.Tween.Completed:Once(function()
        if id == self.TransitionId then
            self.Transitioning = false
            self:Layout()
        end
    end)
    self.Tween:Play()
end

function View:Hide(immediate)
    self.Transitioning = false
    self.TransitionId = (self.TransitionId or 0) + 1
    local id = self.TransitionId
    if self.Tween then self.Tween:Cancel() end
    if immediate then self.Gui.Enabled = false; return end
    self.Tween = TweenService:Create(self.Panel, TweenInfo.new(0.2), {GroupTransparency = 1})
    self.Tween:Play()
    task.delay(0.2, function() if id == self.TransitionId then self.Gui.Enabled = false end end)
end

return View
