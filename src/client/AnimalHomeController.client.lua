local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local definitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local config = require(ReplicatedStorage.Configs.AnimalConfig)
local recipes = require(ReplicatedStorage.Configs.ProductionRecipes)
local View = require(script.Parent:WaitForChild("AnimalHomeView"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local inventory = player:WaitForChild("Inventory")
local remotes = ReplicatedStorage.RemoteEvents
local view = View.new(playerGui)
local current
local openingWorkshop
local outline = Instance.new("Highlight")
outline.Name = "AnimalHomeFocus"
outline.FillTransparency = 1
outline.OutlineColor = Color3.fromRGB(244, 204, 121)
outline.Enabled = false
outline.Parent = workspace

local function count(itemName)
    local amount = 0
    for _, slot in ipairs(inventory:GetChildren()) do
        if slot.ItemName.Value == itemName then amount += slot.Amount.Value end
    end
    return amount
end

local function upgradeFor(itemName)
    for id, definition in pairs(definitions) do
        if definition.UpgradeFrom == itemName then return id end
    end
end

local function close(immediate)
    if not current then return end
    local previous = current
    current = nil
    previous.Connection:Disconnect()
    ProximityPromptService.Enabled = previous.PromptsEnabled
    player:SetAttribute("AnimalMenuOpen", false)
    for gui, enabled in pairs(previous.Guis) do if gui.Parent then gui.Enabled = enabled end end
    outline.Enabled, outline.Adornee = false, nil
    view:Hide(immediate)
end

local function refreshWorkshop()
    local object, definition = current.Object, current.Definition
    local outputs, ids = {}, {}
    for _, id in ipairs(definition.Recipes) do
        for name in pairs(recipes[id].Outputs) do ids[name] = true end
    end
    local stored = object:FindFirstChild("OutputInventory")
    local names = {}
    for name in pairs(ids) do table.insert(names, name) end
    table.sort(names)
    for _, name in ipairs(names) do
        local value = stored and stored:FindFirstChild(name)
        table.insert(outputs, {Id = name, Icon = definitions[name].Icon, Amount = value and value.Value or 0})
    end
    local recipe = recipes[object:GetAttribute("ActiveRecipe")]
    local result = recipe and definitions[next(recipe.Outputs)]
    local duration = object:GetAttribute("ProductionDuration") or 0
    local elapsed = workspace:GetServerTimeNow() - (object:GetAttribute("ProductionStartedAt") or 0)
    view:UpdateWorkshop({Title = definition.DisplayName, Icon = current.Icon,
        MilkIcon = definitions[definition.MilkTank.Item].Icon, Stock = object:GetAttribute("MilkStock") or 0,
        Capacity = definition.MilkTank.Capacity, Owned = count(definition.MilkTank.Item), Outputs = outputs,
        Busy = object:GetAttribute("Busy") == true, ResultName = result and result.DisplayName or "Working",
        ResultIcon = result and result.Icon, Remaining = math.max(0, math.ceil(duration - elapsed)),
        Progress = duration > 0 and math.clamp(elapsed / duration, 0, 1) or 0, Pending = current.Pending})
end

local function refresh()
    if not current then return end
    if current.Workshop then refreshWorkshop();return end
    local object, settings = current.Object, current.Settings
    local egg = object:FindFirstChild("OutputInventory")
    egg = egg and settings.EggItem and egg:FindFirstChild(settings.EggItem)
    view:Update({Title = current.Definition.DisplayName, Icon = current.Icon,
        Count = object:GetAttribute("AnimalCount") or 0, Capacity = settings.Capacity,
        Hungry = object:GetAttribute("HungryCount") or 0, Stock = object:GetAttribute("FeedStock") or 0,
        PluralName = settings.PluralName, FeedName = definitions[settings.FeedItem].DisplayName,
        HasOutput = settings.EggItem ~= nil,
        FeedCapacity = settings.FeedCapacity, EggCapacity = settings.EggCapacity,
        Eggs = egg and egg.Value or 0, Wheat = count(settings.FeedItem), Owned = count(settings.ItemName),
        FeedIcon = definitions[settings.FeedItem].Icon, EggIcon = settings.EggItem and definitions[settings.EggItem].Icon or "",
        AnimalIcon = definitions[settings.ItemName].Icon, HasUpgrade = current.Upgrade ~= nil,
        UpgradeOwned = current.Upgrade and count(current.Upgrade) or 0, Pending = current.Pending})
end

local function open(object)
    if not object or not object:IsDescendantOf(workspace) then return end
    local id = object:GetAttribute("ItemName") or object.Name
    local settings, definition = config.Coops[id], definitions[id]
    local workshop = definition and definition.InteractionMenu and definition.MilkTank ~= nil
    if not definition or not (workshop or settings and settings.InteractionMenu) or
        object:GetAttribute("OwnerUserId") ~= player.UserId then return end
    close(true)
    local icon = definition.Icon
    if not icon or icon == "" then
        for _, item in pairs(definitions) do if item.BuildsInto == id then icon = item.Icon;break end end
    end
    current = {Object = object, Settings = settings, Definition = definition, Workshop = workshop, Upgrade = upgradeFor(id),
        Icon = icon or settings and definitions[settings.ItemName].Icon or "", Guis = {}, PromptsEnabled = ProximityPromptService.Enabled}
    current.Connection = object.Destroying:Connect(function() close(true) end)
    for _, name in ipairs({"InventoryGui", "MoneyGui"}) do
        local gui = playerGui:FindFirstChild(name)
        if gui then current.Guis[gui] = gui.Enabled;gui.Enabled = false end
    end
    ProximityPromptService.Enabled = false
    player:SetAttribute("AnimalMenuOpen", true)
    outline.Adornee, outline.Enabled = object, true
    view:ShowConfirm(false)
    view:Message("", true)
    view.Actions.CanvasPosition = Vector2.zero
    refresh()
    view:Show()
end

local function send(action, amount)
    if not current or current.Pending then return end
    if current.Workshop and action == "Work" then
        local object = current.Object
        close(true)
        openingWorkshop = object
        remotes.ProductionCommand:FireServer("Menu", object, "Work")
        return
    end
    if action == "Shop" or action == "UpgradeShop" then
        local object = current.Object
        close(false)
        remotes.AnimalCommand:FireServer(object, action)
        return
    end
    current.Pending = true
    current.RequestedAt = os.clock()
    if current.Workshop then
        if action == "Feed" then remotes.ProductionCommand:FireServer("Deposit", current.Object, amount)
        else remotes.ProductionCommand:FireServer("Menu", current.Object, action) end
    else remotes.AnimalCommand:FireServer(current.Object, action, amount) end
    refresh()
end

for amount, button in pairs(view.FeedButtons) do button.Activated:Connect(function() send("Feed", amount) end) end
view.Collect.Activated:Connect(function() send("Collect") end)
view.CollectProducts.Activated:Connect(function() send("Collect") end)
view.Work.Activated:Connect(function() send("Work") end)
view.Add.Activated:Connect(function() send("Add") end)
view.Shop.Activated:Connect(function() send("Shop") end)
view.Upgrade.Activated:Connect(function()
    if not current or current.Pending then return end
    if current.Upgrade and count(current.Upgrade) > 0 then view:ShowConfirm(true)
    else send("UpgradeShop") end
end)
view.Back.Activated:Connect(function() view:ShowConfirm(false) end)
view.Pack.Activated:Connect(function() send("Upgrade") end)
view.Close.Activated:Connect(function() close(false) end)

remotes.AnimalFeedback.OnClientEvent:Connect(function(object, success, message, source)
    if source ~= "HomeMenu" then return end
    if success and message == "OpenHome" then open(object)
    elseif current and current.Object == object then
        current.Pending = false
        if success and message == "OpenShop" then close(false);return end
        view:Message(message, success)
        refresh()
    end
end)

remotes.ProductionState.OnClientEvent:Connect(function(action, data)
    if action == "MenuOpened" and data.Success then open(data.Station)
    elseif action == "MenuFeedback" or action == "TankFeedback" then
        if openingWorkshop == data.Station then
            openingWorkshop = nil
            if not data.Success then open(data.Station) end
        end
        if current and current.Workshop and current.Object == data.Station then
            current.Pending = false
            view:Message(data.Message, data.Success)
            refresh()
        end
    end
end)

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
    if not current then return end
    elapsed += dt
    if elapsed < 0.1 then return end
    elapsed = 0
    local object = current.Object
    local plot = workspace.Plots:FindFirstChild(player:GetAttribute("PlotName") or "")
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local prompt = object:FindFirstChild("ActionPrompt", true)
    local shop = playerGui:FindFirstChild("BuyGui")
    if not plot or plot:GetAttribute("OwnerUserId") ~= player.UserId or object.Parent ~= plot:FindFirstChild("PlacedObjects") or
        not object:IsDescendantOf(workspace) or not root or not humanoid or humanoid.Health <= 0 or
        not prompt or player:GetAttribute("DataLoaded") ~= true or object:GetAttribute("OwnerUserId") ~= player.UserId or
        player:GetAttribute("ProductionMode") == true or player:GetAttribute("Milking") == true or
        player:GetAttribute("Teleporting") == true or (root.Position - prompt.Parent.WorldPosition).Magnitude > prompt.MaxActivationDistance or
        (shop and shop.Enabled and shop.MainFrame.Visible) then close(true);return end
    if current.Pending and os.clock() - current.RequestedAt > 5 then
        current.Pending = false
        view:Message("Check the result and try again.", false)
    end
    view:Layout()
    refresh()
end)

UserInputService.InputBegan:Connect(function(input)
    if current and not UserInputService:GetFocusedTextBox() and
        (input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then close(false) end
end)
player.CharacterRemoving:Connect(function() close(true) end)
script.Destroying:Connect(function() close(true);outline:Destroy();view.Gui:Destroy() end)
