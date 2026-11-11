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
RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    if elapsed >= Config.UpdateInterval then
        elapsed = 0
        AnimalService.Step(workspace:GetServerTimeNow())
    end
end)
