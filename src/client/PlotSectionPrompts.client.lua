local Players = game:GetService("Players")

local player = Players.LocalPlayer
local plots = workspace:WaitForChild("Plots")
local money = player:WaitForChild("PlayerData"):WaitForChild("MoneyCents")
local tracked = {}

local function refresh(prompt, plot)
    local price = prompt:GetAttribute("PriceCents")
    local visible = price ~= nil and player:GetAttribute("PlotName") == plot.Name
        and plot:GetAttribute("OwnerUserId") == player.UserId and player:GetAttribute("DataLoaded") == true
        and not player:GetAttribute("ProductionMode") and not player:GetAttribute("StorageOpen")
    if prompt.Enabled ~= visible then
        prompt.Enabled = visible
    end
    if visible then
        local verb = money.Value >= price and "Buy for " or "Need "
        prompt.ActionText = verb .. string.format("$%.2f", price / 100)
    end
end

local function track(object)
    if not object:IsA("ProximityPrompt") or object.Name ~= "BuySectionPrompt" or tracked[object] then
        return
    end
    local borders = object:FindFirstAncestor("SectionBorders")
    local plot = borders and borders.Parent
    if not plot then
        return
    end
    local function update()
        refresh(object, plot)
    end
    tracked[object] = {
        Update = update,
        Enabled = object:GetPropertyChangedSignal("Enabled"):Connect(update),
        Price = object:GetAttributeChangedSignal("PriceCents"):Connect(update),
    }
    update()
end

local function refreshAll()
    for _, entry in pairs(tracked) do
        entry.Update()
    end
end

plots.DescendantAdded:Connect(track)
plots.DescendantRemoving:Connect(function(object)
    local entry = tracked[object]
    if entry then
        entry.Enabled:Disconnect()
        entry.Price:Disconnect()
        tracked[object] = nil
    end
end)
for _, object in ipairs(plots:GetDescendants()) do
    track(object)
end
for _, attribute in ipairs({ "PlotName", "DataLoaded", "ProductionMode", "StorageOpen" }) do
    player:GetAttributeChangedSignal(attribute):Connect(refreshAll)
end
money.Changed:Connect(refreshAll)
