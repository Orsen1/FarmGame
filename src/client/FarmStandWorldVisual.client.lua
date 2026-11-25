local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local config = require(ReplicatedStorage.Configs.FarmStandConfig)
local plots = workspace:WaitForChild("Plots")
local stands = setmetatable({}, {__mode = "k"})
local buyers = {}

local function fade(at, from, to, apply)
    if not at then return end
    local function start()
        local progress = math.clamp((workspace:GetServerTimeNow() - at) / config.FadeDuration, 0, 1)
        local initial = from + (to - from) * progress
        apply(initial)
        if progress == 1 then return end
        local alpha = Instance.new("NumberValue")
        alpha.Value = initial
        alpha.Changed:Connect(apply)
        local tween = TweenService:Create(alpha, TweenInfo.new(config.FadeDuration * (1 - progress)), {Value = to})
        tween.Completed:Once(function() alpha:Destroy() end)
        tween:Play()
    end
    local delay = at - workspace:GetServerTimeNow()
    if delay > 0 then task.delay(delay, start) else start() end
end

local function watchBuyer(buyer)
    if buyer.Name ~= "Buyer" or not buyer:IsA("Model") or buyers[buyer] then return end
    local card = buyer:FindFirstChild("OrderCard", true)
    if not card then return end
    local edge = card:FindFirstChildOfClass("UIStroke")
    local stand = buyer.Parent
    local connections = {}
    buyers[buyer] = connections

    local function fadeBody(at, from, to)
        local parts = {}
        for _, part in ipairs(buyer:GetDescendants()) do
            if part:IsA("BasePart") then table.insert(parts, part) end
        end
        fade(at, from, to, function(alpha)
            if buyers[buyer] ~= connections then return end
            for _, part in ipairs(parts) do part.LocalTransparencyModifier = alpha end
        end)
    end
    local function order(alpha)
        if buyers[buyer] ~= connections then return end
        card.GroupTransparency = alpha
        card.Visible = alpha < 1
        edge.Transparency = alpha
    end
    local function leave() fadeBody(buyer:GetAttribute("MarketFadeAt"), 0, 1) end
    local function closeCard() fade(buyer:GetAttribute("MarketCardFadeAt"), 0, 1, order) end

    if buyer:GetAttribute("MarketFadeAt") then leave() else fadeBody(buyer:GetAttribute("MarketArrivalAt"), 1, 0) end
    if buyer:GetAttribute("MarketCardFadeAt") then closeCard() else fade(buyer:GetAttribute("MarketArrivalAt"), 1, 0, order) end

    table.insert(connections, buyer:GetAttributeChangedSignal("MarketFadeAt"):Connect(leave))
    table.insert(connections, buyer:GetAttributeChangedSignal("MarketCardFadeAt"):Connect(closeCard))
    table.insert(connections, buyer.AncestryChanged:Connect(function()
        if buyer.Parent == stand and buyer:IsDescendantOf(plots) then return end
        for _, connection in ipairs(connections) do connection:Disconnect() end
        buyers[buyer] = nil
    end))
end

local function watchStand(stand)
    if stand.Name ~= "FarmStand" or not stand:IsA("Model") or stands[stand] then return end
    stands[stand] = true
    stand.ChildAdded:Connect(watchBuyer)
    for _, buyer in ipairs(stand:GetChildren()) do watchBuyer(buyer) end
end

for _, plot in ipairs(plots:GetChildren()) do
    plot.ChildAdded:Connect(watchStand)
    local stand = plot:FindFirstChild("FarmStand")
    if stand then watchStand(stand) end
end
