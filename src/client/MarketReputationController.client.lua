local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Input = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local View = require(script.Parent:WaitForChild("MarketReputationView"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local view = View.new(playerGui)
local marketEvent = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("FarmStandEvent")
view.ChooseDirection = function(direction, level, previous)
    marketEvent:FireServer("ChooseDirection", direction, level, previous)
end
local stateAttribute = "MarketReputationState"
local busyAttributes = {"BuildMode", "Teleporting", "ProductionMode", "Milking", "AnimalMenuOpen", "FeederOpen",
    "LaboratoryOpen", "BedUpgradeOpen", "StorageOpen", "FarmJournalOpen", "FarmOverviewOpen", "WorldMapOpen", "FarmStandOpen"}
local fullScreens = {OrderGui = true, DeleteConfirmGui = true, InventoryDiscardGui = true}
local moneyGui, moneyWindow, moneyHome, moneyOrder
local shop, shopPanel

local function blocked()
    for _, attribute in ipairs(busyAttributes) do
        if player:GetAttribute(attribute) then return true end
    end
    for name in pairs(fullScreens) do
        local screen = playerGui:FindFirstChild(name)
        if screen and screen.Enabled then return true end
    end
    return shop and shop.Enabled and shopPanel and shopPanel.Visible
end

local function adjustBalance()
    local hud = view.Hud
    local inHeader = view.Mobile and view.Gui.Enabled and moneyGui and moneyGui.Enabled
    view:SetBalanceWidth(inHeader and moneyWindow.AbsoluteSize.X or 0)
    if not moneyWindow then return end
    moneyGui.DisplayOrder = inHeader and view.Gui.DisplayOrder + 1 or moneyOrder
    if not view.Gui.Enabled or hud.AbsoluteSize.Y == 0 then
        moneyWindow.Position = moneyHome
        return
    end

    local size = view.Gui.AbsoluteSize
    local top = hud.AbsolutePosition.Y - view.Gui.AbsolutePosition.Y
    if inHeader then
        moneyWindow.Position = UDim2.new(1, hud.Position.X.Offset - 8, 0, top + 5)
    elseif size.Y < 380 and size.X >= hud.AbsoluteSize.X + moneyWindow.AbsoluteSize.X + 31 then
        moneyWindow.Position = UDim2.new(1, hud.Position.X.Offset - hud.AbsoluteSize.X - 7, 0, top)
    else
        moneyWindow.Position = UDim2.new(moneyHome.X.Scale, moneyHome.X.Offset, 0, top + hud.AbsoluteSize.Y + 7)
    end
end

local function setDetails(show)
    if view.DetailGui.Enabled == show then return end
    if show and (blocked() or not view.State) then return end
    view:SetDetails(show)
    if show then
        ContextActionService:BindActionAtPriority("MarketReputationDetails", function()
            return Enum.ContextActionResult.Sink
        end, false, 3000, Enum.KeyCode.E, Enum.KeyCode.F)
    else
        ContextActionService:UnbindAction("MarketReputationDetails")
    end
end

local function visibility()
    local hidden = blocked()
    if hidden then setDetails(false) end
    view.Gui.Enabled = not hidden
    view:ShowLevelUp()
    adjustBalance()
end

local function refresh()
    local state
    if player:GetAttribute("DataLoaded") == true then
        local raw = player:GetAttribute(stateAttribute)
        if raw then
            local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
            if ok then state = decoded end
        end
    end
    if not state then setDetails(false) end
    view:Update(state)
    adjustBalance()
end

local function watchGui(screen)
    if screen.Name == "MoneyGui" then
        local root = screen:FindFirstChild("Root")
        local window = root and root:FindFirstChild("Window")
        if window then
            moneyGui, moneyWindow, moneyHome, moneyOrder = screen, window, window.Position, screen.DisplayOrder
            moneyWindow:GetPropertyChangedSignal("AbsoluteSize"):Connect(adjustBalance)
            moneyGui:GetPropertyChangedSignal("Enabled"):Connect(adjustBalance)
            adjustBalance()
        end
    elseif screen.Name == "BuyGui" then
        shop, shopPanel = screen, screen:FindFirstChild("MainFrame")
        screen:GetPropertyChangedSignal("Enabled"):Connect(visibility)
        if shopPanel then shopPanel:GetPropertyChangedSignal("Visible"):Connect(visibility) end
        visibility()
    elseif fullScreens[screen.Name] then
        screen:GetPropertyChangedSignal("Enabled"):Connect(visibility)
        visibility()
    end
end

view.Hud.Activated:Connect(function() setDetails(true) end)
view.Backdrop.Activated:Connect(function() setDetails(false) end)
view.Close.Activated:Connect(function() setDetails(false) end)
local function relayout()
    view:Layout()
    adjustBalance()
end
view.Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(relayout)
Input:GetPropertyChangedSignal("TouchEnabled"):Connect(relayout)
view.Hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(adjustBalance)
for _, attribute in ipairs(busyAttributes) do
    player:GetAttributeChangedSignal(attribute):Connect(visibility)
end
player:GetAttributeChangedSignal(stateAttribute):Connect(refresh)
player:GetAttributeChangedSignal("DataLoaded"):Connect(refresh)
player.CharacterRemoving:Connect(function() setDetails(false) end)
Input.InputBegan:Connect(function(input, processed)
    if not processed and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Q
        or input.KeyCode == Enum.KeyCode.ButtonB) then setDetails(false) end
end)
playerGui.ChildAdded:Connect(watchGui)
for _, child in ipairs(playerGui:GetChildren()) do watchGui(child) end
refresh()
visibility()
