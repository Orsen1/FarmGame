local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementService = require(ServerScriptService:WaitForChild("PlacementService"))
local PlaceGardenBedEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("PlaceGardenBedEvent")

local lastRequest = {}

PlaceGardenBedEvent.OnServerEvent:Connect(function(player, position)
    local now = os.clock()

    if now - (lastRequest[player] or -math.huge) < 0.25 then
        event:FireClient(player, false, "Please wait a moment")
        return
    end

    lastRequest[player] = now

    local success, reason = PlacementService.placeGardenBed(player, position)
    PlaceGardenBedEvent:FireClient(player, success, reason)
end)