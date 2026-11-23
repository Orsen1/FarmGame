local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Stand = require(script.Parent.FarmStandService)
local config = require(ReplicatedStorage.Configs.FarmStandConfig)
local definitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local avatars = ReplicatedStorage.FarmModels:WaitForChild("MarketAvatars")
local random = Random.new()

local Visitors = {}
local approach = -3.6
local departure = -6.8
local spawnDistance = 18

local function make(class, parent, properties)
    local object = Instance.new(class)
    for name, value in pairs(properties) do object[name] = value end
    object.Parent = parent
    return object
end

local function animate(avatar, asset, priority)
    local animation = Instance.new("Animation")
    animation.AnimationId = asset
    animation.Parent = avatar
    local humanoid = avatar:FindFirstChildOfClass("Humanoid")
    local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
    local track = animator:LoadAnimation(animation)
    track.Priority = priority
    track.Looped = true
    return track
end

local function spawn(template, model, frame, role)
    local avatar = template:Clone()
    avatar.Name = role
    avatar:PivotTo(frame + Vector3.yAxis * avatar:GetAttribute("StandHeight"))
    avatar.Parent = model
    local idle = animate(avatar, config.IdleAnimation, Enum.AnimationPriority.Idle)
    idle:Play(.15)
    return avatar, idle
end

local function orderBubble(buyer, ticket)
    local board = make("BillboardGui", buyer.Head, {Name = "OrderBubble", StudsOffsetWorldSpace = Vector3.new(0, 1.05, 0),
        Size = UDim2.fromOffset(100, 42), AlwaysOnTop = true, MaxDistance = 64})
    local bubble = make("Frame", board, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 229, 166),
        BorderSizePixel = 0})
    make("UICorner", bubble, {CornerRadius = UDim.new(0, 12)})
    make("UIStroke", bubble, {Color = Color3.fromRGB(150, 92, 45), Thickness = 2})
    local icon = make("ImageLabel", bubble, {Position = UDim2.fromOffset(5, 3), Size = UDim2.fromOffset(40, 36),
        BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Image = definitions[ticket.Item].Icon})
    local label = make("TextLabel", bubble, {Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -50, 1, 0),
        BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextSize = 21, TextColor3 = Color3.fromRGB(113, 67, 32),
        Text = "×" .. ticket.Amount})
    return {Board = board, Bubble = bubble, Icon = icon, Label = label}
end

local function paid(entry, cents)
    local sign = entry.Order
    sign.Bubble.BackgroundColor3 = Color3.fromRGB(251, 207, 103)
    sign.Icon.Visible = false
    sign.Label.Position, sign.Label.Size = UDim2.fromOffset(4, 0), UDim2.new(1, -8, 1, 0)
    sign.Label.Text = string.format("+$%.2f", cents / 100)
    sign.Label.TextScaled = true
    make("UITextSizeConstraint", sign.Label, {MaxTextSize = 22})
    local sound = make("Sound", entry.Avatar.PrimaryPart, {SoundId = config.CoinSound, PlaybackSpeed = 1.22,
        Volume = .45, RollOffMaxDistance = 34})
    sound:Play()
    TweenService:Create(sign.Board, TweenInfo.new(.8, Enum.EasingStyle.Quad),
        {StudsOffsetWorldSpace = Vector3.new(0, 1.95, 0)}):Play()
end

local function move(entry, target, face)
    local avatar = entry.Avatar
    local root = avatar.PrimaryPart
    if entry.Motion then
        local old = entry.Motion
        entry.Motion = nil
        old:Cancel()
    end
    local position = target + Vector3.yAxis * avatar:GetAttribute("StandHeight")
    local delta = position - root.Position
    if delta.Magnitude < .05 then
        root.CFrame = CFrame.lookAlong(position, face)
        entry.Walk:Stop(.15)
        return
    end
    root.CFrame = CFrame.lookAlong(root.Position, delta)
    if not entry.Walk.IsPlaying then entry.Walk:Play(.15, 1, .65) end
    local motion = TweenService:Create(root, TweenInfo.new(delta.Magnitude / config.WalkSpeed, Enum.EasingStyle.Linear),
        {CFrame = CFrame.lookAlong(position, delta)})
    entry.Motion = motion
    motion.Completed:Once(function()
        if entry.Motion ~= motion then return end
        entry.Motion = nil
        if not avatar.Parent then return end
        root.CFrame = CFrame.lookAlong(position, face)
        entry.Walk:Stop(.15)
    end)
    motion:Play()
    return motion
end

local function tweenTo(object, target, time)
    local tween = TweenService:Create(object, TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), target)
    tween:Play()
end

local function reach(avatar, position, time)
    local target = make("Attachment", avatar.PrimaryPart, {Name = "HandoffTarget"})
    target.WorldPosition = position
    local ik = make("IKControl", avatar.Humanoid, {Name = "Handoff", Type = Enum.IKControlType.Position,
        ChainRoot = avatar.RightUpperArm, EndEffector = avatar.RightHand, Target = target, Weight = 0, SmoothTime = .08})
    tweenTo(ik, {Weight = 1}, time)
    return function()
        if ik.Parent then tweenTo(ik, {Weight = 0}, time) end
        task.delay(time, function() ik:Destroy();target:Destroy() end)
    end
end

local function handoff(seller, entry, model, finish)
    local buyer = entry.Avatar
    local pivot = model:GetPivot()
    local beat = config.ServiceSeconds / 5
    local resetSeller = reach(seller, (pivot * CFrame.new(.65, 3.26, 1.1)).Position, beat)
    task.wait(beat)
    if not buyer.Parent then
        resetSeller()
        return
    end

    local parcel = make("Part", buyer, {Name = "ProduceParcel", Size = Vector3.new(.66, .48, .55), Anchored = true,
        Massless = true, CanCollide = false, CanQuery = false, CanTouch = false, Color = Color3.fromRGB(180, 116, 65),
        Material = Enum.Material.Wood, CFrame = CFrame.new(seller.RightHand.Position) * pivot.Rotation})
    make("Decal", parcel, {Face = Enum.NormalId.Top, Texture = definitions[entry.Ticket.Item].Icon})
    tweenTo(parcel, {CFrame = pivot * CFrame.new(0, 3.44, -.35)}, beat)
    task.wait(beat)
    resetSeller()
    if not buyer.Parent then return end
    local resetBuyer = reach(buyer, (pivot * CFrame.new(-.6, 3.24, -1.25)).Position, beat)
    task.wait(beat)
    if not buyer.Parent then return end
    tweenTo(parcel, {CFrame = CFrame.new(buyer.RightHand.Position) * pivot.Rotation}, beat)
    task.wait(beat)
    if not buyer.Parent then return end

    local cents = finish()
    if cents then
        make("WeldConstraint", parcel, {Part0 = buyer.RightHand, Part1 = parcel})
        parcel.Anchored = false
        paid(entry, cents)
    else
        parcel:Destroy()
    end
    resetBuyer()
    task.wait(beat)
end

function Visitors.Run(player, model, changed)
    local pivot = model:GetPivot()
    local queue, exiting = {}, {}
    local seller = spawn(avatars.Vendor, model, pivot * CFrame.new(0, 0, 2.95), "Vendor")
    local nextArrival = 0

    local function slot(entry, index)
        local at = (pivot * CFrame.new((index - 1) * config.QueueSpacing, 0, index == 1 and -3.15 or approach)).Position
        move(entry, at, index == 1 and -pivot.LookVector or -pivot.RightVector)
    end

    local function retire(entry)
        exiting[entry] = true
        task.spawn(function()
            local across = move(entry, (pivot * CFrame.new(0, 0, departure)).Position, pivot.RightVector)
            if across then across.Completed:Wait() end
            if entry.Avatar.Parent then
                local away = move(entry, (pivot * CFrame.new(spawnDistance, 0, departure)).Position, pivot.RightVector)
                if away then away.Completed:Wait() end
                entry.Avatar:Destroy()
            end
            exiting[entry] = nil
        end)
    end

    local function clearQueue()
        local function remove(entry)
            local motion = entry.Motion
            entry.Motion = nil
            entry.Avatar:Destroy()
            if motion then motion:Cancel() end
        end
        for _, entry in ipairs(queue) do
            Stand.Cancel(player, entry.Ticket)
            remove(entry)
        end
        table.clear(queue)
        for entry in pairs(exiting) do remove(entry) end
        table.clear(exiting)
    end

    while model.Parent and player.Parent do
        if Stand.IsOpen(player, model) then
            local front = queue[1]
            if front and front.Served then
                table.remove(queue, 1)
                retire(front)
                for index, entry in ipairs(queue) do slot(entry, index) end
            elseif front and not front.Serving and not front.Motion then
                front.Serving = true
                task.spawn(function()
                    local ok, reason = pcall(handoff, seller, front, model, function()
                        local cents = Stand.Finish(player, model, front.Ticket)
                        changed(cents and string.format("Sold %d  ·  +$%.2f", front.Ticket.Amount, cents / 100) or nil)
                        return cents
                    end)
                    if not ok then
                        warn("Farm stand handoff failed:", reason)
                        Stand.Cancel(player, front.Ticket)
                        changed()
                    end
                    front.Served = true
                end)
            end
            local active = #queue
            for _ in pairs(exiting) do active += 1 end
            if #queue < config.QueueLimit and active < config.QueueLimit + 1 and os.clock() >= nextArrival then
                nextArrival = os.clock() + random:NextNumber(config.VisitInterval[1], config.VisitInterval[2])
                local ticket = Stand.Reserve(player, model)
                if ticket then
                    local at = pivot * CFrame.new(spawnDistance, 0, approach) * CFrame.Angles(0, math.pi / 2, 0)
                    local template = random:NextInteger(1, 2) == 1 and avatars.Visitor1 or avatars.Visitor2
                    local avatar = spawn(template, model, at, "Buyer")
                    local entry = {Avatar = avatar, Ticket = ticket, Order = orderBubble(avatar, ticket),
                        Walk = animate(avatar, config.WalkAnimation, Enum.AnimationPriority.Movement)}
                    table.insert(queue, entry)
                    slot(entry, #queue)
                    changed()
                end
            end
        elseif #queue > 0 or next(exiting) then
            clearQueue()
            changed()
        end
        task.wait(.1)
    end
    clearQueue()
end

return Visitors
