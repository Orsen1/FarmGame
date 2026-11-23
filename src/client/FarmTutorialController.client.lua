local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local config = require(ReplicatedStorage.Configs.FarmTutorialConfig)
local definitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local remote = remotes:WaitForChild("FarmJournal")
local ink, paper = Color3.fromRGB(94, 59, 32), Color3.fromRGB(255, 236, 190)
local green, gold = Color3.fromRGB(91, 139, 61), Color3.fromRGB(237, 189, 87)
local tutorial, minimized, hadTutorial, doneUntil = nil, false, false, 0
local inspected = {}
local shownStep
local refresh

local function make(class, parent, properties)
    local object = Instance.new(class)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = parent
    return object
end

local function trim(object, color, radius, thickness)
    make("UICorner", object, {CornerRadius = UDim.new(0, radius or 12)})
    make("UIStroke", object, {Color = color or ink, Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end

local function text(parent, name, size, fontSize, color)
    return make("TextLabel", parent, {Name = name, Size = size, Text = "", BackgroundTransparency = 1,
        Font = Enum.Font.FredokaOne, TextSize = fontSize, TextColor3 = color or ink,
        TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true})
end

local gui = make("ScreenGui", playerGui, {Name = "FarmTutorialGui", ResetOnSpawn = false, DisplayOrder = 42,
    ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
local card = make("CanvasGroup", gui, {Name = "Guide", AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, 0, 8),
    Size = UDim2.fromOffset(440, 176), BackgroundColor3 = paper, BorderSizePixel = 0, Visible = false})
trim(card, Color3.fromRGB(151, 103, 55), 14, 2.5)
local category = text(card, "Chapter", UDim2.new(1, -90, 0, 20), 12, Color3.fromRGB(140, 95, 46))
category.Position = UDim2.fromOffset(16, 8)
local minimize = make("TextButton", card, {Name = "Minimize", Text = "-", Position = UDim2.new(1, -44, 0, 5),
    Size = UDim2.fromOffset(36, 36), TextSize = 24, Font = Enum.Font.FredokaOne, TextColor3 = ink,
    BackgroundColor3 = Color3.fromRGB(239, 210, 158), BorderSizePixel = 0})
trim(minimize, Color3.fromRGB(186, 139, 77), 8, 1)
local icon = make("ImageLabel", card, {Name = "Icon", Position = UDim2.fromOffset(14, 34),
    Size = UDim2.fromOffset(52, 52), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit})
local title = text(card, "Title", UDim2.new(1, -94, 0, 38), 21)
title.Position = UDim2.fromOffset(76, 30)
local body = text(card, "Body", UDim2.new(1, -32, 0, 48), 14)
body.Position, body.Font, body.TextYAlignment = UDim2.fromOffset(16, 84), Enum.Font.GothamMedium, Enum.TextYAlignment.Top
local action = make("TextButton", card, {Name = "Action", Position = UDim2.new(0, 14, 1, -50), Size = UDim2.new(1, -28, 0, 42),
    Text = "", Font = Enum.Font.FredokaOne, TextSize = 18, TextColor3 = paper, BackgroundColor3 = green, BorderSizePixel = 0})
trim(action, Color3.fromRGB(66, 101, 44), 9, 1.5)
local rail = make("Frame", card, {Name = "Progress", Position = UDim2.fromOffset(16, 75), Size = UDim2.new(1, -32, 0, 4),
    BackgroundColor3 = Color3.fromRGB(219, 188, 136), BorderSizePixel = 0})
make("UICorner", rail, {CornerRadius = UDim.new(0, 2)})
local fill = make("Frame", rail, {Name = "Fill", BackgroundColor3 = green, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1)})
make("UICorner", fill, {CornerRadius = UDim.new(0, 2)})

local marker = make("BillboardGui", playerGui, {Name = "TutorialWaypoint", Size = UDim2.fromOffset(180, 46),
    StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0), AlwaysOnTop = true, MaxDistance = 180, Enabled = false})
local markerText = text(marker, "Hint", UDim2.fromScale(1, 1), 18, paper)
markerText.TextXAlignment, markerText.BackgroundColor3, markerText.BackgroundTransparency = Enum.TextXAlignment.Center, green, .08
trim(markerText, gold, 12, 1.5)
local outline = make("Highlight", workspace, {Name = "TutorialBedHighlight", FillTransparency = .94, OutlineColor = gold,
    FillColor = gold, DepthMode = Enum.HighlightDepthMode.Occluded, Enabled = false})

local function anyMenuOpen()
    for _, attribute in ipairs({"FarmJournalOpen", "FarmOverviewOpen", "WorldMapOpen", "StorageOpen",
        "ProductionMode", "AnimalMenuOpen", "LaboratoryOpen", "FeederOpen", "Milking", "Teleporting"}) do
        if player:GetAttribute(attribute) then return true end
    end
    for _, name in ipairs({"BuyGui", "FarmStandGui"}) do
        local other = playerGui:FindFirstChild(name)
        if other and other.Enabled and other.MainFrame.Visible then return true end
    end
    return false
end

local function currentBed()
    if tutorial and tutorial.Bed and tutorial.Bed:IsDescendantOf(workspace) then return tutorial.Bed end
    local plots = workspace:FindFirstChild("Plots")
    local plot = plots and plots:FindFirstChild(player:GetAttribute("PlotName") or "")
    for _, object in ipairs(plot and plot.PlacedObjects:GetChildren() or {}) do
        if tutorial and (object:GetAttribute("ItemName") or object.Name) == tutorial.BedItem then return object end
    end
end

local function selectItem(itemName)
    local inventory = player:FindFirstChild("Inventory")
    for _, slot in ipairs(inventory and inventory:GetChildren() or {}) do
        if slot.ItemName.Value == itemName and slot.Amount.Value > 0 then
            local index = tonumber(slot.Name:match("%d+"))
            local view = playerGui:FindFirstChild("InventoryGui")
            local selectSlot = view and view:FindFirstChild("SelectSlot")
            if selectSlot then selectSlot:Invoke(index) end
            return
        end
    end
end

local function invoke(guiName, functionName, value)
    local other = playerGui:FindFirstChild(guiName)
    local callback = other and other:FindFirstChild(functionName)
    if callback then callback:Invoke(value) end
end

action.Activated:Connect(function()
    if not tutorial then return end
    local step = tutorial.Step
    if step == "BuyBed" then invoke("BuyGui", "OpenShop", "Buildings")
    elseif step == "BuySeeds" then invoke("BuyGui", "OpenShop", "Seeds")
    elseif step == "BuyCan" then invoke("BuyGui", "OpenShop", "Equipment")
    elseif step == "Place" then selectItem(tutorial.BedItem)
    elseif step == "Plant" then selectItem(tutorial.SeedItem)
    elseif step == "Grow" and currentBed() and currentBed():GetAttribute("GrowthLastSegment") then
        invoke("FarmJournalGui", "OpenChapter", "NewBeginning")
    elseif step == "Water" or step == "Grow" then selectItem("WateringCan")
    elseif step == "Farm" then invoke("MyFarmGui", "Open")
    elseif step == "Journal" or step == "Complete" then invoke("FarmJournalGui", "OpenChapter", "NewBeginning")
    elseif step == "Sell" then
        minimized = true
        refresh()
    end
end)
minimize.Activated:Connect(function()
    if tutorial and tutorial.Completed then doneUntil = 0 end
    minimized = not minimized
    refresh()
end)

local function watchMenu(attribute, name)
    player:GetAttributeChangedSignal(attribute):Connect(function()
        if not tutorial then return end
        if player:GetAttribute(attribute) and tutorial.Step == name then inspected[name] = true
        elseif not player:GetAttribute(attribute) and inspected[name] then
            for _, delay in ipairs({.2, .8}) do
                task.delay(delay, function()
                    if not tutorial or tutorial.Completed or player:GetAttribute(attribute) then return end
                    local waiting = name == "Farm" and not tutorial.FarmSeen or
                        name == "Journal" and tutorial.FarmSeen and not tutorial.JournalSeen
                    if waiting then remote:FireServer("Tutorial", name) end
                end)
            end
        end
    end)
end
watchMenu("FarmOverviewOpen", "Farm")
watchMenu("FarmJournalOpen", "Journal")

refresh = function()
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local active = tutorial and (not tutorial.Completed or os.clock() < doneUntil)
    local visible = active and player:GetAttribute("DataLoaded") == true and humanoid and humanoid.Health > 0 and not anyMenuOpen()
    card.Visible = visible == true
    marker.Enabled, outline.Enabled = false, false
    if not tutorial or not active then return end
    local step = tutorial.Step
    local info = config.Steps[step]
    if not info and step ~= "Complete" then return end
    local size = gui.AbsoluteSize
    local compact = size.Y < 400
    local width = math.min(compact and 480 or 440, size.X - (compact and 300 or 24))
    width = math.max(260, width)
    local placing = playerGui:FindFirstChild("PlacementControls") ~= nil and step == "Place"
    local folded = minimized or placing
    card.Position = UDim2.new(.5, 0, 0, placing and 50 or not compact and size.X < 700 and 64 or 8)
    card.Size = UDim2.fromOffset(width, folded and 44 or compact and 152 or 186)
    category.Text = tutorial.Completed and "FIRST HARVEST COMPLETE" or "FIRST HARVEST  /  " .. info.Order .. " OF 10"
    title.Text = tutorial.Completed and "A great start!" or info.Title
    local iconName = tutorial.Completed and (tutorial.CropItem or "Carrot") or info.Icon
    if step == "Plant" then iconName = tutorial.SeedItem
    elseif step == "Place" then iconName = tutorial.BedItem
    elseif step == "Harvest" or step == "Sell" then iconName = tutorial.CropItem end
    icon.Image = definitions[iconName] and definitions[iconName].Icon or ""
    local description = tutorial.Completed and
        string.format("Your first harvest is sold! +$%.2f. Shops are open; Town orders pay extra. Keep growing to unlock farm levels.", config.CompletionRewardCents / 100) or (compact and (info.ShortText or info.Text) or info.Text)
    if tutorial.Completed and compact then description = string.format("First harvest sold! +$%.2f. Shops and Town orders are now available.", config.CompletionRewardCents / 100) end
    description = description:gsub("{capacity}", tostring(tutorial.Capacity or 1))
        :gsub("{seed}", definitions[tutorial.SeedItem or ""] and definitions[tutorial.SeedItem].DisplayName or "seeds")
        :gsub("{remaining}", tostring(tutorial.Harvested - tutorial.Sold))
    body.Text, action.Text = description:gsub("1 seeds", "1 seed"), tutorial.Completed and "See the next journal tasks" or info.Action
    local bed = currentBed()
    if step == "Grow" and bed then
        local endsAt = bed:GetAttribute("GrowthEndsAt")
        if endsAt then
            local seconds = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
            local last = bed:GetAttribute("GrowthLastSegment")
            title.Text = (last and "Harvest in " or "Water in ") .. seconds .. "s"
            body.Text = last and "Your crop is ripening. Explore the journal while it grows." or "Equip the watering can and watch for the blue drop."
            action.Text = last and "Open journal" or "Select watering can"
        end
    end
    minimize.Text = folded and "+" or "-"
    category.Visible, icon.Visible, body.Visible, action.Visible, rail.Visible = not folded, not folded, not folded, not folded, not folded
    title.Position = folded and UDim2.fromOffset(14, 2) or UDim2.fromOffset(compact and 62 or 76, compact and 23 or 29)
    title.Size = folded and UDim2.new(1, -62, 1, -4) or UDim2.new(1, compact and -112 or -94, 0, compact and 30 or 40)
    title.TextSize = compact and 18 or 21
    category.Position, category.TextSize = UDim2.fromOffset(14, compact and 4 or 8), compact and 10 or 12
    icon.Position, icon.Size = UDim2.fromOffset(12, compact and 25 or 34), UDim2.fromOffset(compact and 40 or 52, compact and 40 or 52)
    rail.Position = UDim2.fromOffset(16, compact and 61 or 77)
    body.Position, body.Size = UDim2.fromOffset(16, compact and 69 or 87), UDim2.new(1, -32, 0, compact and 32 or 44)
    body.TextSize = compact and 13 or 14
    action.Position, action.Size = UDim2.new(0, 14, 1, compact and -49 or -52), UDim2.new(1, -28, 0, 44)
    action.TextSize = compact and 16 or 18
    if shownStep ~= step then
        shownStep = step
        TweenService:Create(fill, TweenInfo.new(.3), {Size = UDim2.fromScale(tutorial.Completed and 1 or (info.Order - 1) / 10, 1)}):Play()
        card.BackgroundColor3 = Color3.fromRGB(255, 223, 150)
        TweenService:Create(card, TweenInfo.new(.4), {BackgroundColor3 = paper}):Play()
    end
    if visible and (step == "Place" or step == "Sell") then
        local plots = workspace:FindFirstChild("Plots")
        local plot = plots and plots:FindFirstChild(player:GetAttribute("PlotName") or "")
        local stand = plot and plot:FindFirstChild("FarmStand")
        if step == "Sell" and stand then
            marker.Adornee, markerText.Text = stand.Nameboard, "Your farm stand"
            markerText.BackgroundColor3 = green
            marker.Enabled = true
            outline.Adornee, outline.Enabled = stand, true
        elseif step == "Place" and plot then
            marker.Adornee, markerText.Text = plot.SpawnPoint, "Your farm"
            marker.Enabled = true
        end
    end
    if visible and bed and (step == "Plant" or step == "Grow" or step == "Water" or step == "Harvest") then
        marker.Adornee = bed:FindFirstChild("PlacementRoot") or bed.PrimaryPart
        markerText.Text = step == "Water" and "Water crops" or step == "Harvest" and "Harvest ready" or step == "Plant" and "Plant here" or "Your first crop"
        markerText.BackgroundColor3 = step == "Water" and Color3.fromRGB(72, 135, 158) or green
        marker.Enabled = marker.Adornee ~= nil
        outline.Adornee, outline.Enabled = bed, true
    end
end

remote.OnClientEvent:Connect(function(data)
    if not data.Tutorial then return end
    local previous = tutorial
    tutorial = data.Tutorial
    if not tutorial.Completed then hadTutorial = true end
    if tutorial.Completed and previous and not previous.Completed and hadTutorial then doneUntil = os.clock() + 12;minimized = false end
    if not previous or previous.Step ~= tutorial.Step then minimized = false end
    refresh()
end)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)
player.CharacterRemoving:Connect(function() card.Visible = false;marker.Enabled = false;outline.Enabled = false end)
script.Destroying:Connect(function() outline:Destroy();marker:Destroy() end)
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    if elapsed >= .25 then elapsed = 0;refresh() end
end)
task.spawn(function()
    while player:GetAttribute("DataLoaded") ~= true do player:GetAttributeChangedSignal("DataLoaded"):Wait() end
    remote:FireServer("Get")
end)
