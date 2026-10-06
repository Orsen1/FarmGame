local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SellService = require(ServerScriptService:WaitForChild("SellService"))

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local sellItemEvent = remoteEvents:WaitForChild("SellItemEvent")

sellItemEvent.OnServerEvent:Connect(function(player, itemName, amount)
	if typeof(itemName) ~= "string" then
		return
	end
	
	if typeof(amount) ~= "number" then
		return
	end

	if amount <= 0 then
		return
	end

	SellService.SellItem(player, itemName, amount)
end)