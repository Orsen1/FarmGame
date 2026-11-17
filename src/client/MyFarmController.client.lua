local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local levels = require(ReplicatedStorage.Configs.FarmLevelConfig)
local journal = require(ReplicatedStorage.Configs.FarmJournalConfig)
local definitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local HudMenu = require(ReplicatedStorage.HudMenu)
local remote = ReplicatedStorage.RemoteEvents:WaitForChild("FarmJournal")
local ink, wood = Color3.fromRGB(93, 58, 34), Color3.fromRGB(139, 91, 48)
local paper, green = Color3.fromRGB(255, 237, 194), Color3.fromRGB(82, 121, 57)
local dark, gold = Color3.fromRGB(45, 68, 45), Color3.fromRGB(239, 190, 82)
local state, opened, celebrating, pending = nil, false, false, false
local savedPrompts, savedInventory, generation = nil, nil, 0
local taskRows, unlockRows, celebrationRows = {}, {}, {}
local layout, refresh, setOpen

local function make(class, parent, properties)
    local object = Instance.new(class)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = parent
    return object
end

local function trim(object, color, radius, thickness)
    make("UICorner", object, {CornerRadius = UDim.new(0, radius or 10)})
    make("UIStroke", object, {Color = color or wood, Thickness = thickness or 1.5,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end

local function label(parent, name, text, size, color)
    return make("TextLabel", parent, {Name = name, Text = text, BackgroundTransparency = 1,
        Size = size, TextColor3 = color or ink, Font = Enum.Font.FredokaOne, TextSize = 18,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left})
end

local function button(parent, name, text, color)
    local object = make("TextButton", parent, {Name = name, Text = text, BackgroundColor3 = color or green,
        BorderSizePixel = 0, Font = Enum.Font.FredokaOne, TextSize = 20, TextColor3 = paper})
    trim(object, ink)
    return object
end

local function tween(object, properties, duration)
    local animation = TweenService:Create(object, TweenInfo.new(duration or .24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
    animation:Play()
    return animation
end

local function icon(parent)
    return make("ImageLabel", parent, {Name = "Icon", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit})
end

local function scroll(parent, name)
    local frame = make("ScrollingFrame", parent, {Name = name, BackgroundTransparency = 1,
        BorderSizePixel = 0, CanvasSize = UDim2.new(), ScrollBarThickness = 4,
        ScrollBarImageColor3 = wood, ScrollingDirection = Enum.ScrollingDirection.Y, Active = true})
    return frame
end

local function stack(parent, padding)
    make("UIListLayout", parent, {Padding = UDim.new(0, padding or 8), SortOrder = Enum.SortOrder.LayoutOrder})
    make("UIPadding", parent, {PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8),
        PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4)})
    parent.AutomaticCanvasSize = Enum.AutomaticSize.Y
end

local function chapterFor(level)
    local id = levels.Levels[level].Chapter
    for _, chapter in ipairs(journal.Chapters) do if chapter.Id == id then return chapter end end
end

local function formatCount(objective, count)
    if objective.Format == "Money" then return string.format("$%.2f", count / 100) end
    return tostring(count) .. (objective.Format == "Percent" and "%" or "")
end

local gui = make("ScreenGui", playerGui, {Name = "MyFarmGui", ResetOnSpawn = false, DisplayOrder = 35,
    ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
local farmButton = HudMenu.Add("OpenFarm", "Farm", 6)
local badge = label(farmButton, "Ready", "!", UDim2.fromOffset(22, 22))
badge.AnchorPoint, badge.Position = Vector2.new(1, 0), UDim2.new(1, 5, 0, -5)
badge.BackgroundColor3, badge.BackgroundTransparency = gold, 0
badge.TextXAlignment, badge.Visible = Enum.TextXAlignment.Center, false
trim(badge, ink, 11)
local notice = button(gui, "LevelNotice", "A new farm level is ready!", green)
notice.AnchorPoint, notice.Position = Vector2.new(.5, 0), UDim2.new(.5, 0, 0, 10)
notice.Size, notice.TextSize, notice.Visible = UDim2.new(.8, 0, 0, 48), 18, false
make("UISizeConstraint", notice, {MaxSize = Vector2.new(420, 48)})

local backdrop = button(gui, "Backdrop", "", dark)
backdrop.Size, backdrop.BackgroundTransparency, backdrop.Visible = UDim2.fromScale(1, 1), 1, false
backdrop.UIStroke:Destroy()
backdrop.UICorner:Destroy()
local panel = make("CanvasGroup", backdrop, {Name = "Overview", AnchorPoint = Vector2.new(.5, .5),
    Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(900, 650),
    BackgroundColor3 = dark, BorderSizePixel = 0, GroupTransparency = 1})
trim(panel, wood, 15, 5)
local title = label(panel, "Title", "My Farm", UDim2.new(1, -94, 0, 42), paper)
title.Position, title.TextSize = UDim2.fromOffset(22, 8), 29
local close = button(panel, "Close", "X", Color3.fromRGB(171, 72, 48))
close.Position, close.Size = UDim2.new(1, -56, 0, 8), UDim2.fromOffset(44, 44)
local levelText = label(panel, "Level", "", UDim2.new(.62, -30, 0, 32), gold)
levelText.Position, levelText.TextSize = UDim2.fromOffset(22, 54), 22
local nextText = label(panel, "NextLevel", "", UDim2.new(.38, -22, 0, 32), paper)
nextText.Position, nextText.TextXAlignment = UDim2.new(.62, 0, 0, 54), Enum.TextXAlignment.Right
local content = scroll(panel, "Content")
local tasks = make("Frame", content, {Name = "Chapter", BackgroundColor3 = paper, BorderSizePixel = 0})
trim(tasks)
local taskHeading = label(tasks, "Heading", "Chapter tasks", UDim2.new(1, -24, 0, 32))
taskHeading.Position, taskHeading.TextSize = UDim2.fromOffset(14, 6), 22
local taskProgress = label(tasks, "ProgressText", "", UDim2.new(1, -24, 0, 22))
taskProgress.Position, taskProgress.TextSize, taskProgress.Font = UDim2.fromOffset(14, 39), 14, Enum.Font.GothamMedium
local progress = make("Frame", tasks, {Name = "Progress", Position = UDim2.fromOffset(14, 67),
    Size = UDim2.new(1, -28, 0, 6), BackgroundColor3 = Color3.fromRGB(219, 193, 145), BorderSizePixel = 0})
trim(progress, Color3.fromRGB(219, 193, 145), 3, 0)
local progressFill = make("Frame", progress, {Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = green, BorderSizePixel = 0})
make("UICorner", progressFill, {CornerRadius = UDim.new(0, 3)})
local taskList = scroll(tasks, "Tasks")
stack(taskList, 6)
local maxTasks, maxUnlocks = 0, 0
for _, chapter in ipairs(journal.Chapters) do maxTasks = math.max(maxTasks, #chapter.Objectives) end
for _, level in ipairs(levels.Levels) do maxUnlocks = math.max(maxUnlocks, #level.Unlocks) end
for index = 1, maxTasks do
    local row = make("Frame", taskList, {Name = "Task" .. index, Size = UDim2.new(1, 0, 0, 54),
        LayoutOrder = index, BackgroundTransparency = 1})
    local image = icon(row)
    image.Position, image.Size = UDim2.fromOffset(0, 7), UDim2.fromOffset(38, 38)
    local text = label(row, "Title", "", UDim2.new(1, -124, 1, -4))
    text.Position, text.TextSize = UDim2.fromOffset(46, 2), 17
    local count = label(row, "Count", "", UDim2.fromOffset(74, 46))
    count.Position, count.TextXAlignment, count.TextSize = UDim2.new(1, -78, 0, 4), Enum.TextXAlignment.Right, 16
    taskRows[index] = {Root = row, Icon = image, Text = text, Count = count}
end
local unlockPanel = make("Frame", content, {Name = "Unlocks", BackgroundColor3 = paper, BorderSizePixel = 0})
trim(unlockPanel)
local unlockHeading = label(unlockPanel, "Heading", "Next level unlocks", UDim2.new(1, -28, 0, 38))
unlockHeading.Position, unlockHeading.TextSize = UDim2.fromOffset(14, 5), 21
local unlockList = scroll(unlockPanel, "List")
stack(unlockList, 8)
for index = 1, maxUnlocks do
    local row = make("Frame", unlockList, {Name = "Unlock" .. index, BackgroundColor3 = Color3.fromRGB(242, 220, 172),
        BorderSizePixel = 0, LayoutOrder = index, Size = UDim2.new(1, 0, 0, 82)})
    trim(row, Color3.fromRGB(206, 174, 117), 8, 1)
    local image = icon(row)
    image.Position, image.Size = UDim2.fromOffset(8, 9), UDim2.fromOffset(64, 64)
    local text = label(row, "Title", "", UDim2.new(1, -88, 1, -12))
    text.Position, text.TextSize = UDim2.fromOffset(80, 6), 19
    unlockRows[index] = {Root = row, Icon = image, Text = text}
end
local maxLabel = label(unlockPanel, "MaxLevel", "All farm levels unlocked.\nMore adventures will grow from here.", UDim2.new(1, -32, 1, -64))
maxLabel.Position, maxLabel.TextSize, maxLabel.Visible = UDim2.fromOffset(16, 52), 20, false
local footer = make("Frame", panel, {Name = "Footer", BackgroundTransparency = 1})
local rewardText = label(footer, "Reward", "", UDim2.new(1, 0, 0, 28), paper)
rewardText.Font, rewardText.TextSize = Enum.Font.GothamMedium, 15
local journalButton = button(footer, "Journal", "Open journal", wood)
local upgrade = button(footer, "LevelUp", "Level up farm", green)
local status = label(footer, "Status", "", UDim2.new(1, 0, 0, 22), paper)
status.Font, status.TextSize = Enum.Font.GothamMedium, 13

local celebration = make("CanvasGroup", backdrop, {Name = "Celebration", AnchorPoint = Vector2.new(.5, .5),
    Position = UDim2.fromScale(.5, .5), BackgroundTransparency = 1, Visible = false})
local emblem = make("Frame", celebration, {Name = "Emblem", AnchorPoint = Vector2.new(.5, 0),
    Position = UDim2.new(.5, 0, 0, 8), Size = UDim2.fromOffset(78, 78), BackgroundColor3 = gold, BorderSizePixel = 0})
trim(emblem, Color3.fromRGB(255, 221, 131), 39, 4)
local emblemScale = make("UIScale", emblem, {Scale = .5})
local roof = make("Frame", emblem, {Position = UDim2.fromOffset(23, 20), Size = UDim2.fromOffset(32, 32),
    Rotation = 45, BackgroundColor3 = Color3.fromRGB(170, 76, 41), BorderSizePixel = 0})
local barn = make("Frame", emblem, {Position = UDim2.fromOffset(19, 35), Size = UDim2.fromOffset(40, 28),
    BackgroundColor3 = Color3.fromRGB(170, 76, 41), BorderSizePixel = 0})
trim(barn, paper, 2, 2)
make("Frame", barn, {Position = UDim2.fromOffset(13, 9), Size = UDim2.fromOffset(14, 19),
    BackgroundColor3 = ink, BorderSizePixel = 0})
local celebrationTitle = label(celebration, "Title", "Farm upgraded!", UDim2.new(1, 0, 0, 40), paper)
celebrationTitle.Position, celebrationTitle.TextXAlignment, celebrationTitle.TextSize = UDim2.fromOffset(0, 96), Enum.TextXAlignment.Center, 31
local transitionText = label(celebration, "Levels", "", UDim2.new(1, 0, 0, 66), gold)
transitionText.Position, transitionText.TextXAlignment, transitionText.TextSize = UDim2.fromOffset(0, 138), Enum.TextXAlignment.Center, 55
local celebrationName = label(celebration, "LevelName", "", UDim2.new(1, 0, 0, 30), paper)
celebrationName.Position, celebrationName.TextXAlignment, celebrationName.TextSize = UDim2.fromOffset(0, 204), Enum.TextXAlignment.Center, 20
local celebrationList = scroll(celebration, "NewUnlocks")
celebrationList.Position, celebrationList.Size = UDim2.fromOffset(0, 248), UDim2.new(1, 0, 1, -316)
stack(celebrationList, 8)
for index = 1, maxUnlocks do
    local row = make("CanvasGroup", celebrationList, {Name = "Unlock" .. index, Size = UDim2.new(1, 0, 0, 62),
        LayoutOrder = index, BorderSizePixel = 0, BackgroundColor3 = paper})
    trim(row, gold, 10, 1)
    local image = icon(row)
    image.Position, image.Size = UDim2.fromOffset(10, 5), UDim2.fromOffset(52, 52)
    local text = label(row, "Title", "", UDim2.new(1, -82, 1, -8))
    text.Position = UDim2.fromOffset(72, 4)
    celebrationRows[index] = {Root = row, Icon = image, Text = text}
end
local continue = button(celebration, "Continue", "Skip", green)
continue.AnchorPoint, continue.Position, continue.Size = Vector2.new(.5, 1), UDim2.new(.5, 0, 1, -4), UDim2.fromOffset(220, 48)
local particles = make("Frame", celebration, {Name = "Particles", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1})

local function captureInput()
    if savedPrompts ~= nil then return end
    savedPrompts = ProximityPromptService.Enabled
    ProximityPromptService.Enabled = false
    local inventory = playerGui:FindFirstChild("InventoryGui")
    if inventory then savedInventory = inventory.Enabled;inventory.Enabled = false end
end

local function restoreInput()
    if savedPrompts ~= nil then ProximityPromptService.Enabled = savedPrompts;savedPrompts = nil end
    local inventory = playerGui:FindFirstChild("InventoryGui")
    if inventory and savedInventory ~= nil then inventory.Enabled = savedInventory end
    savedInventory = nil
end

setOpen = function(value)
    generation += 1
    opened, celebrating = value, false
    player:SetAttribute("FarmOverviewOpen", value)
    particles:ClearAllChildren()
    celebration.Visible = false
    if value then
        HudMenu.CloseStorage()
        local book = playerGui:FindFirstChild("FarmJournalGui")
        local closeBook = book and book:FindFirstChild("CloseMenu")
        if closeBook then closeBook:Invoke() end
        captureInput()
        notice.Visible = false
        panel.Visible, backdrop.Visible = true, true
        tween(backdrop, {BackgroundTransparency = .35})
        tween(panel, {GroupTransparency = 0})
        remote:FireServer("Get")
        refresh()
    else
        restoreInput()
        tween(backdrop, {BackgroundTransparency = 1})
        tween(panel, {GroupTransparency = 1})
        local token = generation
        task.delay(.25, function() if generation == token then backdrop.Visible = false end end)
    end
end

local function celebrate(previous, level)
    generation += 1
    local token = generation
    opened, celebrating = true, true
    player:SetAttribute("FarmOverviewOpen", true)
    captureInput()
    notice.Visible, panel.Visible, backdrop.Visible, celebration.Visible = false, false, true, true
    celebration.GroupTransparency, emblemScale.Scale = 1, .5
    continue.Text = "Skip"
    local definition = levels.Levels[level]
    transitionText.Text = tostring(previous)
    celebrationName.Text = "Level " .. level .. " - " .. definition.Name
    particles:ClearAllChildren()
    for index, row in ipairs(celebrationRows) do
        local unlock = definition.Unlocks[index]
        row.Root.Visible, row.Root.GroupTransparency = unlock ~= nil, 1
        if unlock then row.Icon.Image = definitions[unlock.Icon].Icon or "";row.Text.Text = unlock.Name end
    end
    tween(backdrop, {BackgroundTransparency = .15}, .35)
    tween(celebration, {GroupTransparency = 0}, .35)
    tween(emblemScale, {Scale = celebration:GetAttribute("EmblemScale") or 1}, .6)
    task.delay(.55, function()
        if generation ~= token then return end
        transitionText.Text = previous .. "  →  " .. level
        for index = 1, 18 do
            local leaf = make("Frame", particles, {Position = UDim2.fromScale(.5, .15), Size = UDim2.fromOffset(index % 3 == 0 and 10 or 5, 8),
                BackgroundColor3 = index % 3 == 0 and Color3.fromRGB(164, 184, 87) or gold, BorderSizePixel = 0, Rotation = index * 23})
            make("UICorner", leaf, {CornerRadius = UDim.new(.5, 0)})
            tween(leaf, {Position = UDim2.fromScale(.08 + (index % 9) * .105, .5 + (index % 4) * .08),
                Rotation = index * 41, BackgroundTransparency = 1}, 1.7)
        end
        for index, row in ipairs(celebrationRows) do
            task.delay(.45 + index * .18, function()
                if generation == token and row.Root.Visible then tween(row.Root, {GroupTransparency = 0}, .3) end
            end)
        end
    end)
    task.delay(2.4, function()
        if generation == token then transitionText.Text = tostring(level);continue.Text = "Continue" end
    end)
end

refresh = function(message)
    if not state then return end
    local level = state.FarmLevel
    local definition = levels.Levels[level]
    local chapter = chapterFor(level)
    badge.Visible = state.Ready == true
    levelText.Text = "Level " .. level .. " - " .. definition.Name
    nextText.Text = level < levels.MaxLevel and "Next: level " .. (level + 1) or "Maximum level"
    local completed = 0
    for index, row in ipairs(taskRows) do
        local objective = chapter.Objectives[index]
        row.Root.Visible = objective ~= nil
        if objective then
            local count = math.min(objective.Goal, state.Counts[objective.Id] or 0)
            local done = count >= objective.Goal or state.Completed[chapter.Id] == true
            if done then completed += 1 end
            row.Icon.Image = definitions[objective.Icon].Icon or ""
            row.Text.Text = objective.Text
            row.Count.Text = done and "Done" or formatCount(objective, count) .. "/" .. formatCount(objective, objective.Goal)
            row.Count.TextColor3 = done and green or ink
        end
    end
    taskProgress.Text = completed .. " / " .. #chapter.Objectives .. " tasks complete"
    tween(progressFill, {Size = UDim2.fromScale(completed / #chapter.Objectives, 1)})
    local nextLevel = levels.Levels[level + 1]
    unlockHeading.Text = nextLevel and "Next level unlocks" or "A thriving farm"
    maxLabel.Visible, unlockList.Visible = nextLevel == nil, nextLevel ~= nil
    for index, row in ipairs(unlockRows) do
        local unlock = nextLevel and nextLevel.Unlocks[index]
        row.Root.Visible = unlock ~= nil
        if unlock then row.Icon.Image = definitions[unlock.Icon].Icon or "";row.Text.Text = unlock.Name end
    end
    local rewards = {string.format("$%.2f", chapter.Reward.MoneyCents / 100)}
    for name, amount in pairs(chapter.Reward.Items) do table.insert(rewards, amount .. " " .. definitions[name].DisplayName) end
    rewardText.Text = (state.Claimed[chapter.Id] and "Chapter reward claimed: " or "Chapter reward: ") .. table.concat(rewards, " + ")
    upgrade.Text = level == levels.MaxLevel and "Maximum farm level" or state.Ready and "Level up farm" or "Complete chapter tasks"
    upgrade.Interactable, upgrade.AutoButtonColor = state.Ready == true and not pending, state.Ready == true and not pending
    upgrade.BackgroundColor3 = state.Ready and green or Color3.fromRGB(114, 123, 88)
    status.Text = level == levels.MaxLevel and "Finish the final chapter for its reward." or state.Ready and "Ready to grow. Level up is free." or "Main chapter tasks unlock levels."
    if state.Completed[chapter.Id] and not state.Claimed[chapter.Id] then status.Text = "Reward waiting: make room, then visit the journal." end
    local messages = {NotComplete = "Finish the main chapter first.", LevelChanged = "Your farm level is already up to date.", DataNotReady = "Wait for your farm to load."}
    if typeof(message) == "string" then status.Text = messages[message] or status.Text end
    layout()
end

farmButton.Activated:Connect(function() setOpen(true) end)
notice.Activated:Connect(function() setOpen(true) end)
close.Activated:Connect(function() setOpen(false) end)
continue.Activated:Connect(function() setOpen(false) end)
backdrop.Activated:Connect(function() setOpen(false) end)
journalButton.Activated:Connect(function()
    if not state then return end
    local book = playerGui:FindFirstChild("FarmJournalGui")
    local openChapter = book and book:FindFirstChild("OpenChapter")
    if openChapter then local id = levels.Levels[state.FarmLevel].Chapter;setOpen(false);openChapter:Invoke(id) end
end)
upgrade.Activated:Connect(function()
    if not state or not state.Ready or pending then return end
    pending = true
    refresh()
    remote:FireServer("LevelUp", tostring(state.FarmLevel))
    task.delay(1, function() pending = false;refresh() end)
end)
make("BindableFunction", gui, {Name = "Open"}).OnInvoke = function() setOpen(true) end
remote.OnClientEvent:Connect(function(data, message)
    state, pending = data, false
    refresh(message)
    if data.Notice == "LevelReady" and not opened then
        notice.Visible = true
        task.delay(5, function() notice.Visible = false end)
    end
    if typeof(message) == "table" and message.Kind == "LevelUp" then celebrate(message.Previous, message.Level) end
end)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    if opened and (input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Escape) then setOpen(false) end
end)
player.CharacterRemoving:Connect(function() setOpen(false) end)
for _, attribute in ipairs({"ProductionMode", "AnimalMenuOpen", "Milking", "FeederOpen", "Teleporting", "WorldMapOpen", "FarmJournalOpen", "LaboratoryOpen"}) do
    player:GetAttributeChangedSignal(attribute):Connect(function()
        if player:GetAttribute(attribute) and opened then setOpen(false) end
    end)
end
layout = function()
    local size = gui.AbsoluteSize
    local width, height = math.min(920, size.X - 24), math.min(650, size.Y - 20)
    local portrait, compact = width < 620, height < 500
    local short = height < 400
    panel.Size = UDim2.fromOffset(width, height)
    title.TextSize = compact and 25 or 29
    title.Position, title.Size = UDim2.fromOffset(22, short and 2 or 8), UDim2.new(1, -94, 0, short and 32 or 42)
    levelText.TextSize, nextText.TextSize = portrait and 17 or 22, portrait and 15 or 18
    levelText.Position = UDim2.fromOffset(22, short and 36 or 54)
    levelText.Size = UDim2.new(.68, -26, 0, short and 26 or 38)
    nextText.Position, nextText.Size = UDim2.new(.68, 0, 0, short and 36 or 54), UDim2.new(.32, -18, 0, short and 26 or 38)
    local top, bottom = short and 68 or compact and 90 or 104, short and 72 or compact and 102 or 118
    content.Position, content.Size = UDim2.fromOffset(12, top), UDim2.new(1, -24, 1, -top - bottom)
    nextText.Visible = not short
    if state then
        local level = state.FarmLevel
        local prefix = short and level < levels.MaxLevel and "Level " .. level .. " → " .. (level + 1) or "Level " .. level
        levelText.Text = prefix .. " - " .. levels.Levels[level].Name
    end
    local count = state and #chapterFor(state.FarmLevel).Objectives or 5
    local unlockCount = state and levels.Levels[state.FarmLevel + 1] and #levels.Levels[state.FarmLevel + 1].Unlocks or 0
    if portrait then
        local tasksHeight, unlocksHeight = 92 + count * 60, math.max(150, 60 + unlockCount * 90)
        tasks.Position, tasks.Size = UDim2.fromOffset(3, 3), UDim2.new(1, -12, 0, tasksHeight)
        unlockPanel.Position, unlockPanel.Size = UDim2.fromOffset(3, tasksHeight + 16), UDim2.new(1, -12, 0, unlocksHeight)
        content.CanvasSize = UDim2.fromOffset(0, tasksHeight + unlocksHeight + 26)
        taskList.ScrollingEnabled, unlockList.ScrollingEnabled = false, false
    else
        tasks.Position, tasks.Size = UDim2.fromOffset(3, 3), UDim2.new(.56, -9, 1, -10)
        unlockPanel.Position, unlockPanel.Size = UDim2.new(.56, 6, 0, 3), UDim2.new(.44, -15, 1, -10)
        content.CanvasSize = UDim2.new()
        taskList.ScrollingEnabled, unlockList.ScrollingEnabled = true, true
    end
    local tight = compact and not portrait
    taskHeading.TextSize = short and 18 or tight and 19 or 22
    taskHeading.Size = UDim2.new(1, short and -96 or -24, 0, 32)
    taskProgress.Position, taskProgress.TextSize = UDim2.fromOffset(14, tight and 31 or 39), tight and 13 or 14
    if short then
        taskProgress.Position, taskProgress.Size = UDim2.new(1, -78, 0, 4), UDim2.fromOffset(64, 28)
    else taskProgress.Size = UDim2.new(1, -24, 0, 22) end
    taskProgress.TextXAlignment = short and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
    local fraction = taskProgress.Text:match("%d+ / %d+")
    if fraction then taskProgress.Text = fraction .. (short and "" or " tasks complete") end
    progress.Position = UDim2.fromOffset(14, short and 34 or tight and 57 or 67)
    taskList.UIPadding.PaddingBottom = UDim.new(0, short and 0 or tight and 2 or 4)
    taskList.UIListLayout.Padding = UDim.new(0, tight and 2 or 6)
    for _, row in ipairs(taskRows) do
        row.Root.Size = UDim2.new(1, 0, 0, tight and 28 or 54)
        row.Icon.Position, row.Icon.Size = UDim2.fromOffset(0, tight and 2 or 7), UDim2.fromOffset(tight and 26 or 38, tight and 26 or 38)
        row.Text.Position, row.Text.Size = UDim2.fromOffset(tight and 36 or 46, 2), UDim2.new(1, tight and -112 or -124, 1, -4)
        row.Text.TextSize, row.Count.TextSize = tight and 15 or 17, tight and 14 or 16
        row.Count.Position, row.Count.Size = UDim2.new(1, -76, 0, 0), UDim2.fromOffset(72, tight and 28 or 54)
    end
    unlockList.UIListLayout.Padding = UDim.new(0, tight and 6 or 8)
    for _, row in ipairs(unlockRows) do
        row.Root.Size = UDim2.new(1, 0, 0, tight and 49 or 82)
        row.Icon.Position, row.Icon.Size = UDim2.fromOffset(7, 5), UDim2.fromOffset(tight and 39 or 64, tight and 39 or 64)
        row.Text.Position, row.Text.Size = UDim2.fromOffset(tight and 60 or 80, 4), UDim2.new(1, tight and -66 or -88, 1, -8)
        row.Text.TextSize = tight and 17 or 19
    end
    taskList.Position, taskList.Size = UDim2.fromOffset(10, short and 42 or tight and 66 or 82), UDim2.new(1, -20, 1, short and -48 or tight and -72 or -88)
    unlockHeading.TextSize = short and 18 or 21
    unlockList.Position, unlockList.Size = UDim2.fromOffset(8, short and 42 or 48), UDim2.new(1, -16, 1, short and -48 or -56)
    footer.Position, footer.Size = UDim2.new(0, 18, 1, -bottom + 4), UDim2.new(1, -36, 0, bottom - 8)
    journalButton.Position, journalButton.Size = UDim2.fromOffset(0, short and 20 or compact and 28 or 34), UDim2.new(.34, -5, 0, compact and 44 or 46)
    upgrade.Position, upgrade.Size = UDim2.new(.34, 5, 0, short and 20 or compact and 28 or 34), UDim2.new(.66, -5, 0, compact and 44 or 46)
    upgrade.TextSize, journalButton.TextSize = portrait and 17 or 21, portrait and 16 or 18
    status.Visible = not short
    status.Position = UDim2.fromOffset(0, compact and 76 or 87)
    status.Size = UDim2.new(1, 0, 0, compact and 18 or 22)
    rewardText.Size = UDim2.new(1, 0, 0, short and 20 or 28)
    rewardText.TextSize, status.TextSize = portrait and 13 or 15, portrait and 12 or 13
    local celebrationHeight = math.min(size.Y - 24, 566)
    celebration.Size = UDim2.fromOffset(math.min(size.X - 40, 530), celebrationHeight)
    local small = celebrationHeight < 430
    emblem.Position = UDim2.new(.5, 0, 0, 6)
    emblem.Size = UDim2.fromOffset(78, 78)
    emblem.Visible = true
    emblem.Position = small and UDim2.fromOffset(34, 2) or UDim2.new(.5, 0, 0, 8)
    celebration:SetAttribute("EmblemScale", small and .55 or 1)
    celebrationTitle.TextSize = small and 25 or 31
    celebrationTitle.Position = UDim2.fromOffset(0, small and 0 or 96)
    transitionText.Position = UDim2.fromOffset(0, small and 38 or 138)
    celebrationName.Position = UDim2.fromOffset(0, small and 102 or 204)
    celebrationList.Position = UDim2.fromOffset(0, small and 136 or 248)
    celebrationList.Size = UDim2.new(1, 0, 1, small and -198 or -310)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
layout()
task.spawn(function()
    while player:GetAttribute("DataLoaded") ~= true do player:GetAttributeChangedSignal("DataLoaded"):Wait() end
    remote:FireServer("Get")
end)
