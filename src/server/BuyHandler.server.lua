local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BuyService = require(ServerScriptService:WaitForChild("BuyService"))
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local buyItemEvent = remoteEvents:WaitForChild("BuyItemEvent")

local lastRequest = {}
local REQUEST_INTERVAL = 0.15

buyItemEvent.OnServerEvent:Connect(function(player, itemName, amount)
	if typeof(itemName) ~= "string" then
		return
	end

	if typeof(amount) ~= "number" or amount <= 0 or amount % 1 ~= 0 then
		return
	end

	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < REQUEST_INTERVAL then
		return
	end
	lastRequest[player] = now

	BuyService.BuyItem(player, itemName, amount)
end)

Players.PlayerRemoving:Connect(function(player)
	lastRequest[player] = nil
end)
