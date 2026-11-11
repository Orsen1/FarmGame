local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OrderService = require(script.Parent.OrderService)
local config = require(ReplicatedStorage.Configs.OrderConfig)
local event = ReplicatedStorage.RemoteEvents:WaitForChild("OrderEvent")
local boards = workspace:WaitForChild("OrderBoards")
local lastRequest = {}

for boardId, definition in pairs(config.Boards) do
    local board = boards:WaitForChild(definition.ModelName)
    local prompt = board.InteractionRoot.OrderPrompt
    prompt.MaxActivationDistance = config.InteractionDistance
    prompt.ObjectText = definition.DisplayName
    prompt.Triggered:Connect(function(player)
        local state = OrderService.Open(player, boardId)
        if state then
            event:FireClient(player, "Open", state)
        end
    end)
end

event.OnServerEvent:Connect(function(player, boardId, orderId)
    if typeof(boardId) ~= "string" or #boardId > 40 or typeof(orderId) ~= "string" or #orderId > 64 then
        return
    end
    local now = os.clock()
    if lastRequest[player] and now - lastRequest[player] < config.RequestInterval then
        return
    end
    lastRequest[player] = now
    local success, reason, value = OrderService.Deliver(player, boardId, orderId)
    local state = OrderService.Open(player, boardId)
    if state then
        event:FireClient(player, "Update", state, success, reason, value)
    else
        event:FireClient(player, "Close", nil, false, reason)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    lastRequest[player] = nil
end)
