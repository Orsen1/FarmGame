local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Prompts = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local Actions = game:GetService("ContextActionService")
local Input = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local scripts = ReplicatedStorage:WaitForChild("PlacementScripts")
local Placement = require(scripts.PlacementController)
local Rules = require(scripts.PlacementRules)
local Catalog = require(scripts.BuildCatalog)
local Camera = require(scripts.BuildCamera)
local View = require(scripts.BuildView)
local Hud = require(ReplicatedStorage.HudMenu)
local definitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local gui = View.make("ScreenGui", playerGui, {Name = "BuildModeGui", ResetOnSpawn = false,
    ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, DisplayOrder = 49, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
local launch = View.text("TextButton", gui, "Open", "Build", 17, View.Paper)
launch.AnchorPoint, launch.Position = Vector2.new(1,.5), UDim2.new(1,-12,.5,0)
launch.TextYAlignment = Enum.TextYAlignment.Bottom
View.make("UIPadding", launch, {PaddingBottom = UDim.new(0,4)})
local icon = View.make("Frame", launch, {Name = "Hammer", BackgroundTransparency = 1, AnchorPoint = Vector2.new(.5,0),
    Position = UDim2.new(.5,0,0,5), Size = UDim2.fromOffset(36,28), Rotation = 36})
local function shape(x,y,w,h,color)
    local piece = View.make("Frame", icon, {Position = UDim2.fromOffset(x,y),Size = UDim2.fromOffset(w,h),
        BackgroundColor3 = color, BorderSizePixel = 0})
    View.trim(piece,3)
end
shape(15,6,7,22,View.Gold)
shape(7,2,23,9,Color3.fromRGB(122,147,141))

local panel = View.make("Frame",gui,{Name = "Catalog",Visible = false, Active = true, AnchorPoint = Vector2.new(1,0),
    BorderSizePixel = 0, BackgroundColor3 = View.Paper})
View.trim(panel,13)
local heading = View.text("TextLabel",panel,"Heading","Buildings",20)
heading.Position, heading.Size, heading.TextXAlignment = UDim2.fromOffset(9,2), UDim2.new(1,-59,0,45), Enum.TextXAlignment.Left
local exit = View.text("TextButton",panel,"Close","×",25,View.Gold)
exit.Size, exit.Position = UDim2.fromOffset(44,44), UDim2.new(1,-49,0,4)
local list = View.make("ScrollingFrame",panel,{Name = "Items",Active = true, Position = UDim2.fromOffset(5,54),
    Size = UDim2.new(1,-10,1,-60),CanvasSize = UDim2.new(),AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, BackgroundTransparency = 1, BorderSizePixel = 0})
View.make("UIPadding",list,{PaddingLeft = UDim.new(0,3),PaddingRight = UDim.new(0,7),PaddingTop = UDim.new(0,3),PaddingBottom = UDim.new(0,4)})
View.make("UIListLayout",list,{Padding = UDim.new(0,6),SortOrder = Enum.SortOrder.LayoutOrder})
local empty = View.text("TextLabel",list,"Empty","Your buildings and blueprints will appear here.",15)
empty.Size, empty.TextWrapped = UDim2.new(1,0,0,76), true
local zoom = View.make("Frame",gui,{Name = "Zoom",Visible = false,BackgroundTransparency = 1,
    Position = UDim2.fromOffset(7,7),Size = UDim2.fromOffset(99,46)})
local panHint = View.text("TextLabel",zoom,"PanHint","Drag to pan",13,View.Paper)
panHint.Position,panHint.Size = UDim2.fromOffset(102,3),UDim2.fromOffset(90,38)
local moveHint = View.text("TextLabel", gui, "MoveHint", "", 14, View.Paper)
moveHint.AnchorPoint, moveHint.Position = Vector2.new(.5, 1), UDim2.new(.5, 0, 1, -8)
moveHint.Size, moveHint.Visible = UDim2.fromOffset(245, 34), false
local session
for index, sign in ipairs({"+","−"}) do
    local b = View.text("TextButton",zoom,"Zoom"..index,sign,23,View.Paper)
    b.Size,b.Position = UDim2.fromOffset(44,44), UDim2.fromOffset((index-1)*50,0)
    b.Activated:Connect(function() if session then session.Camera.Zoom(index == 1 and .8 or 1.25) end end)
end

local blockers = {"Teleporting","Milking","ProductionMode","BedUpgradeOpen","AnimalMenuOpen","FeederOpen","StorageOpen",
    "WorldMapOpen","FarmOverviewOpen","FarmJournalOpen","FarmStandOpen","LaboratoryOpen"}
local function canOpen()
    if not Hud.Panel.Visible or not Prompts.Enabled or player:GetAttribute("DataLoaded") ~= true then return false end
    for _, key in ipairs(blockers) do if player:GetAttribute(key) then return false end end
    for _, name in ipairs({"InventoryDiscardGui","DeleteConfirmGui","OrderGui"}) do
        local modal = playerGui:FindFirstChild(name)
        if modal and modal.Enabled then return false end
    end
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0 and not char:GetAttribute("GatherStartedAt")
        and workspace.CurrentCamera and workspace.CurrentCamera.CameraType ~= Enum.CameraType.Scriptable
end

local function layout()
    local size = gui.AbsoluteSize
    local width = math.clamp(math.floor(size.X*.32),148,275)
    launch.Size = UDim2.fromOffset(size.X < 600 and 61 or 79, size.Y < 450 and 56 or 65)
    local available = math.max(96, size.Y - 112)
    local content = session and session.RowCount and 68 + math.max(1, session.RowCount)*65 or available
    panel.Size = UDim2.fromOffset(width, math.min(available, content))
    panHint.Visible = size.X-width > 213
    if not session then panel.Position = UDim2.new(1,-6,0,6) end
    heading.TextSize = width < 180 and 16 or 20
end

local function visibility()
    launch.Visible = not session and canOpen() == true
end

local function selection(message)
    local key = Placement.selection()
    moveHint.Visible = session ~= nil and key == nil
    local failure = typeof(message) == "string" and message or nil
    moveHint.Text = failure or "Drag a building to move it"
    moveHint.TextColor3 = failure and View.Red or View.Ink
    if not session then return end
    if failure then
        local current = session
        task.delay(1.8, function()
            if session == current and moveHint.Text == failure then selection() end
        end)
    end
    for id, row in pairs(session.Rows) do
        row.BackgroundColor3 = key == id and Color3.fromRGB(202,225,166) or Color3.fromRGB(247,221,166)
    end
end

local function startMove(point)
    if not session or Placement.selection() then return end
    local camera = workspace.CurrentCamera
    local placed = session.Placed
    if not camera or placed.Parent ~= session.Plot then return end
    local ray = camera:ViewportPointToRay(point.X, point.Y)
    local hit = workspace:Raycast(ray.Origin, ray.Direction * 1400, session.PickParams)
    local object = hit and hit.Instance
    if not object or not object:IsDescendantOf(placed) then return end
    while object.Parent ~= placed do object = object.Parent end
    return Placement.startMove(object, session.Plot, point)
end

local function refresh()
    local s = session
    if not s then return end
    for _, row in pairs(s.Rows) do row:Destroy() end
    table.clear(s.Rows)
    local entries = Catalog.Entries(player)
    s.RowCount = #entries
    layout()
    empty.Visible = #entries == 0
    for index, entry in ipairs(entries) do
        local definition = definitions[entry.Item]
        local row = View.text("TextButton",list,"Item_"..index,"",15,View.Gold)
        s.Rows[entry.Key] = row
        row.LayoutOrder, row.Size = index, UDim2.new(1,0,0,59)
        View.make("ImageLabel",row,{Name = "ItemIcon",BackgroundTransparency = 1,Image = definition.Icon or "",
            Position = UDim2.fromOffset(4,9),Size = UDim2.fromOffset(39,39),ScaleType = Enum.ScaleType.Fit})
        local name = View.text("TextLabel",row,"ItemName",definition.DisplayName,14)
        name.Position,name.Size,name.TextWrapped = UDim2.fromOffset(46,2),UDim2.new(1,-49,0,34),true
        name.TextXAlignment = Enum.TextXAlignment.Left
        local detail = entry.Kind == "Relocation" and ("Packed · "..(entry.Area == "Inventory" and "Bag " or "Store ")..entry.Index)
            or ("×"..entry.Amount.." owned")
        local count = View.text("TextLabel",row,"Amount",detail,12)
        count.Position,count.Size,count.TextXAlignment = UDim2.fromOffset(46,36),UDim2.new(1,-47,0,21),Enum.TextXAlignment.Left
        row.Activated:Connect(function() Placement.startPlacement(entry.Item,nil,entry) end)
    end
    selection()
end

local function close()
    local s = session
    if not s then return end
    session = nil
    for _, c in ipairs(s.Connections) do c:Disconnect() end
    Placement.cancelPlacement()
    Actions:UnbindAction("BuildBlockShortcuts")
    s.Camera.Close()
    s.Grid:Destroy()
    for _,row in pairs(s.Rows) do row:Destroy() end
    panel.Visible,zoom.Visible = false,false
    moveHint.Visible = false
    Prompts.Enabled = s.Prompts
    for element,enabled in pairs(s.Hidden) do if element.Parent then element.Enabled = enabled end end
    player:SetAttribute("BuildMode",false)
    visibility()
end

local function open()
    if session or not canOpen() then return end
    local plot = workspace.Plots:FindFirstChild(player:GetAttribute("PlotName") or "")
    local placed = plot and plot:FindFirstChild("PlacedObjects")
    if not placed or plot:GetAttribute("OwnerUserId") ~= player.UserId then return end
    Placement.cancelPlacement()
    local s = {Plot = plot, Placed = placed, Rows = {}, Hidden = {}, Connections = {}, Prompts = Prompts.Enabled,
        Grid = Instance.new("Folder")}
    s.PickParams = RaycastParams.new()
    s.PickParams.FilterType = Enum.RaycastFilterType.Include
    s.PickParams.FilterDescendantsInstances = {placed}
    s.Grid.Name,s.Grid.Parent = "BuildPlotGrid",workspace
    session = s
    player:SetAttribute("BuildMode",true)
    Prompts.Enabled = false
    for _,name in ipairs({"InventoryGui","MoneyGui","FarmMenuGui","FarmTutorialGui","MyFarmGui","FarmJournalGui","MarketReputationNotice"}) do
        local g = playerGui:FindFirstChild(name)
        if g then s.Hidden[g] = g.Enabled; g.Enabled = false end
    end
    layout()
    Actions:BindActionAtPriority("BuildBlockShortcuts",function() return Enum.ContextActionResult.Sink end,false,3200,
        Enum.KeyCode.One,Enum.KeyCode.Two,Enum.KeyCode.Three,Enum.KeyCode.Four,Enum.KeyCode.Five,Enum.KeyCode.Six,
        Enum.KeyCode.J,Enum.KeyCode.M)
    s.Camera = Camera.open(plot, function() return panel.AbsoluteSize.X end, {
        Start = startMove,
        Aim = Placement.aimMove,
        Drop = Placement.dropMove,
        Cancel = Placement.cancelMove,
    })
    launch.Visible,panel.Visible,zoom.Visible = false,true,true
    panel.Position = UDim2.new(1, panel.AbsoluteSize.X,0,6)
    TweenService:Create(panel,TweenInfo.new(.22,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
        {Position = UDim2.new(1,-6,0,6)}):Play()
    local function on(signal, callback) table.insert(s.Connections, signal:Connect(callback)) end
    local queued = false
    local function queue()
        if queued then return end
        queued = true
        task.defer(function() queued = false; if session == s then refresh() end end)
    end
    local function track(object)
        if object:IsA("ValueBase") then on(object.Changed,queue)
        elseif object:IsA("Folder") then on(object:GetAttributeChangedSignal("ObjectData"),queue) end
    end
    for _,folderName in ipairs({"Inventory","StorageInventory"}) do
        local folder = player:FindFirstChild(folderName)
        if folder then
            for _,object in ipairs(folder:GetDescendants()) do track(object) end
            on(folder.DescendantAdded,function(o) track(o); queue() end)
            on(folder.DescendantRemoving,queue)
        end
    end
    local function grid(floor)
        local draw = View.grid("Land",s.Grid,View.Green,.025)
        draw(floor.CFrame*CFrame.new(0,floor.Size.Y/2+.025,0),floor.Size,Rules.CellSize)
    end
    grid(plot.Ground)
    for _,section in ipairs(plot.Sections:GetChildren()) do
        if section:GetAttribute("Unlocked") then grid(section.Ground)
        else on(section:GetAttributeChangedSignal("Unlocked"),function() if section:GetAttribute("Unlocked") then grid(section.Ground) end end) end
    end
    on(player:GetAttributeChangedSignal("WarehouseReady"),queue)
    on(plot:GetAttributeChangedSignal("OwnerUserId"),close)
    on(plot.AncestryChanged,close)
    on(player.Character:FindFirstChildOfClass("Humanoid").Died,close)
    on(workspace:GetPropertyChangedSignal("CurrentCamera"),close)
    refresh()
end

launch.Activated:Connect(open)
exit.Activated:Connect(close)
Placement.Changed:Connect(selection)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
Hud.Panel:GetPropertyChangedSignal("Visible"):Connect(visibility)
Prompts:GetPropertyChangedSignal("Enabled"):Connect(visibility)
for _,key in ipairs(blockers) do
    player:GetAttributeChangedSignal(key):Connect(function()
        if session and player:GetAttribute(key) then close() end
        visibility()
    end)
end
for _,key in ipairs({"PlotName","DataLoaded"}) do
    player:GetAttributeChangedSignal(key):Connect(function() close(); visibility() end)
end
player.CharacterRemoving:Connect(close)
player.CharacterAdded:Connect(function(character) character:WaitForChild("Humanoid"); visibility() end)
Input.InputBegan:Connect(function(input,processed)
    if session and not processed and input.KeyCode == Enum.KeyCode.Escape then close() end
end)
layout()
visibility()
