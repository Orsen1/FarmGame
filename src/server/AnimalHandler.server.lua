local RunService = game:GetService("RunService")
local AnimalService = require(script.Parent.AnimalService)
local Config = require(game.ReplicatedStorage.Configs.AnimalConfig)
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
game.ReplicatedStorage.RemoteEvents.AnimalCommand.OnServerEvent:Connect(function(player, object, amount)
    if typeof(object) ~= "Instance" or not object:IsA("Model") then return end
    local success, message = AnimalService.DepositFeed(player, object, amount)
    game.ReplicatedStorage.RemoteEvents.AnimalFeedback:FireClient(player, object, success, message, "FeedPrompt")
end)

RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    if elapsed >= Config.UpdateInterval then
        elapsed = 0
        AnimalService.Step(workspace:GetServerTimeNow())
    end
end)
