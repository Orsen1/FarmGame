local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ObjectRemovalService = require(script.Parent:WaitForChild("ObjectRemovalService"))
local RemoveObjectEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("RemoveObjectEvent")

local lastRequest = {}

RemoveObjectEvent.OnServerEvent:Connect(function(player, object)
    local now = os.clock()

    if now - (lastRequest[player] or -math.huge) < 0.25 then
        RemoveObjectEvent:FireClient(player, false, "Please wait a moment.")
        return
    end

    lastRequest[player] = now

    local success, message = ObjectRemovalService.remove(player, object)
    RemoveObjectEvent:FireClient(player, success, message)
end)

Players.PlayerRemoving:Connect(function(player)
    lastRequest[player] = nil
end)
