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
        BackgroundTransparency = 1, TextColor3 = colors.Ink, Font = Enum.Font.GothamMedium,
        TextSize = 16, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    })
    for property, value in pairs(props or {}) do object[property] = value end
    return object
end
local function button(name, parent, text)
    local object = make("TextButton", name, parent, {
        BackgroundColor3 = colors.Button, BorderSizePixel = 0, Text = text,
        TextColor3 = colors.Ink, Font = Enum.Font.GothamBold, TextSize = 16,
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
    local close = button("CloseButton", root, "×")
    close.Position, close.Size = UDim2.fromOffset(12, 12), UDim2.fromOffset(48, 48)
    close.TextSize = 30
    local panel = make("CanvasGroup", "Panel", root, {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.fromOffset(360, 540), BackgroundColor3 = colors.Panel, BorderSizePixel = 0,
    })
    round(panel, 16)
    label("Title", panel, {Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 28),
        Text = "Производство", Font = Enum.Font.GothamBold, TextSize = 22})
    label("Subtitle", panel, {Position = UDim2.fromOffset(16, 42), Size = UDim2.new(1, -32, 0, 22), Text = "Выберите рецепт"})
    local body = make("CanvasGroup", "Body", panel, {BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 74), Size = UDim2.new(1, -24, 1, -86)})
    local list = scroll("RecipeList", body)
    list.Size = UDim2.fromScale(1, 1)
    make("UIListLayout", "ListLayout", list, {Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder})
    label("EmptyLabel", list, {Size = UDim2.new(1, -12, 0, 80), Text = "Нет доступных рецептов", Visible = false})
    local work = make("Frame", "WorkPanel", body, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false})
    scroll("RecipeSummary", work)
    label("StatusLabel", work, {Text = "Удерживайте кнопку для работы", TextSize = 15})
    local progress = make("Frame", "ProgressBar", work, {BackgroundColor3 = colors.Muted, BorderSizePixel = 0, ClipsDescendants = true})
    make("UICorner", "Corner", progress, {CornerRadius = UDim.new(0, 6)})
    local fill = make("Frame", "Fill", progress, {Size = UDim2.fromScale(0, 1), BackgroundColor3 = colors.Green, BorderSizePixel = 0})
    make("UICorner", "Corner", fill, {CornerRadius = UDim.new(0, 6)})
    label("TimeLabel", work, {Text = "0.0 с", TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center})
    button("BackButton", work, "Рецепты")
    button("StartButton", work, "Удерживайте E")
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
        Size = UDim2.fromOffset(66, 40), TextSize = 16, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right})
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
    self.Body, self.Templates = self.Panel.Body, gui.Templates
    self.Work, self.List = self.Body.WorkPanel, self.Body.RecipeList
    self.MaterialRows, self.Cards = {}, {}
    self.LayoutConnection = self.Root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:Layout() end)
    self:Layout()
    return self
end

function View:Layout()
    local size = self.Root.AbsoluteSize
    if size.X < 1 or size.Y < 1 then return end
    local previousCompact = self.Compact
    self.Portrait = size.Y > size.X
    self.Compact = not self.Portrait and size.Y < 420
    if self.Portrait then
        self.OpenPosition = UDim2.new(0.5, 0, 1, -12)
        self.Panel.AnchorPoint = Vector2.new(0.5, 1)
        self.Panel.Size = UDim2.fromOffset(size.X - 24, math.min(size.Y * 0.52, 470))
    else
        self.OpenPosition = UDim2.new(1, -16, 0.5, 0)
        self.Panel.AnchorPoint = Vector2.new(1, 0.5)
        self.Panel.Size = UDim2.fromOffset(math.clamp(size.X * 0.33, 274, 400), math.min(size.Y - 24, 650))
    end
    if not self.Transitioning then self.Panel.Position = self.OpenPosition end
    local header = self.Compact and 60 or 74
    self.Panel.Title.Position = UDim2.fromOffset(16, self.Compact and 6 or 12)
    self.Panel.Title.TextSize = self.Compact and 20 or 22
    self.Panel.Subtitle.Position = UDim2.fromOffset(16, self.Compact and 34 or 42)
    self.Panel.Subtitle.TextSize = self.Compact and 14 or 16
    self.Body.Position = UDim2.fromOffset(12, header)
    self.Body.Size = UDim2.new(1, -24, 1, -header - 12)
    local height = self.Panel.Size.Y.Offset - header - 12
    local summaryHeight = math.max(40, height - (self.Compact and 122 or 134))
    self.Work.RecipeSummary.Size = UDim2.new(1, 0, 0, summaryHeight)
    self.Work.StatusLabel.Position = UDim2.fromOffset(0, summaryHeight + 4)
    self.Work.StatusLabel.Size = UDim2.new(1, 0, 0, self.Compact and 26 or 32)
    self.Work.ProgressBar.Position = UDim2.fromOffset(0, summaryHeight + (self.Compact and 32 or 40))
    self.Work.ProgressBar.Size = UDim2.new(1, 0, 0, 12)
    self.Work.TimeLabel.Position = UDim2.fromOffset(0, summaryHeight + (self.Compact and 46 or 54))
    self.Work.TimeLabel.Size = UDim2.new(1, 0, 0, 20)
    self.Work.BackButton.Position = UDim2.new(0, 0, 1, -48)
    self.Work.BackButton.Size = UDim2.new(0.3, -6, 0, 48)
    self.Work.StartButton.Position = UDim2.new(0.3, 6, 1, -48)
    self.Work.StartButton.Size = UDim2.new(0.7, -6, 0, 48)
    if previousCompact ~= self.Compact and self.RecipeId then
        self:SetRecipe(self.RecipeId)
        self:UpdateMaterials(self.Inventory)
        if self.LastState then self:UpdateState(self.LastState) end
    end
end

function View:CreateCompactCard(recipeId, parent)
    local recipe = recipes[recipeId]
    local card = self.Templates.RecipeCard:Clone()
    card.Name, card.Parent, card.Visible = recipeId, parent, true
    card.Content.ListLayout:Destroy()
    local height = 0
    local function column(items, x, isInput)
        local keys = sortedKeys(items)
        height = math.max(height, #keys * 64)
        for index, name in ipairs(keys) do
            local definition = definitions[name] or {}
            local row = self.Templates.ItemRow:Clone()
            row.Name, row.Parent, row.Visible = name, card.Content, true
            row.Position = UDim2.new(x, 0, 0, (index - 1) * 64)
            row.Size = UDim2.new(0.44, 0, 0, 60)
            row.Icon.Position = UDim2.fromOffset(0, 0)
            row.Icon.Size = UDim2.fromOffset(28, 28)
            row.Icon.Image = definition.Icon or ""
            row.ItemName.Position = UDim2.fromOffset(0, 30)
            row.ItemName.Size = UDim2.new(1, 0, 0, 30)
            row.ItemName.TextSize = 12
            row.ItemName.Text = definition.DisplayName or name
            row.Amount.Position = UDim2.fromScale(1, 0)
            row.Amount.Size = UDim2.new(1, -30, 0, 28)
            row.Amount.TextSize = 14
            row.Amount.Text = "×" .. items[name]
            if isInput then table.insert(self.MaterialRows, {Row = row, Name = name, Required = items[name]}) end
        end
    end
    column(recipe.Inputs, 0, true)
    column(recipe.Outputs, 0.56, false)
    label("Direction", card.Content, {Position = UDim2.new(0.44, 0, 0, 4),
        Size = UDim2.new(0.12, 0, 0, 28), Text = "→", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center})
    card.Content.Position = UDim2.fromOffset(6, 4)
    card.Content.Size = UDim2.new(1, -12, 1, -8)
    card.Size = UDim2.new(1, -10, 0, height + 8)
    return card
end

function View:CreateCard(recipeId, parent, showOwned)
    local recipe = recipes[recipeId]
    if not recipe then return end
    local card = self.Templates.RecipeCard:Clone()
    card.Name, card.Parent, card.Visible = recipeId, parent, true
    local order, height = 0, 20
    local function text(textValue, textHeight)
        order = order + 1
        local row = label("Caption", card.Content, {Text = textValue, Size = UDim2.new(1, 0, 0, textHeight), LayoutOrder = order,
            TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center})
        height = height + textHeight + 4
        return row
    end
    local function items(values, isInput)
        for _, name in ipairs(sortedKeys(values)) do
            local definition = definitions[name] or {}
            order = order + 1
            local row = self.Templates.ItemRow:Clone()
            row.Name, row.LayoutOrder, row.Parent, row.Visible = name, order, card.Content, true
            row.Icon.Image = definition.Icon or ""
            row.ItemName.Text = definition.DisplayName or name
            row.Amount.Text = "×" .. values[name]
            if showOwned and isInput then
                table.insert(self.MaterialRows, {Row = row, Name = name, Required = values[name]})
            end
            height = height + 44
        end
    end
    text(showOwned and "Материалы: есть / нужно" or "Материалы", 20)
    items(recipe.Inputs, true)
    text("↓", 22)
    items(recipe.Outputs, false)
    text(string.format("%.1f с • за одну порцию", recipe.Duration), 22)
    card.Size = UDim2.new(1, -10, 0, height)
    return card
end

function View:ShowRecipes(station, onSelect)
    for _, card in ipairs(self.Cards) do card:Destroy() end
    self.Cards = {}
    local definition = definitions[station:GetAttribute("ItemName") or station.Name] or {}
    for order, recipeId in ipairs(definition.Recipes or {}) do
        if recipes[recipeId] then
            local card = self:CreateCard(recipeId, self.List, false)
            card.LayoutOrder = order
            card.Activated:Connect(function() onSelect(recipeId) end)
            table.insert(self.Cards, card)
        end
    end
    self.List.EmptyLabel.Visible = #self.Cards == 0
    self.List.CanvasPosition = Vector2.zero
    self.Panel.Title.Text = definition.DisplayName or station.Name
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
    self.Panel.Subtitle.Text = recipeId and "Удерживайте для работы" or "Выберите рецепт"
    self.MaterialRows = {}
    for _, child in ipairs(self.Work.RecipeSummary:GetChildren()) do child:Destroy() end
    if recipeId then
        local card
        if self.Compact then card = self:CreateCompactCard(recipeId, self.Work.RecipeSummary)
        else card = self:CreateCard(recipeId, self.Work.RecipeSummary, true) end
        card.Active, card.AutoButtonColor, card.Selectable = false, false, false
        self.Work.RecipeSummary.CanvasPosition = Vector2.zero
    end
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
    local text = "Удерживайте E, чтобы начать"
    if UserInputService.TouchEnabled then text = "Удерживайте для запуска" end
    if self.Busy then text = "Работаем… удерживайте"
    elseif not self.Enough then text = "Не хватает материалов" end
    self.Work.StartButton.Text = text
    self.Work.StartButton.BackgroundColor3 = (self.Enough or self.Busy) and colors.Button or colors.Muted
    self.Work.BackButton.Interactable = not self.Busy
    self.Work.BackButton.AutoButtonColor = not self.Busy
    self.Work.BackButton.BackgroundColor3 = self.Busy and colors.Muted or colors.Button
    local messages = {
        Working = "Помол… Отпустите — порция отменится.",
        Released = "Порция отменена. Материалы сохранены.",
        Completed = "Готово! Продукция осталась в станке.",
        NotEnoughItems = "Не хватает ингредиентов.",
        InvalidOutputInventory = "Ошибка запаса станка.",
        MissingOutputInventory = "Не найден склад станка.",
        Ready = "Удерживайте для работы. Q — выход.",
    }
    if UserInputService.TouchEnabled then messages.Ready = "Удерживайте для работы." end
    if self.Compact then
        messages.Working = "Работаем… Отпускание отменяет."
        messages.Released = "Отменено. Материалы сохранены."
        messages.Completed = "Готово! Продукция в станке."
        messages.Ready = "Удерживайте для работы."
    end
    self.Work.StatusLabel.Text = (not self.Enough and not self.Busy) and "Не хватает ингредиентов." or (messages[state.Message] or "Q — выход • F — сбор после выхода")
end

function View:UpdateProgress(state)
    local fraction, remaining = 0, 0
    if state.Busy and state.Duration > 0 then
        local elapsed = workspace:GetServerTimeNow() - state.StartedAt
        fraction = math.clamp(elapsed / state.Duration, 0, 1)
        remaining = math.max(0, state.Duration - elapsed)
    end
    self.Work.ProgressBar.Fill.Size = UDim2.fromScale(fraction, 1)
    self.Work.TimeLabel.Text = string.format("%.1f / %.1f с", remaining, (self.RecipeId and recipes[self.RecipeId].Duration) or 0)
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
    self.Tween:Play()
    self.Transitioning = false
end

function View:Hide(immediate)
    self.TransitionId = (self.TransitionId or 0) + 1
    local id = self.TransitionId
    if self.Tween then self.Tween:Cancel() end
    if immediate then self.Gui.Enabled = false; return end
    self.Tween = TweenService:Create(self.Panel, TweenInfo.new(0.2), {GroupTransparency = 1})
    self.Tween:Play()
    task.delay(0.2, function() if id == self.TransitionId then self.Gui.Enabled = false end end)
end

return View
