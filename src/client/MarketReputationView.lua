local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Text = require(script.Parent.MarketReputationText)
local itemDefinitions = require(ReplicatedStorage.Configs.ItemDefinitions)

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

local function rowFor(parent, compact)
    local row = box("Frame", parent, "Requirement", tan)
    round(row, compact and 5 or 8)
    local icon = picture(row, "Icon")
    local title = label(row, "Title", "", compact and 12 or 15)
    local value = label(row, "Progress", "", compact and 13 or 15)
    value.TextScaled = true
    make("UITextSizeConstraint", value, {MinTextSize = compact and 9 or 11, MaxTextSize = value.TextSize})
    local detail = label(row, "Detail", "", compact and 11 or 13)
    local check = label(row, "Complete", "✓", compact and 12 or 17)
    check.TextColor3 = green
    local track = box("Frame", row, "Track", Color3.fromRGB(220, 188, 135))
    local fill = box("Frame", track, "Fill", green)
    round(track, 3)
    round(fill, 3)
    return {Root = row, Icon = icon, Title = title, Value = value, Detail = detail, Check = check, Track = track, Fill = fill}
end

local function updateRow(row, data, width, compact)
    row.Root.Name = data.Heading and "Heading" or "Requirement"
    row.Root.BackgroundColor3 = data.Complete and completed or (data.Heading and tan or paper)
    row.Icon.Image, row.Icon.Visible = data.Icon or "", data.Icon ~= nil
    row.Icon.Position = UDim2.fromOffset(6, 4)
    row.Icon.Size = UDim2.fromOffset(compact and 16 or 24, compact and 16 or 24)
    local left = data.Icon and (compact and 26 or 37) or 7
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
        local numberWidth = data.Value and math.floor(width * .45) or 0
        row.Title.Size = UDim2.fromOffset(math.max(1, width - left - right - numberWidth), 18)
        row.Value.TextXAlignment = Enum.TextXAlignment.Right
        row.Value.Position = UDim2.fromOffset(width - right - numberWidth, 3)
        row.Value.Size = UDim2.fromOffset(numberWidth, 16)
        row.Detail.Position = UDim2.fromOffset(left, 18)
        row.Detail.Size = UDim2.new(1, -left - right, 0, 14)
        height = data.Detail and 35 or 22
    else
        local available = math.max(1, width - left - right)
        local titleHeight = math.max(22, TextService:GetTextSize(data.Title, 15, font, Vector2.new(available, 1000)).Y + 4)
        row.Title.Size = UDim2.fromOffset(available, titleHeight)
        row.Value.TextXAlignment = Enum.TextXAlignment.Left
        row.Value.Position = UDim2.fromOffset(left, titleHeight + 2)
        row.Value.Size = UDim2.fromOffset(available, 19)
        height = titleHeight + (data.Value and 24 or 7)
        if data.Detail then
            local detailHeight = math.max(17, TextService:GetTextSize(data.Detail, 13, font, Vector2.new(available, 1000)).Y + 3)
            row.Detail.Position = UDim2.fromOffset(left, height - 2)
            row.Detail.Size = UDim2.fromOffset(available, detailHeight)
            height += detailHeight
        end
    end
    row.Track.Visible = data.Ratio ~= nil
    row.Track.Size = UDim2.new(1, -left - 8, 0, compact and 3 or 5)
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
        height += compact and 5 or 9
    end
    row.Root.Size = UDim2.new(1, 0, 0, height)
    return height
end

local function drawRows(container, cache, rows, width, limit, compact)
    local seen = {}
    local height = 0
    for index = 1, math.min(limit, #rows) do
        local data = rows[index]
        local row = cache[data.Key] or rowFor(container, compact)
        cache[data.Key], seen[data.Key] = row, true
        row.Root.LayoutOrder = index
        row.Root.Position = UDim2.fromOffset(0, height)
        height += updateRow(row, data, width, compact) + 4
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
    badge.Position, badge.Size = UDim2.fromOffset(7, 6), UDim2.fromOffset(22, 22)
    local title = label(hud, "Title", "Market Rep", 15)
    title.Position, title.Size = UDim2.fromOffset(33, 4), UDim2.new(1, -116, 0, 24)
    local rank = label(hud, "Level", "", 17)
    rank.Position, rank.Size = UDim2.new(1, -82, 0, 3), UDim2.fromOffset(74, 26)
    rank.TextXAlignment, rank.TextColor3 = Enum.TextXAlignment.Right, green
    local caption = label(hud, "Caption", "", 12)
    caption.Position, caption.Size = UDim2.fromOffset(8, 29), UDim2.new(1, -16, 0, 15)
    local contents = box("Frame", hud, "Requirements", paper)
    contents.BackgroundTransparency = 1
    local more = label(hud, "More", "", 12)

    local detailGui = make("ScreenGui", parent, opts)
    detailGui.Name, detailGui.DisplayOrder, detailGui.Enabled = "MarketReputationDetails", 46, false
    local overlay = box("TextButton", detailGui, "Backdrop", Color3.fromRGB(36, 23, 12))
    overlay.Size, overlay.Text, overlay.AutoButtonColor = UDim2.fromScale(1, 1), "", false
    overlay.BackgroundTransparency = .53
    local panel = box("CanvasGroup", overlay, "Panel", paper)
    panel.AnchorPoint, panel.Position, panel.Active = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), true
    round(panel, 14, 2)
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
    local self = setmetatable({Gui = gui, Hud = hud, Rank = rank, Caption = caption, Rows = contents, More = more,
        DetailGui = detailGui, Backdrop = overlay, Panel = panel, Close = close, DetailTitle = detailTitle,
        DetailStatus = detailStatus, Scroll = scroll, DetailRows = detailRows, CompactCache = {}, DetailCache = {}}, View)
    return self
end

function View:Layout()
    local size = self.Gui.AbsoluteSize
    if size.X < 100 then return end
    local phone = size.X < 600 or size.Y < 460
    local width = math.min(phone and 188 or 220, size.X - 24)
    local rows, caption = Text.Rows(self.State, false)
    local goal = self.State and self.State.Goal
    local limit = size.Y < 380 and 2 or phone and 3 or 4
    local showCaption = not self.State or not self.State.NextLevel or not goal or goal.Children ~= nil or goal.Kind == "Paths"
    self.Rank.Text = self.State and ("Lv. " .. self.State.Level) or "—"
    self.Caption.Text, self.Caption.Visible = caption, showCaption
    local start = showCaption and 47 or 31
    self.Rows.Position, self.Rows.Size = UDim2.fromOffset(7, start), UDim2.new(1, -14, 0, 0)
    local height = drawRows(self.Rows, self.CompactCache, rows, width - 14, limit, true)
    local hidden = math.max(0, #rows - limit)
    self.More.Visible = hidden > 0
    self.More.Text = string.format("+ %d more", hidden)
    self.More.Position, self.More.Size = UDim2.fromOffset(8, start + height), UDim2.new(1, -16, 0, 16)
    self.Hud.Size = UDim2.fromOffset(width, start + height + (hidden > 0 and 17 or 4))

    if not self.DetailGui.Enabled then return end
    local details, status = Text.Rows(self.State, true)
    self.DetailStatus.Text = (self.State and ("Lv. " .. self.State.Level .. " / " .. self.State.MaxLevel .. "  ·  ") or "") .. status
    self.DetailStatus.TextTruncate = Enum.TextTruncate.AtEnd
    local detailWidth = math.min(520, size.X - 24)
    local total = drawRows(self.DetailRows, self.DetailCache, details, detailWidth - 32, math.huge, false)
    self.DetailRows.Size = UDim2.new(1, -8, 0, math.max(1, total))
    self.Panel.Size = UDim2.fromOffset(detailWidth, math.min(size.Y - 22, math.max(138, total + 80), 540))
end

function View:Update(value)
    local previous = self.State
    self.State = value
    self:Layout()
    if previous and value and value.Level > previous.Level then
        if self.Glow then self.Glow:Cancel() end
        self.Hud.BackgroundColor3 = Color3.fromRGB(249, 199, 99)
        self.Glow = TweenService:Create(self.Hud, TweenInfo.new(.85), {BackgroundColor3 = paper})
        self.Glow:Play()
    end
end

function View:SetDetails(open)
    self.DetailGui.Enabled = open
    if open then
        self.Scroll.CanvasPosition = Vector2.zero
        self.Panel.GroupTransparency = 1
        self:Layout()
        TweenService:Create(self.Panel, TweenInfo.new(.17), {GroupTransparency = 0}):Play()
    end
end

return View
