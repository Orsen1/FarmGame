local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local config = require(ReplicatedStorage.Configs.PlotSectionConfig)
local MoneyService = require(script.Parent.MoneyService)
local PlotSectionService = {}
local bound = {}

local function open(sections, name)
    if name == "Starter" then
        return true
    end
    return sections[name]:GetAttribute("Unlocked") == true
end

local function availableSection(plot, border)
    local first, second = string.match(border.Name, "^(%w+)_(%w+)$")
    local sections = plot.Sections
    local firstOpen, secondOpen = open(sections, first), open(sections, second)
    if firstOpen ~= secondOpen then
        return sections[firstOpen and second or first]
    end
end

function PlotSectionService.getData(plot)
    local purchased = {}
    local sections = plot:FindFirstChild("Sections")
    if sections then
        for _, id in ipairs(config.SectionIds) do
            if sections[id]:GetAttribute("Unlocked") == true then
                table.insert(purchased, id)
            end
        end
    end
    return purchased
end

local function currentPrice(plot)
    return config.PricesCents[#PlotSectionService.getData(plot) + 1]
end

local function refreshBorders(plot)
    local price = currentPrice(plot)
    local priceText = price and string.format("$%.2f", price / 100)
    local owned = plot:GetAttribute("OwnerUserId") ~= 0
    for _, border in ipairs(plot.SectionBorders:GetChildren()) do
        local first, second = string.match(border.Name, "^(%w+)_(%w+)$")
        local hidden = open(plot.Sections, first) and open(plot.Sections, second)
        local target = availableSection(plot, border)
        for _, part in ipairs(border:GetChildren()) do
            if part:IsA("BasePart") then
                part.Transparency = hidden and 1 or 0
                part.CanCollide = not hidden and part.Name ~= "Sign"
                part.CanQuery = part.CanCollide
            end
        end

        local sign = border.Sign
        for _, face in ipairs(sign:GetChildren()) do
            if face:IsA("SurfaceGui") then
                face.Enabled = not hidden
                face.Price.Text = target and priceText or "Expand next door"
            end
        end
        local prompt = sign.BuySectionPrompt
        prompt:SetAttribute("PriceCents", target and owned and price or nil)
        prompt.Enabled = target ~= nil and owned
    end
end

local function buy(player, plot, border, prompt)
    if player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true
        or player:GetAttribute("Teleporting") == true or player:GetAttribute("PlotName") ~= plot.Name
        or plot:GetAttribute("OwnerUserId") ~= player.UserId or not prompt.Enabled then
        return
    end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0
        or (root.Position - border.Sign.Position).Magnitude > prompt.MaxActivationDistance then
        return
    end
    local section = availableSection(plot, border)
    local price = section and currentPrice(plot)
    if price and MoneyService.RemoveMoney(player, price) then
        section:SetAttribute("Unlocked", true)
        section.Ground.Color = plot.Ground.Color
        refreshBorders(plot)
    end
end

function PlotSectionService.loadData(plot, purchased)
    local sections = plot:FindFirstChild("Sections")
    local borders = plot:FindFirstChild("SectionBorders")
    if not sections or not borders then
        return false, "Plot expansion layout is missing"
    end
    if purchased ~= nil and typeof(purchased) ~= "table" then
        return false, "Invalid plot expansion data"
    end

    local unlocked = {}
    for _, id in ipairs(purchased or {}) do
        if not table.find(config.SectionIds, id) then
            return false, "Invalid plot section ID"
        end
        unlocked[id] = true
    end
    for _, id in ipairs(config.SectionIds) do
        local section = sections[id]
        section:SetAttribute("Unlocked", unlocked[id] == true)
        section.Ground.Color = unlocked[id] and plot.Ground.Color or config.LockedColor
    end

    if not bound[plot] then
        bound[plot] = true
        for _, border in ipairs(borders:GetChildren()) do
            local prompt = border.Sign.BuySectionPrompt
            prompt.Triggered:Connect(function(player)
                buy(player, plot, border, prompt)
            end)
        end
    end
    refreshBorders(plot)
    return true
end

return PlotSectionService
