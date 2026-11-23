local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Stand = require(script.Parent.FarmStandService)
local Visitors = require(script.Parent.FarmStandVisitors)
local config = require(ReplicatedStorage.Configs.FarmStandConfig)
local definitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local templates = ReplicatedStorage:WaitForChild("FarmModels")
local event = ReplicatedStorage.RemoteEvents:WaitForChild("FarmStandEvent")
local plots = workspace:WaitForChild("Plots")
local opened = {}

local function make(class, parent, properties)
    local object = Instance.new(class)
    for name, value in pairs(properties) do object[name] = value end
    object.Parent = parent
    return object
end

local function addSign(model, displayName)
    for _, side in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
        local face = make("SurfaceGui", model.Nameboard, {Name = "StandSign", Face = side, CanvasSize = Vector2.new(760, 102), LightInfluence = 0.15})
        make("TextLabel", face, {Size = UDim2.fromScale(.92, .92), Position = UDim2.fromScale(.04, .04),
            BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextSize = 80, TextScaled = true,
            TextColor3 = Color3.fromRGB(255, 239, 192), Text = displayName .. "'s Farm Stand"})
    end
end

local function update(player, model, message)
    if opened[player] ~= model then return end
    if not Stand.CanReach(player, model) then
        opened[player] = nil
        if player.Parent == Players then event:FireClient(player, "Close") end
        return
    end
    event:FireClient(player, "Update", Stand.Snapshot(player), message)
end

local function setup(player)
    if not player:GetAttribute("DataLoaded") then return end
    local plot = plots:FindFirstChild(player:GetAttribute("PlotName") or "")
    if not plot or plot:GetAttribute("OwnerUserId") ~= player.UserId or plot:FindFirstChild("FarmStand") then return end
    local ground = plot.Ground
    local model = templates.FarmStand:Clone()
    model.Name = "FarmStand"
    model:SetAttribute("OwnerUserId", player.UserId)
    model:PivotTo(ground.CFrame * CFrame.new(12, -ground.Size.Y / 2, ground.Size.Z / 2 + 8.5))
    addSign(model, player.DisplayName)
    local anchor = make("Attachment", model.PrimaryPart, {Name = "StandAttachment", Position = Vector3.new(2.8, 2.7, -1.4)})
    local prompt = make("ProximityPrompt", anchor, {Name = "FarmStandPrompt", Style = Enum.ProximityPromptStyle.Custom,
        MaxActivationDistance = config.PromptDistance, RequiresLineOfSight = false, ActionText = "Stock your stand", ObjectText = "Farm stand"})
    prompt:SetAttribute("Context", "Farm stand")
    prompt:SetAttribute("Icon", definitions.Carrot.Icon)
    prompt.Triggered:Connect(function(visitor)
        if visitor ~= player or not Stand.CanReach(visitor, model) then return end
        opened[player] = model
        event:FireClient(player, "Open", Stand.Snapshot(player), model)
    end)
    model.Parent = plot
    Visitors.Run(player, model, function(message) update(player, model, message) end)
end

event.OnServerEvent:Connect(function(player, action, item, amount)
    local model = opened[player]
    if action == "Close" then opened[player] = nil;return end
    if not model or action ~= "Stock" and action ~= "Return" then return end
    local _, message = Stand.Transfer(player, model, action, item, amount)
    update(player, model, message)
end)

local function watch(player)
    player:GetAttributeChangedSignal("DataLoaded"):Connect(function() setup(player) end)
    task.defer(setup, player)
end

Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(player) opened[player] = nil end)
for _, player in ipairs(Players:GetPlayers()) do watch(player) end
