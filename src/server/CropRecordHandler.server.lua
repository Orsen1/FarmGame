local Records = require(script.Parent.CropRecordService)
local config = require(game.ReplicatedStorage.Configs.CropConfig)
local remote = game.ReplicatedStorage.RemoteEvents.CropRecords
local last = {}
remote.OnServerEvent:Connect(function(player, crop)
    if crop ~= nil and (typeof(crop) ~= "string" or crop ~= "All" and not config.Crops[crop]) then return end
    if player:GetAttribute("DataLoaded") ~= true or os.clock() - (last[player] or -10) < 1 then return end
    last[player] = os.clock()
    remote:FireClient(player, Records.GetBoards(crop))
end)
game.Players.PlayerRemoving:Connect(function(player) last[player] = nil end)
