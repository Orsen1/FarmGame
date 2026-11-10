local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("WorldTravelConfig"))

local WorldTravelService = {}
local pending = {}
local lastAttempt = {}
local prepareData
local restoreData
local send
local activeFarms

if not RunService:IsStudio() then
    activeFarms = MemoryStoreService:GetHashMap("ActiveFarmServers_v1")
end

local function trackFarmServer()
    local closing = false
    local updating = false
    local refreshAgain = false

    local function refresh()
        if updating then
            refreshAgain = true
            return
        end
        updating = true
        repeat
            refreshAgain = false
            if closing or #Players:GetPlayers() == 0 then
                pcall(activeFarms.RemoveAsync, activeFarms, game.JobId)
            else
                pcall(activeFarms.SetAsync, activeFarms, game.JobId, true, 35)
            end
        until not refreshAgain
        updating = false
    end

    Players.PlayerAdded:Connect(function()
        if #Players:GetPlayers() == 1 then
            refresh()
        end
    end)
    Players.PlayerRemoving:Connect(function()
        if #Players:GetPlayers() <= 1 then
            task.defer(refresh)
        end
    end)
    game:BindToClose(function()
        closing = true
        refresh()
        while updating do
            task.wait()
        end
    end)
    task.spawn(function()
        while not closing do
            refresh()
            task.wait(12)
        end
    end)
end

if activeFarms and game.PlaceId == Config.FarmPlaceId then
    trackFarmServer()
end

local function validPlaceId(value)
    return typeof(value) == "number" and value > 0 and value % 1 == 0
end

function WorldTravelService.SetDataCallbacks(prepare, restore)
    prepareData = prepare
    restoreData = restore
end

local function finish(player, context, reason)
    if pending[player] ~= context then
        return
    end

    pending[player] = nil
    lastAttempt[player] = os.clock()

    if player.Parent == Players then
        if context.Prepared and restoreData then
            local ok, message = pcall(restoreData, player)

            if not ok then
                warn("[TRAVEL RESTORE]", message)
            end
        end

        player:SetAttribute("Teleporting", false)
        warn("[TRAVEL]", reason)
    end
end

local function failed(player, context, attemptId, reason)
    if pending[player] ~= context or context.AttemptId ~= attemptId then
        return
    end

    if context.Destination == "Farm" and context.ServerId ~= "" then
        context.ServerId = ""
        context.AttemptId = nil
        task.defer(send, player, context)
        return
    end

    finish(player, context, reason)
end

send = function(player, context)
    if pending[player] ~= context or player.Parent ~= Players then
        return
    end

    local attemptId = HttpService:GenerateGUID(false)
    context.AttemptId = attemptId

    local options = Instance.new("TeleportOptions")

    if context.ServerId ~= "" then
        options.ServerInstanceId = context.ServerId
    end

    options:SetTeleportData({
        TravelAttemptId = attemptId,
        ReturnFarmPlaceId = context.ReturnFarmPlaceId,
        ReturnFarmJobId = context.ReturnFarmJobId
    })

    local success, reason = pcall(function()
        TeleportService:TeleportAsync(context.PlaceId, {player}, options)
    end)

    if not success then
        failed(player, context, attemptId, tostring(reason))
    end
end

function WorldTravelService.Travel(player, destination)
    if pending[player] or (lastAttempt[player] and os.clock() - lastAttempt[player] < Config.RetryCooldown) then
        return false, "Busy"
    end

    lastAttempt[player] = os.clock()

    if RunService:IsStudio() then
        return false, "Teleports must be tested in the published Roblox game"
    end

    if not validPlaceId(Config.FarmPlaceId) or not validPlaceId(Config.ResourcesPlaceId) or Config.FarmPlaceId ==
        Config.ResourcesPlaceId then
        return false, "Configure both PlaceIds in WorldTravelConfig"
    end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    if player.Parent ~= Players or not humanoid or humanoid.Health <= 0 then
        return false, "Player is not ready"
    end

    local context = {
        Destination = destination,
        ServerId = "",
        Prepared = false
    }

    if destination == "Resources" and game.PlaceId == Config.FarmPlaceId then
        context.PlaceId = Config.ResourcesPlaceId
        context.ReturnFarmPlaceId = game.PlaceId
        if #Players:GetPlayers() > 1 then
            context.ReturnFarmJobId = game.JobId
        end

    elseif destination == "Farm" and game.PlaceId == Config.ResourcesPlaceId then
        context.PlaceId = Config.FarmPlaceId

        local joinData = player:GetJoinData()
        local data = joinData.TeleportData

        if joinData.SourcePlaceId == Config.FarmPlaceId and typeof(data) == "table" and data.ReturnFarmPlaceId ==
            Config.FarmPlaceId and typeof(data.ReturnFarmJobId) == "string" and #data.ReturnFarmJobId <= 100 then
            context.ServerId = data.ReturnFarmJobId
        end

    else
        return false, "This portal destination is not available here"
    end

    if player:GetAttribute("DataLoaded") ~= true or not prepareData or not restoreData then
        return false, "Player data is not ready"
    end

    pending[player] = context
    player:SetAttribute("Teleporting", true)

    local ok, saved = pcall(prepareData, player)
    if not ok or saved ~= true then
        finish(player, context, "Player data could not be saved; teleport cancelled")
        return false, "Save failed"
    end

    context.Prepared = true
    if context.ServerId ~= "" then
        local checked, online = pcall(activeFarms.GetAsync, activeFarms, context.ServerId)
        if not checked or online ~= true then
            context.ServerId = ""
        end
    end
    send(player, context)
    return true
end

TeleportService.TeleportInitFailed:Connect(function(player, _, message, placeId, options)
    local context = pending[player]

    if not context or context.PlaceId ~= placeId or not context.AttemptId or not options then
        return
    end

    local data = options:GetTeleportData()

    if typeof(data) == "table" and typeof(data.TravelAttemptId) == "string" then
        failed(player, context, data.TravelAttemptId, message)
    elseif options.ServerInstanceId == context.ServerId then
        failed(player, context, context.AttemptId, message)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    pending[player] = nil
    lastAttempt[player] = nil
end)

return WorldTravelService
