local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ProductionService = require(script.Parent:WaitForChild("ProductionService"))
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local command, state = remotes:WaitForChild("ProductionCommand"), remotes:WaitForChild("ProductionState")

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
    if prompt.Name ~= "MillPrompt" and prompt.Name ~= "ProductionPrompt" then return end
    local station = prompt:FindFirstAncestorOfClass("Model")
    local success, reason = ProductionService.Open(player, station)
    if not success and reason ~= "AlreadyOpen" then state:FireClient(player, "Error", {Message = reason}) end
end)

command.OnServerEvent:Connect(function(player, action, sessionId, value)
    if typeof(action) ~= "string" or typeof(sessionId) ~= "number"
        or sessionId ~= ProductionService.GetSessionId(player) then return end

    if action == "Close" then ProductionService.Close(player, "Exit"); return end
    if action == "Hold" and value == false then ProductionService.SetHeld(player, sessionId, false); return end
    if action == "Select" and (value == nil or typeof(value) == "string") then
        ProductionService.Select(player, sessionId, value)
    elseif action == "Hold" and value == true then
        ProductionService.SetHeld(player, sessionId, true)
    end
end)
