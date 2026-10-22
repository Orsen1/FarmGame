local Players = game:GetService("Players")
local plotsFolder = workspace:WaitForChild("Plots")

local PlayerPlotService = {}

function PlayerPlotService.assignPlotToPlayer(player)
    if player.Parent ~= Players or player:GetAttribute("PlotName") then
        return
    end

    for plotNumber = 1, 4 do
        local plot = plotsFolder:FindFirstChild("Plot" .. plotNumber)

        if plot and plot:GetAttribute("OwnerUserId") == 0 then
            plot:SetAttribute("OwnerUserId", player.UserId)
            player:SetAttribute("PlotName", plot.Name)

            local ownerSign = plot:FindFirstChild("OwnerSign")

            if ownerSign then
                local label = ownerSign:FindFirstChildWhichIsA("TextLabel", true)

                if label then
                    label.Text = player.Name
                end
            end

            print("[PLOT]", player.Name, "received", plot.Name)
            return 
        end
    end

    warn("[PLOT] No free plot for", player.Name)
end

function PlayerPlotService.moveCharacterToPlot(player, character)
    local plotName = player:GetAttribute("PlotName")
    if not plotName then
        return
    end

    local plot = plotsFolder:FindFirstChild(plotName)
    if not plot then
        return
    end

    local spawnPoint = plot:FindFirstChild("SpawnPoint")

    if not spawnPoint or not spawnPoint:IsA("BasePart") then
        warn("[PLOT] SpawnPoint is missing or invalid in", plot.Name)
        return
    end

    local rootPart = character:WaitForChild("HumanoidRootPart", 10)

    if not rootPart or player.Character ~= character then
        return
    end

    if plot:GetAttribute("OwnerUserId") ~= player.UserId then
        return
    end

    character:PivotTo(spawnPoint.CFrame + Vector3.new(0, 3, 0))
end

function PlayerPlotService.releasePlot(player)
    local plotName = player:GetAttribute("PlotName")
    if not plotName then
        return
    end

    local plot = plotsFolder:FindFirstChild(plotName)

    if not plot or plot:GetAttribute("OwnerUserId") ~= player.UserId then
        return
    end

    local placedObjects = plot:FindFirstChild("PlacedObjects")

    if placedObjects then
        placedObjects:ClearAllChildren()
    end

    local ownerSign = plot:FindFirstChild("OwnerSign")

    if ownerSign then
        local label = ownerSign:FindFirstChildWhichIsA("TextLabel", true)

        if label then
            label.Text = "Available"
        end
    end

    plot:SetAttribute("OwnerUserId", 0)
    player:SetAttribute("PlotName", nil)

    print("[PLOT]", player.Name, "released", plot.Name)
end

return PlayerPlotService