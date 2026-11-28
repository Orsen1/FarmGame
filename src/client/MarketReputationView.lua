local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local Input = game:GetService("UserInputService")
local Text = require(script.Parent:WaitForChild("MarketReputationText"))
local itemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))

local View = {}
View.__index = View
local ink = Color3.fromRGB(99, 63, 37)
local paper = Color3.fromRGB(255, 238, 197)
local tan = Color3.fromRGB(246, 215, 154)
local green = Color3.fromRGB(80, 128, 59)
local completed = Color3.fromRGB(226, 239, 196)
local font = Enum.Font.FredokaOne

local function make(class, parent, properties)
    local object = Instance.new(class)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = parent
    return object
end

local function round(object, radius, border)
    make("UICorner", object, {CornerRadius = UDim.new(0, radius)})
    if border then
        make("UIStroke", object, {ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = border,
            Color = Color3.fromRGB(167, 114, 64)})
    end
end

local function label(parent, name, text, size)
    return make("TextLabel", parent, {Name = name, Text = text, Font = font, TextSize = size, TextColor3 = ink,
        BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left})
end

local function box(class, parent, name, color)
    return make(class, parent, {Name = name, BackgroundColor3 = color, BorderSizePixel = 0})
end

local function picture(parent, name)
    return make("ImageLabel", parent, {Name = name, Image = "", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit})
end

local function rowFor(parent, compact, direction, view)
    local row = box(direction and "TextButton" or "Frame", parent, "Requirement", tan)
    if direction then
        row.Text = ""
        row.Activated:Connect(function()
            if view.SelectedDirection == direction then
                view.SelectedDirection = nil
                view.ChooseDirection(direction, view.State.Level, view.State.Goal.ActiveId)
            else
                view.SelectedDirection = direction
            end
            view:Layout()
        end)
    end
    round(row, 8)
    local icon = picture(row, "Icon")
    local title = label(row, "Title", "", compact and 17 or 15)
    local value = label(row, "Progress", "", compact and 22 or 15)
    value.TextScaled = true
    make("UITextSizeConstraint", value, {MinTextSize = compact and 13 or 11, MaxTextSize = value.TextSize})
    local detail = label(row, "Detail", "", compact and 15 or 13)
    local check = label(row, "Complete", "✓", 17)
    check.TextColor3 = green
    local track = box("Frame", row, "Track", Color3.fromRGB(220, 188, 135))
    local fill = box("Frame", track, "Fill", green)
    round(track, 3)
    round(fill, 3)
    return {Root = row, Icon = icon, Title = title, Value = value, Detail = detail, Check = check, Track = track, Fill = fill}
end

local function updateRow(row, data, width, compact, large)
    row.Root.Name = data.Heading and "Heading" or "Requirement"
    row.Root.BackgroundColor3 = data.Complete and completed or (data.Heading and tan or paper)
    row.Icon.Image, row.Icon.Visible = data.Icon or "", data.Icon ~= nil
    row.Icon.Position = UDim2.fromOffset(6, compact and 6 or 4)
    row.Icon.Size = UDim2.fromOffset(24, 24)
    local left = data.Icon and 37 or 7
    local right = data.Complete and 26 or 8
    row.Title.Text = data.Title
    row.Title.TextWrapped = not compact
    row.Title.TextTruncate = compact and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None
    row.Check.Visible = data.Complete == true
    row.Check.Position, row.Check.Size = UDim2.new(1, -20, 0, 3), UDim2.fromOffset(16, 19)
    row.Title.Position = UDim2.fromOffset(left, 2)
    row.Value.Text, row.Value.Visible = data.Value or "", data.Value ~= nil
    row.Detail.Text, row.Detail.Visible = data.Detail or "", data.Detail ~= nil
    row.Detail.TextTruncate = compact and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None
    row.Detail.TextWrapped = not compact
    local height
    if compact then
        local numberWidth = 0
        if data.Value then
            local textWidth = TextService:GetTextSize(data.Value, row.Value.TextSize, font, Vector2.new(width, 1000)).X
            numberWidth = math.min(math.floor(width * .52), textWidth + 8)
        end
        row.Title.Size = UDim2.fromOffset(math.max(1, width - left - right - numberWidth), 30)
        row.Value.TextXAlignment = Enum.TextXAlignment.Right
        row.Value.Position = UDim2.fromOffset(width - right - numberWidth, 2)
        row.Value.Size = UDim2.fromOffset(numberWidth, 30)
        row.Check.Position = UDim2.new(1, -20, 0, 7)
        row.Detail.Position = UDim2.fromOffset(left, 30)
        row.Detail.Size = UDim2.new(1, -left - right, 0, 19)
        height = data.Detail and 51 or 35
    else
        local available = math.max(1, width - left - right)
        local titleSize = large and 19 or 15
        local valueSize = large and 21 or 15
        local valueHeight = large and 25 or 19
        local titleHeight = math.max(22, TextService:GetTextSize(data.Title, titleSize, font, Vector2.new(available, 1000)).Y + 4)
        row.Title.TextSize = titleSize
        row.Title.Size = UDim2.fromOffset(available, titleHeight)
        row.Value.TextXAlignment = Enum.TextXAlignment.Left
        row.Value.Position = UDim2.fromOffset(left, titleHeight + 2)
        row.Value.Size = UDim2.fromOffset(available, valueHeight)
        row.Value.UITextSizeConstraint.MaxTextSize = valueSize
        height = titleHeight + (data.Value and valueHeight + 5 or 7)
        if data.Detail then
            local detailSize = large and 15 or 13
            local detailHeight = math.max(17, TextService:GetTextSize(data.Detail, detailSize, font, Vector2.new(available, 1000)).Y + 3)
            row.Detail.TextSize = detailSize
            row.Detail.Position = UDim2.fromOffset(left, height - 2)
            row.Detail.Size = UDim2.fromOffset(available, detailHeight)
            height += detailHeight
        end
    end
    row.Track.Visible = data.Ratio ~= nil
    row.Track.Size = UDim2.new(1, -left - 8, 0, compact and 6 or 5)
    row.Track.Position = UDim2.fromOffset(left, height)
    if data.Ratio ~= nil then
        if row.Ratio ~= data.Ratio then
            if row.Tween then row.Tween:Cancel() end
            local size = UDim2.fromScale(data.Ratio, 1)
            if row.Ratio then
                row.Tween = TweenService:Create(row.Fill, TweenInfo.new(.25, Enum.EasingStyle.Quad), {Size = size})
                row.Tween:Play()
            else
                row.Fill.Size = size
            end
            row.Ratio = data.Ratio
        end
        height += compact and 12 or 9
    end
    return height
end

local function drawRows(container, cache, rows, width, limit, compact, large, view)
    local seen = {}
    local height = 0
    for index = 1, math.min(limit, #rows) do
        local data = rows[index]
        local key = data.Key .. (data.Direction and "/choose" or "")
        local row = cache[key] or rowFor(container, compact, data.Direction, view)
        cache[key], seen[key] = row, true
        row.Root.LayoutOrder = index
        local indent = compact and 0 or math.min(data.Depth or 0, 3) * 12
        local rowHeight = updateRow(row, data, width - indent, compact, large)
        row.Root.Position = UDim2.fromOffset(indent, height)
        row.Root.Size = UDim2.new(1, -indent, 0, rowHeight)
        height += rowHeight + 4
    end
    for key, row in pairs(cache) do
        if not seen[key] then
            if row.Tween then row.Tween:Cancel() end
            row.Root:Destroy()
            cache[key] = nil
        end
    end
    return height
end

function View.new(parent)
    local opts = {ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling}
    local gui = make("ScreenGui", parent, opts)
    gui.Name, gui.DisplayOrder = "MarketReputationGui", 6
    local hud = box("TextButton", gui, "Reputation", paper)
    hud.Text, hud.AutoButtonColor = "", false
    hud.AnchorPoint, hud.Position = Vector2.new(1, 0), UDim2.new(1, -12, 0, 8)
    round(hud, 10, 1.5)
    local badge = picture(hud, "Badge")
    badge.Image = itemDefinitions.Carrot.Icon
    badge.Position, badge.Size = UDim2.fromOffset(9, 7), UDim2.fromOffset(30, 30)
    local title = label(hud, "Title", "Market Rep", 22)
    title.TextScaled = true
    title.TextTruncate = Enum.TextTruncate.AtEnd
    make("UITextSizeConstraint", title, {MinTextSize = 16, MaxTextSize = 22})
    local rank = label(hud, "Level", "", 24)
    rank.Position, rank.Size = UDim2.new(1, -80, 0, 5), UDim2.fromOffset(70, 34)
    rank.TextXAlignment, rank.TextColor3 = Enum.TextXAlignment.Right, green
    local caption = label(hud, "Caption", "", 16)
    caption.TextTruncate = Enum.TextTruncate.AtEnd
    local contents = box("Frame", hud, "Requirements", paper)
    contents.BackgroundTransparency = 1
    local more = label(hud, "More", "", 15)

    local detailGui = make("ScreenGui", parent, opts)
    detailGui.Name, detailGui.DisplayOrder, detailGui.Enabled = "MarketReputationDetails", 55, false
    local overlay = box("TextButton", detailGui, "Backdrop", Color3.fromRGB(36, 23, 12))
    overlay.Size, overlay.Text, overlay.AutoButtonColor = UDim2.fromScale(1, 1), "", false
    overlay.BackgroundTransparency = .53
    local panel = box("CanvasGroup", overlay, "Panel", paper)
    panel.AnchorPoint, panel.Position, panel.Active = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), true
    round(panel, 14, 2)
    local detailHeader = box("Frame", panel, "Header", tan)
    detailHeader.Position, detailHeader.Size = UDim2.fromOffset(8, 2), UDim2.new(1, -16, 0, 64)
    round(detailHeader, 10)
    local detailTitle = label(panel, "Title", "Market reputation", 23)
    detailTitle.Position, detailTitle.Size = UDim2.fromOffset(14, 6), UDim2.new(1, -70, 0, 30)
    local detailStatus = label(panel, "Status", "", 14)
    detailStatus.Position, detailStatus.Size = UDim2.fromOffset(14, 35), UDim2.new(1, -70, 0, 23)
    local close = box("TextButton", panel, "Close", tan)
    close.Size, close.Position, close.Text = UDim2.fromOffset(44, 44), UDim2.new(1, -54, 0, 8), "×"
    close.Font, close.TextColor3, close.TextSize = font, ink, 24
    round(close, 8, 1)
    local scroll = make("ScrollingFrame", panel, {Name = "Requirements", Active = true,
        Position = UDim2.fromOffset(12, 64), Size = UDim2.new(1, -24, 1, -76), BackgroundTransparency = 1,
        BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4, ScrollBarImageColor3 = ink, ScrollingDirection = Enum.ScrollingDirection.Y})
    local detailRows = box("Frame", scroll, "List", paper)
    detailRows.Size, detailRows.BackgroundTransparency = UDim2.new(1, -8, 0, 1), 1
    local self = setmetatable({Gui = gui, Hud = hud, Badge = badge, Title = title, Rank = rank, Caption = caption, Rows = contents, More = more,
        DetailGui = detailGui, Backdrop = overlay, Panel = panel, Close = close, DetailTitle = detailTitle, DetailHeader = detailHeader,
        DetailStatus = detailStatus, Scroll = scroll, DetailRows = detailRows, CompactCache = {}, DetailCache = {}}, View)
    return self
end

function View:SetBalanceWidth(balanceWidth)
    local left = self.Mobile and self.Hud.Size.X.Offset - balanceWidth < 170 and 12 or 44
    local right = self.Mobile and balanceWidth + 20 or 82
    self.Badge.Visible = left == 44
    self.Title.Position = UDim2.fromOffset(left, self.Mobile and 11 or 5)
    self.Title.Size = UDim2.new(1, -left - right, 0, 34)
end

function View:Layout()
    local size = self.Gui.AbsoluteSize
    if size.X < 100 then return end
    local short = size.Y < 380
    local narrow = size.X < 600 or size.Y < 460
    local mobile = Input.TouchEnabled
    self.Mobile = mobile
    local width = math.min(math.max(224, math.floor(size.X / 3)), size.X - 24)
    local y = 8
    if mobile then
        width = size.Y >= size.X and size.X - 16 or math.min(size.X - 16, math.max(360, math.floor(size.X * .54)))
        local topbar = GuiService:GetInsetArea(Enum.ScreenInsets.TopbarSafeInsets)
        y = topbar.Width >= width + 16 and math.min(0, topbar.Min.Y + 4) or 0
    end
    self.Hud.Position = UDim2.new(1, mobile and -8 or -12, 0, y)
    local rows, caption = Text.Rows(self.State, false)
    local goal = self.State and self.State.Goal
    local limit = short and 1 or narrow and 3 or 4
    local hidden = math.max(0, #rows - limit)
    local inlineMore = short and hidden > 0
    local showCaption = mobile or not self.State or not self.State.NextLevel or not goal or goal.Children ~= nil or goal.Kind == "Paths"
    self.Rank.Text = self.State and ("Lv. " .. self.State.Level) or "—"
    self.Rank.Position = mobile and UDim2.fromOffset(10, 51) or UDim2.new(1, -80, 0, 5)
    self.Rank.TextXAlignment = mobile and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
    self.Rank.TextSize = mobile and 19 or 24
    self.Rank.Size = UDim2.fromOffset(70, mobile and 24 or 34)
    self.Caption.Text, self.Caption.Visible = caption, showCaption
    local captionY = mobile and 52 or short and 37 or 39
    local captionX = mobile and 82 or 10
    self.Caption.Position = UDim2.fromOffset(captionX, captionY)
    self.Caption.Size = UDim2.new(1, -captionX - (inlineMore and 92 or 10), 0, mobile and 22 or short and 18 or 21)
    local start = mobile and 78 or showCaption and (short and 55 or 64) or 42
    self.Rows.Position, self.Rows.Size = UDim2.fromOffset(9, start), UDim2.new(1, -18, 0, 0)
    local height = drawRows(self.Rows, self.CompactCache, rows, width - 18, limit, true)
    self.More.Visible = hidden > 0
    self.More.Text = string.format("+ %d more", hidden)
    self.More.TextXAlignment = inlineMore and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
    self.More.Position = inlineMore and UDim2.new(1, -90, 0, captionY) or UDim2.fromOffset(10, start + height)
    self.More.Size = inlineMore and UDim2.fromOffset(80, 18) or UDim2.new(1, -20, 0, 20)
    self.Hud.Size = UDim2.fromOffset(width, start + height + (hidden > 0 and not inlineMore and 23 or 5))

    if not self.DetailGui.Enabled then return end
    local details, status = Text.Rows(self.State, true, self.SelectedDirection)
    self.DetailStatus.Text = (self.State and ("Lv. " .. self.State.Level .. " / " .. self.State.MaxLevel .. "  ·  ") or "") .. status
    self.DetailStatus.TextTruncate = Enum.TextTruncate.AtEnd
    local detailWidth = mobile and size.X or math.min(520, size.X - 24)
    local total = drawRows(self.DetailRows, self.DetailCache, details, detailWidth - 32, math.huge, false, mobile, self)
    self.DetailRows.Size = UDim2.new(1, -8, 0, math.max(1, total))
    self.DetailGui.ClipToDeviceSafeArea = not mobile
    self.Backdrop.BackgroundColor3 = mobile and paper or Color3.fromRGB(36, 23, 12)
    self.Backdrop.BackgroundTransparency = mobile and 0 or .53
    self.Panel.BackgroundTransparency = mobile and 1 or 0
    self.Panel.UIStroke.Enabled = not mobile
    self.DetailHeader.Visible = mobile
    self.DetailTitle.TextSize = mobile and 26 or 23
    self.DetailTitle.TextTruncate = Enum.TextTruncate.AtEnd
    self.DetailTitle.Position = UDim2.fromOffset(mobile and 19 or 14, 6)
    self.DetailStatus.TextSize = mobile and 17 or 14
    self.DetailStatus.Position = UDim2.fromOffset(mobile and 19 or 14, mobile and 37 or 35)
    self.Close.Size = UDim2.fromOffset(mobile and 48 or 44, mobile and 48 or 44)
    self.Close.Position = UDim2.new(1, mobile and -62 or -54, 0, 8)
    self.Scroll.Position = UDim2.fromOffset(12, mobile and 76 or 64)
    self.Scroll.Size = UDim2.new(1, -24, 1, mobile and -88 or -76)
    if mobile then
        local bounds = GuiService:GetInsetArea(Enum.ScreenInsets.None)
        self.Backdrop.Position = UDim2.fromOffset(bounds.Min.X, bounds.Min.Y)
        self.Backdrop.Size = UDim2.fromOffset(bounds.Width, bounds.Height)
        self.Panel.AnchorPoint = Vector2.zero
        self.Panel.Position = UDim2.fromOffset(-bounds.Min.X, -bounds.Min.Y)
        self.Panel.Size = UDim2.fromOffset(size.X, size.Y)
    else
        self.Backdrop.Position, self.Backdrop.Size = UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1)
        self.Panel.AnchorPoint, self.Panel.Position = Vector2.new(.5, .5), UDim2.fromScale(.5, .5)
        self.Panel.Size = UDim2.fromOffset(detailWidth, math.min(size.Y - 22, math.max(138, total + 80), 540))
    end
end

function View:Update(value)
    local previous = self.State
    if not previous or not value or previous.Level ~= value.Level or (previous.Goal and previous.Goal.ActiveId) ~= (value.Goal and value.Goal.ActiveId) then
        self.SelectedDirection = nil
    end
    self.State = value
    self:Layout()
    if previous and value and value.Level > previous.Level then
        self.LevelUp = true
        self:ShowLevelUp()
    end
end

function View:ShowLevelUp()
    if not self.LevelUp or not self.Gui.Enabled then return end
    self.LevelUp = false
    if self.Glow then self.Glow:Cancel() end
    self.Hud.BackgroundColor3 = Color3.fromRGB(249, 199, 99)
    self.Glow = TweenService:Create(self.Hud, TweenInfo.new(.85), {BackgroundColor3 = paper})
    self.Glow:Play()
end

function View:SetDetails(open)
    self.SelectedDirection = nil
    self.DetailGui.Enabled = open
    if open then
        self.Scroll.CanvasPosition = Vector2.zero
        self.Panel.GroupTransparency = 1
        self:Layout()
        TweenService:Create(self.Panel, TweenInfo.new(.17), {GroupTransparency = 0}):Play()
    end
end

return View
