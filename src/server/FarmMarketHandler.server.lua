local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Orders = require(script.Parent.OrderService)
local items = require(ReplicatedStorage.Configs.ItemDefinitions)
local templates = ReplicatedStorage:WaitForChild("FarmModels")
local wagonTemplate = templates:WaitForChild("MarketWagon")
local standTemplate = templates:WaitForChild("FarmStand")
local sell = ReplicatedStorage.RemoteEvents:WaitForChild("OpenSellGuiEvent")
local plots = workspace:WaitForChild("Plots")

local function caption(parent, text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.FredokaOne
    label.TextColor3 = Color3.fromRGB(255, 239, 192)
    label.TextStrokeColor3 = Color3.fromRGB(74, 48, 31)
    label.TextStrokeTransparency = 0.25
    label.TextScaled = true
    label.Text = text
    label.Parent = parent
    return label
end

local function addSign(stand, name)
    for _, side in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
        local face = Instance.new("SurfaceGui")
        face.Name = "StandSign"
        face.Face = side
        face.CanvasSize = Vector2.new(760, 102)
        face.LightInfluence = 0.15
        face.Parent = stand.Nameboard
        local label = caption(face, name .. "'s Farm Stand")
        label.Position = UDim2.fromScale(0.04, 0.04)
        label.Size = UDim2.fromScale(0.92, 0.92)
    end
end

local function showCargo(wagon, order)
    local visible = math.floor(5 * order.Delivered / order.Goal)
    for i = 1, 5 do
        local parcel = wagon["Parcel" .. i]
        parcel.Transparency = i <= visible and 0 or 1
        local sticker = parcel:FindFirstChild("Contents")
        if not sticker then
            sticker = Instance.new("Decal")
            sticker.Name = "Contents"
            sticker.Face = Enum.NormalId.Top
            sticker.Texture = items[order.Crop].Icon
            sticker.Parent = parcel
        end
        sticker.Transparency = parcel.Transparency
    end
    wagon:SetAttribute("Delivered", order.Delivered)
end

local function promptFor(model, action, context, icon, callback)
    local target = Instance.new("Attachment")
    target.Name = "MarketAttachment"
    target.Position = Vector3.new(1.8, 2.5, -1.5)
    target.Parent = model.PrimaryPart
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "MarketPrompt"
    prompt.ActionText = action
    prompt.ObjectText = context
    prompt.Style = Enum.ProximityPromptStyle.Custom
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 8
    prompt:SetAttribute("Context", context)
    prompt:SetAttribute("Icon", icon)
    prompt.Triggered:Connect(callback)
    prompt.Parent = target
    return prompt
end

local function roll(model, first, last)
    local start = os.clock()
    while model.Parent do
        local t = math.min(1, (os.clock() - start) / 1.35)
        model:PivotTo(first:Lerp(last, TweenService:GetValue(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)))
        if t == 1 then return true end
        task.wait(0.05)
    end
    return false
end

local function setup(player)
    if not player:GetAttribute("DataLoaded") or player:GetAttribute("Teleporting") then return end
    local plot = plots:FindFirstChild(player:GetAttribute("PlotName") or "")
    if not plot or plot:GetAttribute("OwnerUserId") ~= player.UserId or plot:FindFirstChild("FarmMarket") then return end
    local order = Orders.FirstDelivery(player)
    if not order then return end
    local ground = plot.Ground
    local parking = ground.CFrame * CFrame.new(12, -ground.Size.Y / 2, ground.Size.Z / 2 + 6)
    local approach = parking * CFrame.new(13, 0, 0)
    local finished = order.Delivered == order.Goal
    local model = (finished and standTemplate or wagonTemplate):Clone()
    model.Name = "FarmMarket"
    model:SetAttribute("MarketKind", finished and "Stand" or "Wagon")
    model:SetAttribute("OwnerUserId", player.UserId)
    model:PivotTo(finished and parking or approach)
    if finished then
        addSign(model, player.DisplayName)
        promptFor(model, "Sell produce", "Your farm stand", items[order.Crop].Icon, function(visitor)
            if visitor == player and Orders.CanUseMarket(visitor, model) then sell:FireClient(visitor) end
        end)
        model.Parent = plot
        return
    end

    local crop = items[order.Crop]
    local function progress()
        return string.format("%s   %d / %d", crop.DisplayName, order.Delivered, order.Goal)
    end
    local board = Instance.new("BillboardGui")
    board.Name = "DeliveryBoard"
    board.Adornee = model.PrimaryPart
    board.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
    board.Size = UDim2.fromOffset(184, 46)
    board.MaxDistance = 52
    board.Parent = model.PrimaryPart
    local label = caption(board, "Mara's delivery\n" .. progress())
    model:SetAttribute("MarketCrop", order.Crop)
    showCargo(model, order)
    model.Parent = plot
    if not roll(model, approach, parking) then return end
    local prompt
    prompt = promptFor(model, "Load wagon", progress(), crop.Icon, function(visitor)
        if visitor ~= player or not model.Parent or order.Delivered >= order.Goal then return end
        if not Orders.LoadWagon(visitor, model) then
            if Orders.CanUseMarket(visitor, model) then
                prompt:SetAttribute("Context", "Bring " .. crop.DisplayName)
            end
            return
        end
        showCargo(model, order)
        label.Text = "Mara's delivery\n" .. progress()
        prompt:SetAttribute("Context", progress())
        if order.Delivered < order.Goal then return end
        prompt:Destroy()
        label.Text = "Thank you!\nFarm stand unlocked"
        task.wait(0.85)
        if roll(model, parking, parking * CFrame.new(-12, 0, 0)) then
            model:Destroy()
            setup(player)
        end
    end)
end

local function watch(player)
    for _, key in ipairs({"DataLoaded", "TutorialStep", "PlotName"}) do
        player:GetAttributeChangedSignal(key):Connect(function() setup(player) end)
    end
    task.defer(setup, player)
end

Players.PlayerAdded:Connect(watch)
for _, player in ipairs(Players:GetPlayers()) do watch(player) end
