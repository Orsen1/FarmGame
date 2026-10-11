local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BuyService = require(ServerScriptService:WaitForChild("BuyService"))
local buyEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("BuyItemEvent")
local MAX_INTEGER = 9007199254740991
local REQUEST_INTERVAL = 0.15
local lastRequest = {}

buyEvent.OnServerEvent:Connect(function(player, itemName, amount, requestId)
    if requestId ~= nil and (typeof(requestId) ~= "string" or #requestId > 64) then
        return
    end

    local function reply(success, reason)
        if player.Parent == nil then
            return
        end
        buyEvent:FireClient(player, {
            RequestId = requestId,
            Success = success,
            Reason = reason
        })
    end

    local now = os.clock()
    if lastRequest[player] and now - lastRequest[player] < REQUEST_INTERVAL then
        reply(false, "RateLimited")
        return
    end
    lastRequest[player] = now

    if typeof(itemName) ~= "string" or #itemName > 128 then
        reply(false, "InvalidItem")
        return
    end
    if typeof(amount) ~= "number" or amount < 1 or amount > MAX_INTEGER or amount % 1 ~= 0 then
        reply(false, "InvalidAmount")
        return
    end

    local ok, success, reason = pcall(BuyService.BuyItem, player, itemName, amount)
    if not ok then
        warn("BuyService error for " .. player.Name .. ": " .. tostring(success))
        reply(false, "InternalError")
        return
    end
    reply(success == true, reason)
end)

Players.PlayerRemoving:Connect(function(player)
    lastRequest[player] = nil
end)

