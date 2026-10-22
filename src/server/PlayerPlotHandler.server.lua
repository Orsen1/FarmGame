local Players = game:GetService("Players")
local plotsFolder = workspace:WaitForChild("Plots")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerPlotService =  require(ServerScriptService:WaitForChild("PlayerPlotService"))

local function onPlayerAdded(player)
    PlayerPlotService.assignPlotToPlayer(player)

    if not player:GetAttribute("PlotName") then
        return
    end

    player.CharacterAdded:Connect(function(character)
        PlayerPlotService.moveCharacterToPlot(player, character)
    end)

    if player.Character then
        task.spawn(PlayerPlotService.moveCharacterToPlot, player, player.Character)
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(PlayerPlotService.releasePlot)

for _, player in ipairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end
