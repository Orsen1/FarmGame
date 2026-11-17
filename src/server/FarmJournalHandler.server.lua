local Players = game:GetService("Players")
local Journal = require(script.Parent.FarmJournalService)
local remote = game.ReplicatedStorage.RemoteEvents:WaitForChild("FarmJournal")
local lastRequest = {}

remote.OnServerEvent:Connect(function(player, action, id)
    if typeof(action) ~= "string" or (id ~= nil and (typeof(id) ~= "string" or #id > 40)) then return end
    local now = os.clock()
    if now - (lastRequest[player] or 0) < 0.15 then return end
    lastRequest[player] = now
    local success, message
    if action == "Claim" then success, message = Journal.Claim(player, id)
    elseif action == "LevelUp" then success, message = Journal.LevelUp(player, id)
    elseif action == "Tutorial" then success = Journal.TutorialViewed(player, id)
    elseif action == "Track" then success = Journal.Track(player, id)
    elseif action ~= "Get" then return end
    local state = Journal.GetState(player)
    if state then remote:FireClient(player, state, success == false and message or nil) end
end)

Players.PlayerRemoving:Connect(function(player) lastRequest[player] = nil end)
