local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Stand = require(script.Parent.FarmStandService)
local config = require(ReplicatedStorage.Configs.FarmStandConfig)
local definitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local avatars = ReplicatedStorage.FarmModels:WaitForChild("MarketAvatars")
local random = Random.new()
local collisionGroup = "FarmStandAvatars"

if not PhysicsService:IsCollisionGroupRegistered(collisionGroup) then
    PhysicsService:RegisterCollisionGroup(collisionGroup)
end
PhysicsService:CollisionGroupSetCollidable(collisionGroup, "Default", false)
PhysicsService:CollisionGroupSetCollidable(collisionGroup, collisionGroup, false)

local Visitors = {}

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

local function prepareAvatar(template, frame, role)
    local avatar = template:Clone()
    avatar.Name = role
    avatar.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
    avatar.Humanoid.EvaluateStateMachine = false
    for _, part in ipairs(avatar:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CollisionGroup = collisionGroup
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
        end
    end
    avatar:PivotTo(frame + Vector3.yAxis * avatar:GetAttribute("StandHeight"))
    return avatar
end

local function orderMood(buyer, mood)
    if buyer:GetAttribute("MarketOrderMood") ~= mood then buyer:SetAttribute("MarketOrderMood", mood) end
end

local function orderBubble(buyer, ticket)
    local board = make("BillboardGui", buyer.Head, {Name = "OrderBubble", StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0),
        Size = UDim2.fromOffset(112, 52), LightInfluence = 0, MaxDistance = 54, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
    local card = make("CanvasGroup", board, {Name = "OrderCard", Position = UDim2.fromOffset(4, 4),
        Size = UDim2.new(1, -8, 1, -8), BorderSizePixel = 0, GroupTransparency = 1, Visible = false})
    make("UICorner", card, {CornerRadius = UDim.new(0, 12)})
    make("UIStroke", card, {Thickness = 2})
    local accent = make("Frame", card, {Name = "Accent", Position = UDim2.fromOffset(7, 9),
        Size = UDim2.new(0, 3, 1, -18), BorderSizePixel = 0})
    make("UICorner", accent, {CornerRadius = UDim.new(1, 0)})
    local icon = make("ImageLabel", card, {Position = UDim2.fromOffset(13, 5), Size = UDim2.fromOffset(32, 32),
        BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Image = definitions[ticket.Item].Icon})
    local label = make("TextLabel", card, {Position = UDim2.fromOffset(45, 0), Size = UDim2.new(0, 28, 1, 0),
        BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextSize = 18, TextColor3 = Color3.fromRGB(89, 53, 28),
        Text = "×" .. ticket.Amount})
    local face = make("Frame", card, {Name = "MoodFace", Position = UDim2.fromOffset(75, 10), Size = UDim2.fromOffset(24, 24),
        BackgroundTransparency = 1, BorderSizePixel = 0})
    make("UICorner", face, {CornerRadius = UDim.new(1, 0)})
    make("UIStroke", face, {Thickness = 1.5})
    local function mark(name, x, y, width, height)
        local part = make("Frame", face, {Name = name, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, height),
            AnchorPoint = Vector2.new(.5, .5), BorderSizePixel = 0})
        make("UICorner", part, {CornerRadius = UDim.new(1, 0)})
    end
    mark("LeftEye", 8, 8, 2.5, 3.5)
    mark("RightEye", 16, 8, 2.5, 3.5)
    mark("LeftMouth", 9.5, 16, 6, 2)
    mark("RightMouth", 14.5, 16, 6, 2)
    orderMood(buyer, "Ready")
    return {Board = board, Face = face, Icon = icon, Label = label}
end

local function paid(entry, cents)
    local sign = entry.Order
    orderMood(entry.Avatar, "Paid")
    sign.Icon.Visible, sign.Face.Visible = false, false
    sign.Label.Position, sign.Label.Size = UDim2.fromOffset(4, 0), UDim2.new(1, -8, 1, 0)
    sign.Label.Text = string.format("+$%.2f", cents / 100)
    sign.Label.TextSize = 20
    local sound = make("Sound", entry.Avatar.PrimaryPart, {SoundId = config.CoinSound, PlaybackSpeed = 1.22,
        Volume = .45, RollOffMaxDistance = 34})
    sound:Play()
    TweenService:Create(sign.Board, TweenInfo.new(.8, Enum.EasingStyle.Quad),
        {StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)}):Play()
end

local function animateRoot(entry, frame, seconds, easing)
    if not entry.Avatar.Parent then return false end
    local motion = TweenService:Create(entry.Avatar.PrimaryPart, TweenInfo.new(seconds, easing), {CFrame = frame})
    entry.Motion = motion
    motion:Play()
    local result = motion.Completed:Wait()
    entry.Motion = nil
    return result == Enum.PlaybackState.Completed and entry.Avatar.Parent ~= nil
end

local function turn(entry, face)
    local root = entry.Avatar.PrimaryPart
    local angle = math.acos(math.clamp(root.CFrame.LookVector:Dot(face), -1, 1))
    return angle < .035 or animateRoot(entry, CFrame.lookAlong(root.Position, face), angle / config.TurnSpeed, Enum.EasingStyle.Sine)
end

local function walkTo(entry, target, arrivalFace)
    local avatar = entry.Avatar
    if not avatar.Parent then return false end
    local position = target + Vector3.yAxis * avatar:GetAttribute("StandHeight")
    local delta = position - avatar.PrimaryPart.Position
    local distance = delta.Magnitude
    if distance > .05 then
        local face = delta.Unit
        if not turn(entry, face) then return false end
        entry.Walk:Play(.14, 1, config.WalkSpeed / config.WalkAnimationSpeed)
        if not animateRoot(entry, CFrame.lookAlong(position, face), distance / config.WalkSpeed, Enum.EasingStyle.Linear) then
            return false
        end
        entry.Walk:Stop(.14)
    end
    return not arrivalFace or turn(entry, arrivalFace)
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
    local anchors = model.PrimaryPart
    local beat = config.ServiceSeconds / 5
    local resetSeller = reach(seller, anchors.VendorReach.WorldPosition, beat)
    task.wait(beat)
    if not buyer.Parent then
        resetSeller()
        return
    end

    local parcel = make("Part", buyer, {Name = "ProduceParcel", Size = Vector3.new(.66, .48, .55), Anchored = true,
        Massless = true, CanCollide = false, CanQuery = false, CanTouch = false, Color = Color3.fromRGB(180, 116, 65),
        Material = Enum.Material.Wood, CFrame = CFrame.new(seller.RightHand.Position) * pivot.Rotation})
    make("Decal", parcel, {Face = Enum.NormalId.Top, Texture = definitions[entry.Ticket.Item].Icon})
    tweenTo(parcel, {CFrame = CFrame.new(anchors.ParcelCenter.WorldPosition) * pivot.Rotation}, beat)
    task.wait(beat)
    resetSeller()
    if not buyer.Parent then return end
    local resetBuyer = reach(buyer, anchors.BuyerReach.WorldPosition, beat)
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
    if cents then
        local rest = buyer.PrimaryPart.CFrame
        if animateRoot(entry, rest * CFrame.Angles(-.075, 0, 0), beat * .43, Enum.EasingStyle.Sine) then
            animateRoot(entry, rest, beat * .57, Enum.EasingStyle.Sine)
        end
    else
        task.wait(beat)
    end
    return cents ~= nil
end

local function refuse(entry)
    local avatar = entry.Avatar
    local rest = avatar.PrimaryPart.CFrame
    local seconds = config.RefusalSeconds
    local resetHand = reach(avatar, rest:PointToWorldSpace(Vector3.new(.82, .34, -.59)), seconds / 3)
    for _, yaw in ipairs({-.15, .15, 0}) do
        if not animateRoot(entry, rest * CFrame.Angles(0, yaw, -yaw * .7), seconds / 3, Enum.EasingStyle.Sine) then break end
    end
    resetHand()
end

function Visitors.Run(player, model, changed)
    local pivot = model:GetPivot()
    local anchors = model.PrimaryPart
    local service = anchors.CustomerService.WorldPosition
    local arrival = anchors.CustomerArrival.WorldPosition
    local exitCorner = anchors.CustomerExitCorner.WorldPosition
    local exitEnd = anchors.CustomerExitEnd.WorldPosition
    local side, inside = pivot.RightVector, -pivot.LookVector
    local queue, exiting = {}, {}
    local seller = prepareAvatar(avatars.Vendor, anchors.VendorPosition.WorldCFrame, "Vendor")
    seller.Parent = model
    animate(seller, config.IdleAnimation, Enum.AnimationPriority.Idle):Play(.15)
    local nextArrival = 0

    local function advanceQueue()
        for index, entry in ipairs(queue) do
            if entry.Slot == index or entry.Moving or entry.Serving then continue end
            local ahead = queue[index - 1]
            local position = entry.Avatar.PrimaryPart.Position
            if ahead and (ahead.Slot ~= index - 1 or
                (position - ahead.Avatar.PrimaryPart.Position):Dot(side) < config.QueueSpacing) then continue end

            entry.Slot, entry.Moving = index, true
            task.spawn(function()
                walkTo(entry, service + side * ((index - 1) * config.QueueSpacing), index == 1 and inside or nil)
                entry.Moving = false
            end)
        end
    end

    local function retire(entry)
        entry.Avatar:SetAttribute("MarketCardFadeAt", workspace:GetServerTimeNow() + .55)
        if not walkTo(entry, exitCorner, side) then return end
        table.remove(queue, 1)
        exiting[entry] = true
        local departureTime = (exitEnd - exitCorner).Magnitude / config.WalkSpeed
        entry.Avatar:SetAttribute("MarketFadeAt", workspace:GetServerTimeNow() + departureTime - config.FadeDuration)
        walkTo(entry, exitEnd)
        entry.Avatar:Destroy()
        exiting[entry] = nil
    end

    local function clearQueue()
        local function remove(entry)
            local motion = entry.Motion
            if motion then motion:Cancel() end
            entry.Avatar:Destroy()
        end
        for _, entry in ipairs(queue) do
            Stand.Cancel(player, entry.Ticket)
            remove(entry)
        end
        table.clear(queue)
        for entry in pairs(exiting) do remove(entry) end
        table.clear(exiting)
        if model.Parent then model:SetAttribute("MarketWaitingFor", nil) end
    end

    local function finishVisit(entry, reserved)
        entry.Serving = true
        model:SetAttribute("MarketWaitingFor", nil)
        if reserved then
            orderMood(entry.Avatar, "Ready")
            changed()
        else
            Stand.Cancel(player, entry.Ticket)
            changed("A buyer left without buying.")
        end
        task.spawn(function()
            local sold
            if reserved then
                local ok, result = pcall(handoff, seller, entry, model, function()
                    local ticket = entry.Ticket
                    local cents = Stand.Finish(player, model, ticket)
                    changed(cents and string.format("Sold %d  ·  +$%.2f", ticket.Amount, cents / 100) or nil)
                    return cents
                end)
                sold = ok and result
                if not ok then
                    warn("Farm stand handoff failed:", result)
                    Stand.Cancel(player, entry.Ticket)
                    changed()
                end
            end
            if not entry.Avatar.Parent or queue[1] ~= entry then return end
            if not sold then
                orderMood(entry.Avatar, "Late")
                refuse(entry)
            end
            if entry.Avatar.Parent and queue[1] == entry then retire(entry) end
        end)
    end

    local function serveFront(front)
        local now = os.clock()
        local waited = front.WaitStarted and now - front.WaitStarted or 0
        if waited >= config.Patience then
            finishVisit(front, false)
        elseif Stand.TryReserve(player, model, front.Ticket) then
            finishVisit(front, true)
        else
            if not front.WaitStarted then
                front.WaitStarted = now
                local ticket = front.Ticket
                model:SetAttribute("MarketWaitingFor", string.format("Waiting for %d × %s", ticket.Amount, definitions[ticket.Item].DisplayName))
                changed()
            end
            orderMood(front.Avatar, waited >= config.WaitLate and "Late" or waited >= config.WaitWarning and "Waiting" or "Ready")
        end
    end

    while model.Parent and player.Parent do
        if Stand.IsOpen(player, model) then
            advanceQueue()
            local front = queue[1]
            if front and front.Slot == 1 and not front.Serving and not front.Moving then
                serveFront(front)
            end
            local active = #queue
            for _ in pairs(exiting) do active += 1 end
            local last = queue[#queue]
            local room = not last or (arrival - last.Avatar.PrimaryPart.Position):Dot(side) >= config.QueueSpacing
            if room and #queue < config.QueueLimit and active < config.QueueLimit + 1 and os.clock() >= nextArrival then
                local ticket = Stand.CreateOrder(player, model)
                nextArrival = os.clock() + (ticket and Stand.VisitDelay(player) or config.PausedVisitRetry)
                if ticket then
                    local template = random:NextInteger(1, 2) == 1 and avatars.Visitor1 or avatars.Visitor2
                    local avatar = prepareAvatar(template, CFrame.lookAlong(arrival, -side), "Buyer")
                    local order = orderBubble(avatar, ticket)
                    avatar:SetAttribute("MarketArrivalAt", workspace:GetServerTimeNow())
                    avatar.Parent = model
                    animate(avatar, config.IdleAnimation, Enum.AnimationPriority.Idle):Play(.15)
                    local entry = {Avatar = avatar, Ticket = ticket, Order = order,
                        Walk = animate(avatar, config.WalkAnimation, Enum.AnimationPriority.Movement)}
                    table.insert(queue, entry)
                    advanceQueue()
                end
            end
        elseif #queue > 0 or next(exiting) then
            clearQueue()
            changed()
        end
        task.wait(.1)
    end
    clearQueue()
    seller:Destroy()
end

return Visitors
