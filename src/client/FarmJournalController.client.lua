local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local config = require(ReplicatedStorage.Configs.FarmJournalConfig)
local definitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local levels = require(ReplicatedStorage.Configs.FarmLevelConfig)
local HudMenu = require(ReplicatedStorage.HudMenu)
local remote = ReplicatedStorage.RemoteEvents:WaitForChild("FarmJournal")
local ink = Color3.fromRGB(91, 56, 31)
local paper = Color3.fromRGB(255, 237, 194)
local green = Color3.fromRGB(91, 139, 61)
local state, chapterIndex, opened = nil, 1, false
local requestPending = false
local category = "Main"
local layout
local transition, closing
local rows, tabs = {}, {}
local refresh

local function make(class, parent, properties)
    local object = Instance.new(class)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = parent
    return object
end

local function round(object, radius)
    make("UICorner", object, {CornerRadius = UDim.new(0, radius or 10)})
end

local function stroke(object, color, thickness)
    make("UIStroke", object, {Color = color or Color3.fromRGB(173, 122, 66), Thickness = thickness or 1.5,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end

local function label(parent, name, text, position, size, textSize)
    return make("TextLabel", parent, {Name = name, Text = text, Position = position, Size = size,
        BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextSize = textSize or 18,
        TextColor3 = ink, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true})
end

local function button(parent, name, text, position, size, color)
    local object = make("TextButton", parent, {Name = name, Text = text, Position = position, Size = size,
        BackgroundColor3 = color or green, BorderSizePixel = 0, Font = Enum.Font.FredokaOne,
        TextSize = 18, TextColor3 = paper, AutoButtonColor = true})
    round(object)
    return object
end

local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), {Name = "FarmJournalGui", ResetOnSpawn = false,
    DisplayOrder = 20, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
local openButton = HudMenu.Add("OpenJournal", "Journal", 3)

local tracker = button(gui, "Tracker", "", UDim2.new(1, -252, 0, 182), UDim2.fromOffset(240, 100), Color3.fromRGB(255, 222, 157))
stroke(tracker)
local trackedTitle = label(tracker, "Title", "", UDim2.fromOffset(12, 8), UDim2.new(1, -48, 0, 40), 17)
local trackedHint = label(tracker, "Hint", "", UDim2.fromOffset(12, 49), UDim2.new(1, -24, 0, 40), 13)
trackedHint.Font = Enum.Font.GothamMedium
local untrack = button(tracker, "Untrack", "X", UDim2.new(1, -36, 0, 5), UDim2.fromOffset(32, 36), Color3.fromRGB(173, 122, 66))
tracker.Visible = false

local blocker = button(gui, "Backdrop", "", UDim2.new(), UDim2.fromScale(1, 1))
blocker.BackgroundTransparency = 1
blocker.Visible = false
local panel = make("CanvasGroup", blocker, {Name = "Book", AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(800, 590), BackgroundColor3 = Color3.fromRGB(153, 98, 50),
    BorderSizePixel = 0, GroupTransparency = 1})
round(panel, 16)
stroke(panel, Color3.fromRGB(94, 56, 29), 3)
local title = label(panel, "Title", config.Title, UDim2.fromOffset(22, 9), UDim2.new(1, -90, 0, 36), 27)
title.TextColor3 = paper
local close = button(panel, "Close", "X", UDim2.new(1, -52, 0, 8), UDim2.fromOffset(44, 44), Color3.fromRGB(170, 68, 48))
local mainTab = button(panel, "MainTab", "Main chapters", UDim2.fromOffset(10, 54), UDim2.fromOffset(160, 34), green)
local sideTab = button(panel, "SideTab", "Side stories", UDim2.fromOffset(178, 54), UDim2.fromOffset(160, 34), ink)
local farmButton = button(panel, "MyFarm", "My Farm", UDim2.new(1, -138, 0, 54), UDim2.fromOffset(128, 34), green)
local navigation = make("ScrollingFrame", panel, {Name = "Chapters", BackgroundColor3 = Color3.fromRGB(232, 196, 137),
    BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(), Active = true})
round(navigation)
for index, chapter in ipairs(config.Chapters) do
    local tab = button(navigation, "Chapter" .. index, "", UDim2.new(), UDim2.new(), paper)
    local number = label(tab, "Number", "", UDim2.fromOffset(10, 8), UDim2.new(1, -20, 0, 20), 13)
    local text = label(tab, "Title", chapter.Title, UDim2.fromOffset(10, 30), UDim2.new(1, -20, 0, 42), 18)
    tabs[index] = {Button = tab, Number = number, Title = text}
    tab.Activated:Connect(function() chapterIndex = index;refresh();remote:FireServer("Get") end)
end

local page = make("Frame", panel, {Name = "Page", BackgroundColor3 = paper, BorderSizePixel = 0,
    Position = UDim2.fromOffset(188, 58), Size = UDim2.new(1, -198, 1, -68)})
round(page)
local chapterTitle = label(page, "ChapterTitle", "", UDim2.fromOffset(16, 10), UDim2.new(1, -32, 0, 32), 23)
local progressText = label(page, "ProgressText", "", UDim2.fromOffset(16, 45), UDim2.new(1, -32, 0, 20), 14)
progressText.Font = Enum.Font.GothamMedium
local progress = make("Frame", page, {Name = "Progress", Position = UDim2.fromOffset(16, 72), Size = UDim2.new(1, -32, 0, 7),
    BackgroundColor3 = Color3.fromRGB(223, 191, 139), BorderSizePixel = 0})
round(progress, 4)
local fill = make("Frame", progress, {Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = green, BorderSizePixel = 0})
round(fill, 4)
local list = make("ScrollingFrame", page, {Name = "Objectives", Position = UDim2.fromOffset(12, 90), Size = UDim2.new(1, -24, 1, -184),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = Color3.fromRGB(173, 122, 66),
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Active = true})
make("UIListLayout", list, {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})
make("UIPadding", list, {PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 8)})
local description = label(list, "Description", "", UDim2.new(), UDim2.new(1, 0, 0, 72), 15)
description.AutomaticSize = Enum.AutomaticSize.Y
description.Size = UDim2.new(1, 0, 0, 0)
description.LayoutOrder = 0
description.Font = Enum.Font.GothamMedium
description.TextYAlignment = Enum.TextYAlignment.Top
local maxObjectives = 0
for _, chapter in ipairs(config.Chapters) do maxObjectives = math.max(maxObjectives, #chapter.Objectives) end
for index = 1, maxObjectives do
    local row = button(list, "Objective" .. index, "", UDim2.new(), UDim2.new(1, 0, 0, 78), Color3.fromRGB(255, 224, 165))
    row.LayoutOrder = index
    stroke(row)
    local icon = make("ImageLabel", row, {Name = "Icon", BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 15), Size = UDim2.fromOffset(48, 48), ScaleType = Enum.ScaleType.Fit})
    local text = label(row, "Title", "", UDim2.fromOffset(66, 8), UDim2.new(1, -112, 0, 40), 18)
    local count = label(row, "Count", "", UDim2.fromOffset(66, 49), UDim2.new(1, -112, 0, 20), 14)
    count.Font = Enum.Font.GothamMedium
    local check = label(row, "Check", "", UDim2.new(1, -38, 0, 19), UDim2.fromOffset(30, 36), 26)
    check.TextXAlignment = Enum.TextXAlignment.Center
    rows[index] = {Button = row, Icon = icon, Text = text, Count = count, Check = check}
    row.Activated:Connect(function()
        if not state then return end
        local id = config.Chapters[chapterIndex].Objectives[index].Id
        remote:FireServer("Track", state.Tracked ~= id and id or nil)
    end)
end
local entry = label(list, "Entry", "", UDim2.new(), UDim2.new(1, 0, 0, 100), 16)
entry.LayoutOrder = maxObjectives + 1
entry.TextColor3 = Color3.fromRGB(113, 113, 58)
entry.Visible = false
local reward = label(page, "Reward", "", UDim2.new(0, 16, 1, -83), UDim2.new(0.54, -22, 0, 42), 15)
local claim = button(page, "Claim", "Claim reward", UDim2.new(0.54, 0, 1, -81), UDim2.new(0.46, -16, 0, 44))
local status = label(page, "Status", "", UDim2.new(0, 16, 1, -30), UDim2.new(1, -32, 0, 25), 12)
status.Font = Enum.Font.GothamMedium

local function tween(object, properties)
    return TweenService:Create(object, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
end

refresh = function(message)
    if not state then return end
    local chapter = config.Chapters[chapterIndex]
    local complete = 0
    local chapterLocked = chapter.Category == "Main" and chapter.Level > state.FarmLevel
    mainTab.BackgroundColor3 = category == "Main" and green or ink
    sideTab.BackgroundColor3 = category == "Side" and green or ink
    for index, tab in ipairs(tabs) do
        local selected = index == chapterIndex
        tab.Button.BackgroundColor3 = selected and paper or Color3.fromRGB(213, 174, 115)
        local definition = config.Chapters[index]
        tab.Number.Text = (definition.Level and "LEVEL " .. definition.Level or "SIDE " .. (index - levels.MaxLevel)) .. (state.Claimed[definition.Id] and "  /  DONE" or "")
    end
    chapterTitle.Text = chapter.Title
    description.Text = chapterIndex == 1 and config.Introduction .. "\n\n" .. chapter.Description or chapter.Description
    for index, row in ipairs(rows) do row.Button.Visible = chapter.Objectives[index] ~= nil end
    for index, objective in ipairs(chapter.Objectives) do
        local row = rows[index]
        local count = math.min(objective.Goal, state.Counts[objective.Id] or 0)
        local done = count >= objective.Goal or state.Completed[chapter.Id] == true
        if done then complete += 1 end
        row.Icon.Image = definitions[objective.Icon].Icon
        row.Text.Text = objective.Text
        local function format(value)
            return objective.Format == "Money" and string.format("$%.2f", value / 100) or tostring(value) .. (objective.Format == "Percent" and "%" or "")
        end
        row.Count.Text = format(count) .. " / " .. format(objective.Goal) .. (state.Tracked == objective.Id and "   /   TRACKED" or "")
        row.Check.Text = done and "✓" or "+"
        row.Check.TextColor3 = done and green or Color3.fromRGB(175, 130, 74)
        row.Button.BackgroundColor3 = done and Color3.fromRGB(225, 232, 172) or state.Tracked == objective.Id and Color3.fromRGB(255, 209, 122) or Color3.fromRGB(255, 224, 165)
    end
    progressText.Text = state.Claimed[chapter.Id] and "A page in our story" or complete .. " / " .. #chapter.Objectives .. " steps complete"
    tween(fill, {Size = UDim2.fromScale(complete / #chapter.Objectives, 1)}):Play()
    local rewards = {string.format("$%.2f", chapter.Reward.MoneyCents / 100)}
    for item, amount in pairs(chapter.Reward.Items) do table.insert(rewards, amount .. " " .. definitions[item].DisplayName) end
    reward.Text = "REWARD\n" .. table.concat(rewards, " + ")
    local ready = complete == #chapter.Objectives and not chapterLocked and not state.Claimed[chapter.Id]
    claim.Text = state.Claimed[chapter.Id] and "Claimed" or chapterLocked and "Farm level " .. chapter.Level or ready and "Claim reward" or "Keep exploring"
    claim.TextSize = 16
    claim.BackgroundColor3 = ready and green or Color3.fromRGB(171, 144, 98)
    claim.Active = ready and not requestPending
    entry.Visible = state.Claimed[chapter.Id] == true
    entry.Text = chapter.Entry
    status.Text = "Tap a step to track it. Explore at your own pace."
    local messages = {InventoryFull = "Make room for the reward, then try again.", RewardClaimed = "A new page in your story!", ChapterLocked = "Reach this farm level first.", AlreadyClaimed = "This reward is already yours.", NotComplete = "A few steps are still waiting.", BalanceLimit = "The reward could not be added yet.", DataNotReady = "Please wait for your farm to load."}
    if typeof(message) == "string" then status.Text = messages[message] or "Could not claim yet. Please try again." end
    tracker.Visible = false
    for _, chapterData in ipairs(config.Chapters) do
        for _, objective in ipairs(chapterData.Objectives) do
            if objective.Id == state.Tracked then
                trackedTitle.Text = objective.Text .. "  " .. (state.Counts[objective.Id] or 0) .. "/" .. objective.Goal
                trackedHint.Text = objective.Hint
                tracker.Visible = not opened and player:GetAttribute("StorageOpen") ~= true
            end
        end
    end
end

local function setOpen(value)
    if value then HudMenu.CloseStorage() end
    opened = value
    player:SetAttribute("FarmJournalOpen", value)
    if transition then transition:Cancel() end
    if closing then task.cancel(closing);closing = nil end
    if value then
        blocker.Visible = true
        transition = tween(panel, {GroupTransparency = 0})
        transition:Play()
        remote:FireServer("Get")
    else
        transition = tween(panel, {GroupTransparency = 1})
        transition:Play()
        closing = task.delay(0.24, function() blocker.Visible = false;closing = nil end)
    end
    refresh()
end

local openChapter = make("BindableFunction", gui, {Name = "OpenChapter"})
openChapter.OnInvoke = function(id)
    for index, chapter in ipairs(config.Chapters) do
        if chapter.Id == id then chapterIndex, category = index, chapter.Category;break end
    end
    layout()
    setOpen(true)
end
local closeMenu = make("BindableFunction", gui, {Name = "CloseMenu"})
closeMenu.OnInvoke = function() setOpen(false) end
for _, tab in ipairs({{mainTab, "Main"}, {sideTab, "Side"}}) do
    tab[1].Activated:Connect(function()
        category = tab[2]
        for index, chapter in ipairs(config.Chapters) do
            if chapter.Category == category then chapterIndex = index;break end
        end
        layout()
        refresh()
    end)
end
farmButton.Activated:Connect(function()
    local overview = player.PlayerGui:FindFirstChild("MyFarmGui")
    local open = overview and overview:FindFirstChild("Open")
    if open then setOpen(false);open:Invoke() end
end)
farmButton.Visible = workspace:FindFirstChild("Plots") ~= nil
openButton.Activated:Connect(function() setOpen(true) end)
close.Activated:Connect(function() setOpen(false) end)
blocker.Activated:Connect(function() setOpen(false) end)
tracker.Activated:Connect(function() setOpen(true) end)
untrack.Activated:Connect(function() remote:FireServer("Track") end)
claim.Activated:Connect(function()
    if requestPending or not claim.Active then return end
    requestPending = true
    remote:FireServer("Claim", config.Chapters[chapterIndex].Id)
    task.delay(1, function() requestPending = false end)
end)
remote.OnClientEvent:Connect(function(data, message)
    if not state then
        for index, chapter in ipairs(config.Chapters) do
            if chapter.Level == data.FarmLevel then chapterIndex = index;break end
        end
    end
    state = data
    layout()
    requestPending = false
    refresh(message)
    if message == "RewardClaimed" then
        page.BackgroundColor3 = Color3.fromRGB(237, 244, 188)
        tween(page, {BackgroundColor3 = paper}):Play()
    end
end)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.J then setOpen(not opened)
    elseif opened and (input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Escape) then setOpen(false) end
end)
player.CharacterRemoving:Connect(function() setOpen(false) end)

layout = function()
    local size = gui.AbsoluteSize
    local width, height = math.min(820, size.X - 24), math.min(610, size.Y - 20)
    local stacked = width < 560
    local compact = height < 500
    panel.Size = UDim2.fromOffset(width, height)
    local tabWidth = width < 500 and math.floor((width - 24) / (farmButton.Visible and 3 or 2)) or 160
    mainTab.Size, sideTab.Size = UDim2.fromOffset(tabWidth, 44), UDim2.fromOffset(tabWidth, 44)
    sideTab.Position = UDim2.fromOffset(tabWidth + 14, 54)
    mainTab.TextSize, sideTab.TextSize = width < 500 and 14 or 18, width < 500 and 14 or 18
    farmButton.Size = UDim2.fromOffset(width < 500 and tabWidth or 128, 44)
    navigation.Position = UDim2.fromOffset(10, 104)
    navigation.Size = stacked and UDim2.new(1, -20, 0, 42) or UDim2.new(0, compact and 112 or 168, 1, -114)
    navigation.ScrollingDirection = stacked and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y
    local visible = 0
    for index, tab in ipairs(tabs) do
        local shown = config.Chapters[index].Category == category
        tab.Button.Visible = shown
        if shown then
            tab.Button.Position = stacked and UDim2.fromOffset(4 + visible * 104, 0) or UDim2.fromOffset(6, 6 + visible * (compact and 54 or 84))
            tab.Button.Size = stacked and UDim2.fromOffset(96, 38) or UDim2.new(1, -14, 0, compact and 48 or 76)
            visible += 1
        end
        tab.Title.Visible = not stacked and not compact
        tab.Number.Position = (stacked or compact) and UDim2.fromOffset(4, 0) or UDim2.fromOffset(10, 8)
        tab.Number.Size = (stacked or compact) and UDim2.new(1, -8, 1, 0) or UDim2.new(1, -20, 0, 20)
        tab.Number.TextSize = (stacked or compact) and 12 or 13
    end
    navigation.CanvasSize = stacked and UDim2.fromOffset(visible * 104 + 4, 0) or UDim2.fromOffset(0, 12 + visible * (compact and 54 or 84))
    local left = compact and 132 or 188
    page.Position = stacked and UDim2.fromOffset(10, 154) or UDim2.fromOffset(left, 104)
    page.Size = stacked and UDim2.new(1, -20, 1, -164) or UDim2.new(1, -left - 10, 1, -114)
    chapterTitle.TextSize = width < 450 and 20 or 23
    description.Visible = not compact
    for _, row in ipairs(rows) do
        row.Button.Size = UDim2.new(1, 0, 0, compact and 64 or 78)
        row.Icon.Size = UDim2.fromOffset(compact and 40 or 48, compact and 40 or 48)
        row.Icon.Position = UDim2.fromOffset(8, compact and 12 or 15)
        row.Text.Size = UDim2.new(1, -112, 0, compact and 30 or 40)
        row.Text.TextSize = compact and 16 or 18
        row.Count.Position = UDim2.fromOffset(66, compact and 39 or 49)
    end
    progressText.Visible = height >= 450
    local top = height < 450 and 55 or 90
    progress.Position = UDim2.fromOffset(16, height < 450 and 45 or 72)
    list.Position = UDim2.fromOffset(12, top)
    list.Size = UDim2.new(1, -24, 1, -top - (compact and 72 or 94))
    reward.Position = UDim2.new(0, 16, 1, compact and -63 or -83)
    claim.Position = UDim2.new(0.54, 0, 1, compact and -61 or -81)
    claim.Size = UDim2.new(0.46, -16, 0, compact and 38 or 44)
    status.TextSize = compact and 10 or 12
    status.Position = UDim2.new(0, 16, 1, compact and -23 or -30)
    tracker.Size = UDim2.fromOffset(size.X < 500 and 200 or 240, 100)
    tracker.Position = UDim2.new(1, size.X < 500 and -212 or -252, 0, 182)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
layout()
task.spawn(function()
    while player:GetAttribute("DataLoaded") ~= true do player:GetAttributeChangedSignal("DataLoaded"):Wait() end
    remote:FireServer("Get")
end)
local elapsed = 0
game:GetService("RunService").Heartbeat:Connect(function(dt)
    elapsed += dt
    if elapsed < 0.25 then return end
    elapsed = 0
    local other = false
    for _, attribute in ipairs({"ProductionMode", "AnimalMenuOpen", "Milking", "FeederOpen", "Teleporting", "FarmOverviewOpen", "WorldMapOpen", "LaboratoryOpen"}) do
        if player:GetAttribute(attribute) then other = true end
    end
    for _, name in ipairs({"BuyGui", "FarmStandGui"}) do
        local shop = player.PlayerGui:FindFirstChild(name)
        if shop and shop.Enabled and shop.MainFrame.Visible then other = true end
    end
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local active = player:GetAttribute("DataLoaded") == true and humanoid and humanoid.Health > 0 and not other
    if not active and opened then setOpen(false) end
    openButton.Visible = active == true and not opened
    if state then tracker.Visible = active == true and not opened and state.Tracked ~= nil and player:GetAttribute("StorageOpen") ~= true end
end)
