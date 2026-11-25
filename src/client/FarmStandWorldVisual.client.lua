local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local config = require(ReplicatedStorage.Configs.FarmStandConfig)
local plots = workspace:WaitForChild("Plots")
local watchedPlots = setmetatable({}, {__mode = "k"})
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
    if buyer.Name ~= "Buyer" or not buyer:IsA("Model") or buyers[buyer] or not buyer:IsDescendantOf(plots) then return end
    local card = buyer:FindFirstChild("OrderCard", true)
    if not card then return end
    local edge = card:FindFirstChildOfClass("UIStroke")
    local face = card:FindFirstChild("MoodFace")
    if not edge or not face or not face:FindFirstChild("RightMouth") then return end
    local faceEdge = face:FindFirstChildOfClass("UIStroke")
    local moodTweens = {}
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
        faceEdge.Transparency = alpha
    end
    local function leave() fadeBody(buyer:GetAttribute("MarketFadeAt"), 0, 1) end
    local function closeCard() fade(buyer:GetAttribute("MarketCardFadeAt"), 0, 1, order) end

    local function mood(animated)
        for _, tween in ipairs(moodTweens) do tween:Cancel() end
        table.clear(moodTweens)
        local palette = config.OrderColors[buyer:GetAttribute("MarketOrderMood")] or config.OrderColors.Ready
        local function paint(object, properties)
            if not animated then
                for property, value in pairs(properties) do object[property] = value end
                return
            end
            local tween = TweenService:Create(object, TweenInfo.new(config.MoodTweenDuration), properties)
            table.insert(moodTweens, tween)
            tween:Play()
        end
        paint(card, {BackgroundColor3 = palette.Background})
        paint(edge, {Color = palette.Accent})
        paint(card.Accent, {BackgroundColor3 = palette.Accent})
        if palette.MouthTilt == nil then return end
        paint(faceEdge, {Color = palette.Accent})
        paint(face.LeftEye, {BackgroundColor3 = palette.Accent})
        paint(face.RightEye, {BackgroundColor3 = palette.Accent})
        paint(face.LeftMouth, {BackgroundColor3 = palette.Accent, Rotation = palette.MouthTilt})
        paint(face.RightMouth, {BackgroundColor3 = palette.Accent, Rotation = -palette.MouthTilt})
    end

    mood(false)
    if buyer:GetAttribute("MarketFadeAt") then leave() else fadeBody(buyer:GetAttribute("MarketArrivalAt"), 1, 0) end
    if buyer:GetAttribute("MarketCardFadeAt") then closeCard() else fade(buyer:GetAttribute("MarketArrivalAt"), 1, 0, order) end

    table.insert(connections, buyer:GetAttributeChangedSignal("MarketFadeAt"):Connect(leave))
    table.insert(connections, buyer:GetAttributeChangedSignal("MarketCardFadeAt"):Connect(closeCard))
    table.insert(connections, buyer:GetAttributeChangedSignal("MarketOrderMood"):Connect(function() mood(true) end))
    table.insert(connections, buyer.AncestryChanged:Connect(function()
        if buyer.Parent == stand and buyer:IsDescendantOf(plots) then return end
        for _, connection in ipairs(connections) do connection:Disconnect() end
        for _, tween in ipairs(moodTweens) do tween:Cancel() end
        buyers[buyer] = nil
    end))
end

local function watchStand(stand)
    if stand.Name ~= "FarmStand" or not stand:IsA("Model") or stands[stand] then return end
    stands[stand] = true
    stand.ChildAdded:Connect(function(buyer) task.defer(watchBuyer, buyer) end)
    stand.DescendantAdded:Connect(function(descendant)
        if descendant.Name == "OrderCard" or descendant.Name == "RightMouth" then
            local buyer = descendant:FindFirstAncestorOfClass("Model")
            if buyer then task.defer(watchBuyer, buyer) end
        end
    end)
    for _, buyer in ipairs(stand:GetChildren()) do watchBuyer(buyer) end
end

local function watchPlot(plot)
    if not plot:IsA("Model") or watchedPlots[plot] then return end
    watchedPlots[plot] = true
    plot.ChildAdded:Connect(watchStand)
    local stand = plot:FindFirstChild("FarmStand")
    if stand then watchStand(stand) end
end

plots.ChildAdded:Connect(watchPlot)
for _, plot in ipairs(plots:GetChildren()) do watchPlot(plot) end
