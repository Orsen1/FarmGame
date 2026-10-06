local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlantService = require(ServerScriptService:WaitForChild("PlantService"))

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local plantSeedEvent = remoteEvents:WaitForChild("PlantSeedEvent")

plantSeedEvent.OnServerEvent:Connect(function(player, gardenBed, seedType)
	print("PlantSeedEvent fired")
	PlantService.Plant(player, gardenBed, seedType)
end)