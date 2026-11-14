local Records = require(script.Parent.CropRecordService)
local remote = game.ReplicatedStorage.RemoteEvents.CropRecords
local last = {}
remote.OnServerEvent:Connect(function(player)
    if player:GetAttribute("DataLoaded") ~= true or os.clock() - (last[player] or -10) < 1 then return end
    last[player] = os.clock()
    remote:FireClient(player, Records.GetBoards())
end)
game.Players.PlayerRemoving:Connect(function(player) last[player] = nil end)
