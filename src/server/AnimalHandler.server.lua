local RunService = game:GetService("RunService")
local AnimalService = require(script.Parent.AnimalService)
local Config = require(game.ReplicatedStorage.Configs.AnimalConfig)
local Definitions = require(game.ReplicatedStorage.Configs.ItemDefinitions)
local CoopUpgradeService = require(script.Parent.CoopUpgradeService)
local plots = workspace:WaitForChild("Plots")

for _, plot in ipairs(plots:GetChildren()) do
    local objects = plot:WaitForChild("PlacedObjects")
    objects.ChildAdded:Connect(AnimalService.Bind)
    for _, object in ipairs(objects:GetChildren()) do AnimalService.Bind(object) end
end

local elapsed = 0
local milkEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("MilkingEvent")
milkEvent.OnServerEvent:Connect(function(player, action, animal)
    if action == "Cancel" then
        AnimalService.CancelMilking(player)
    elseif action == "Start" then
        local success, message = AnimalService.StartMilking(player, animal)
        if not success then milkEvent:FireClient(player, "Rejected", message) end
    end
end)
local lastCommand = {}
game.Players.PlayerRemoving:Connect(function(player) lastCommand[player] = nil end)

game.ReplicatedStorage.RemoteEvents.AnimalCommand.OnServerEvent:Connect(function(player, object, action, amount)
    if typeof(object) ~= "Instance" or not object:IsA("Model") then return end
    local feedback = game.ReplicatedStorage.RemoteEvents.AnimalFeedback
    if typeof(action) == "number" or action == "Max" then
        local success, message = AnimalService.DepositFeed(player, object, action)
        feedback:FireClient(player, object, success, message, "FeedPrompt")
        return
    end
    if action ~= "Feed" and action ~= "Collect" and action ~= "Add" and action ~= "Shop" and
        action ~= "Upgrade" and action ~= "UpgradeShop" then return end
    local now = os.clock()
    if now - (lastCommand[player] or -math.huge) < 0.12 then
        feedback:FireClient(player, object, false, "Please wait a moment.", "HomeMenu")
        return
    end
    lastCommand[player] = now
    local allowed, reason = AnimalService.OpenMenu(player, object)
    if not allowed then feedback:FireClient(player, object, false, reason, "HomeMenu");return end
    local settings = Config.Coops[object:GetAttribute("ItemName") or object.Name]
    local success, message
    if action == "Feed" then
        if settings.FeedCapacity > 0 then success, message = AnimalService.DepositFeed(player, object, amount)
        else success, message = AnimalService.Feed(player, object, amount) end
    elseif action == "Collect" then
        success, message = AnimalService.Collect(player, object)
    elseif action == "Add" then
        success, message = AnimalService.Add(player, object)
    elseif action == "Shop" then
        game.ReplicatedStorage.RemoteEvents.OpenBuyGuiEvent:FireClient(player, "Animals")
        success, message = true, "OpenShop"
    else
        local upgrade
        for id, definition in pairs(Definitions) do
            if definition.UpgradeFrom == (object:GetAttribute("ItemName") or object.Name) then upgrade = id;break end
        end
        if not upgrade then success, message = false, "No upgrade available."
        elseif action == "UpgradeShop" then
            game.ReplicatedStorage.RemoteEvents.OpenBuyGuiEvent:FireClient(player, "Upgrades")
            success, message = true, "OpenShop"
        else success, message = CoopUpgradeService.Pack(player, object, upgrade) end
    end
    feedback:FireClient(player, object, success, message, "HomeMenu")
end)

RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    if elapsed >= Config.UpdateInterval then
        elapsed = 0
        AnimalService.Step(workspace:GetServerTimeNow())
    end
end)
