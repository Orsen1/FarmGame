local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementService = require(ServerScriptService:WaitForChild("PlacementService"))
local PlaceEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("PlaceEvent")

local lastRequest = {}

PlaceEvent.OnServerEvent:Connect(function(player, itemName, position)
    local now = os.clock()

    if now - (lastRequest[player] or -math.huge) < 0.25 then
        PlaceEvent:FireClient(player, false, "Please wait a moment")
        return
    end

    lastRequest[player] = now

    local success, reason = PlacementService.placeItem(player, itemName, position)
    PlaceEvent:FireClient(player, success, reason)
end)

Players.PlayerRemoving:Connect(function(player)
    lastRequest[player] = nil
end)