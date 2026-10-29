local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local configs = ReplicatedStorage:WaitForChild("Configs")
local ItemDefinitions = require(configs:WaitForChild("ItemDefinitions"))
local ProductionRecipes = require(configs:WaitForChild("ProductionRecipes"))
local InventoryService = require(ServerScriptService:WaitForChild("InventoryService"))
local stateEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("ProductionState")
local plots = workspace:WaitForChild("Plots")

local ProductionService = {}
local sessions = {}
local operators = {}
local nextId = 0
local MAX_DISTANCE = 10

local function canUse(player, station)
    if player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true then
        return false, "Player data is not ready"
    end

    local plotName = player:GetAttribute("PlotName")
    local plot = plotName and plots:FindFirstChild(plotName)
    local objects = plot and plot:FindFirstChild("PlacedObjects")

    if not objects or station.Parent ~= objects or plot:GetAttribute("OwnerUserId") ~= player.UserId or
        station:GetAttribute("OwnerUserId") ~= player.UserId then
        return false, "You do not own this station"
    end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not humanoid or humanoid.Health <= 0 or not root then
        return false, "Character is not ready"
    end

    local distance = (root.Position - station:GetPivot().Position).Magnitude

    if distance > MAX_DISTANCE then
        return false, "Stay near the station"
    end
    return true
end

local function getRecipe(station, recipeId)
    local itemName = station:GetAttribute("ItemName") or station.Name
    local definition = ItemDefinitions[itemName]

    if not definition or typeof(definition.Recipes) ~= "table" or not table.find(definition.Recipes, recipeId) then
        return nil, "This recipe is not available at this station"
    end

    local recipe = ProductionRecipes[recipeId]

    if typeof(recipe) ~= "table" or typeof(recipe.Inputs) ~= "table" or typeof(recipe.Outputs) ~= "table" or
        next(recipe.Outputs) == nil or typeof(recipe.Duration) ~= "number" then
        return nil, "Invalid recipe configuration"
    end

    for itemName in pairs(recipe.Inputs) do
        if not ItemDefinitions[itemName] then
            return nil, "Unknown ingredient: " .. tostring(itemName)
        end
    end

    for itemName in pairs(recipe.Outputs) do
        if not ItemDefinitions[itemName] then
            return nil, "Unknown result: " .. tostring(itemName)
        end
    end

    return recipe
end

local function sendState(session, message)
    if session.Player.Parent == Players then
        stateEvent:FireClient(session.Player, "State", {
            SessionId = session.Id,
            Station = session.Station,
            RecipeId = session.RecipeId,
            Busy = session.Job ~= nil,
            Held = session.Held,
            StartedAt = session.Job and session.Job.StartedAt or 0,
            Duration = session.Job and session.Job.Recipe.Duration or 0,
            Message = message or ""
        })
    end
end

local function stopJob(session)
    local station, job = session.Station, session.Job
    if job and station.Parent then
        local cycle = station:GetAttribute("ProductionCycleSeconds") or 4
        local elapsed = math.clamp(workspace:GetServerTimeNow() - job.StartedAt, 0, job.Recipe.Duration)
        station:SetAttribute("ProductionAngle", (job.Angle + elapsed * math.pi * 2 / cycle) % (math.pi * 2))
    end
    session.Job = nil
    if station.Parent then
        station:SetAttribute("Busy", false)
        station:SetAttribute("ActiveRecipe", nil)
        station:SetAttribute("ProductionStartedAt", nil)
        station:SetAttribute("ProductionDuration", nil)
    end
end

function ProductionService.Close(player, reason)
    local session = sessions[player]
    if not session then return end
    sessions[player] = nil
    operators[session.Station] = nil
    session.Held = false
    stopJob(session)
    for _, connection in ipairs(session.Connections) do
        connection:Disconnect()
    end
    if session.Station.Parent then
        session.Station:SetAttribute("OperatorUserId", nil)
    end
    if session.Humanoid.Parent then
        for property, value in pairs(session.Movement) do
            session.Humanoid[property] = value
        end
    end
    if session.Root.Parent then
        session.Root.Anchored = session.WasAnchored
    end
    player:SetAttribute("ProductionMode", nil)
    if player.Parent == Players then
        stateEvent:FireClient(player, "Closed", {
            SessionId = session.Id,
            Reason = reason or "Exit"
        })
    end
end

function ProductionService.Open(player, station)
    local allowed, reason = canUse(player, station)
    if not allowed then return false, reason end
    if sessions[player] then return false, "AlreadyOpen" end
    if operators[station] then return false, "StationBusy" end
    local definition = ItemDefinitions[station:GetAttribute("ItemName") or station.Name]
    if not definition or typeof(definition.Recipes) ~= "table" then return false, "InvalidStation" end
    local work = station.PlacementRoot:FindFirstChild("WorkPosition")
    local camera = station.PlacementRoot:FindFirstChild("CameraPoint")
    local target = station.PlacementRoot:FindFirstChild("CameraTarget")
    if not work or not work:IsA("Attachment") or not camera or not target then return false, "MissingWorkPoints" end
    local character = player.Character
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character.HumanoidRootPart
    if humanoid.Sit then return false, "LeaveSeat" end
    nextId = nextId + 1
    local session = {
        Id = nextId, Player = player, Station = station, Character = character,
        Humanoid = humanoid, Root = root, Held = false, Connections = {},
        WasAnchored = root.Anchored,
        Movement = {WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower,
        JumpHeight = humanoid.JumpHeight, AutoRotate = humanoid.AutoRotate},
    }
    sessions[player], operators[station] = session, session
    local height = humanoid.HipHeight + root.Size.Y / 2
    if humanoid.RigType == Enum.HumanoidRigType.R6 then
        local leg = character:FindFirstChild("Left Leg")
        height = height + (leg and leg.Size.Y or 2)
    end
    root.CFrame = work.WorldCFrame + Vector3.new(0, height, 0)
    root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
    root.Anchored = true
    humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = 0, 0, 0
    humanoid.AutoRotate, humanoid.Jump = false, false
    player:SetAttribute("ProductionMode", true)
    station:SetAttribute("OperatorUserId", player.UserId)
    table.insert(session.Connections, humanoid.Died:Connect(function() ProductionService.Close(player, "Died") end))
    table.insert(session.Connections, station.Destroying:Connect(function() ProductionService.Close(player, "StationRemoved") end))
    table.insert(session.Connections, player.CharacterRemoving:Connect(function() ProductionService.Close(player, "CharacterChanged") end))
    stateEvent:FireClient(player, "Opened", {SessionId = session.Id, Station = station})
    sendState(session, "ChooseRecipe")
    return true
end

function ProductionService.Select(player, sessionId, recipeId)
    local session = sessions[player]
    if not session or session.Id ~= sessionId then return false, "NoSession" end
    if session.Job then sendState(session, "Working"); return false, "Working" end
    local allowed, reason = canUse(player, session.Station)
    if not allowed then ProductionService.Close(player, reason); return false, reason end
    if recipeId ~= nil then
        local recipe, errorMessage = getRecipe(session.Station, recipeId)
        if not recipe then sendState(session, errorMessage); return false, errorMessage end
    end
    session.Held, session.RecipeId = false, recipeId
    sendState(session, recipeId and "Ready" or "ChooseRecipe")
    return true
end

function ProductionService.Start(player)
    local session = sessions[player]
    if not session or not session.Held or session.Job or not session.RecipeId then return false, "NotReady" end
    local allowed, reason = canUse(player, session.Station)
    if not allowed then ProductionService.Close(player, reason); return false, reason end
    local recipe, recipeError = getRecipe(session.Station, session.RecipeId)
    if not recipe then sendState(session, recipeError); return false, recipeError end
    if not InventoryService.CanExchangeItems(player, recipe.Inputs, {}) then
        session.Held = false
        sendState(session, "NotEnoughItems")
        return false, "NotEnoughItems"
    end
    local station = session.Station
    local startedAt, angle = workspace:GetServerTimeNow(), station:GetAttribute("ProductionAngle") or 0
    session.Job = {Recipe = recipe, StartedAt = startedAt, Angle = angle}
    station:SetAttribute("ProductionAngle", angle)
    station:SetAttribute("ActiveRecipe", session.RecipeId)
    station:SetAttribute("ProductionStartedAt", startedAt)
    station:SetAttribute("ProductionDuration", recipe.Duration)
    station:SetAttribute("Busy", true)
    sendState(session, "Working")
    return true
end

function ProductionService.SetHeld(player, sessionId, held)
    local session = sessions[player]
    if not session or session.Id ~= sessionId or typeof(held) ~= "boolean" or session.Held == held then return end
    session.Held = held
    if held then
        ProductionService.Start(player)
    else
        stopJob(session)
        sendState(session, "Released")
    end
end

local function completeJob(session, job)
    local output = session.Station:FindFirstChild("OutputInventory")
    if not output or not output:IsA("Folder") then return false, "MissingOutputInventory" end
    for name, amount in pairs(job.Recipe.Outputs) do
        local stored = output:FindFirstChild(name)
        if stored and (not stored:IsA("IntValue") or stored.Value < 0) then
            return false, "InvalidOutputInventory"
        end
    end

    if not InventoryService.ExchangeItems(session.Player, job.Recipe.Inputs, {}) then return false, "NotEnoughItems" end
    for name, amount in pairs(job.Recipe.Outputs) do
        local stored = output:FindFirstChild(name)
        if not stored then
            stored = Instance.new("IntValue")
            stored.Name, stored.Parent = name, output
        end
        stored.Value = stored.Value + amount
    end
    return true
end

local checkElapsed = 0
RunService.Heartbeat:Connect(function(dt)
    checkElapsed = checkElapsed + dt
    if checkElapsed < 0.05 then return end
    checkElapsed = 0
    for player, session in pairs(sessions) do
        local allowed, reason = canUse(player, session.Station)
        if not allowed or player.Character ~= session.Character then
            ProductionService.Close(player, reason or "CharacterChanged")
        else
            local job = session.Job
            if job and workspace:GetServerTimeNow() >= job.StartedAt + job.Recipe.Duration then
                local success, message = completeJob(session, job)
                stopJob(session)
                if success and session.Held then
                    ProductionService.Start(player)
                else
                    session.Held = false
                    sendState(session, success and "Completed" or message)
                end
            end
        end
    end
end)

function ProductionService.Collect(player, station)
    if typeof(station) ~= "Instance" or not station:IsA("Model") then
        return false, "Invalid station"
    end

    local allowed, reason = canUse(player, station)
    if not allowed then return false, reason end

    local outputInventory = station:FindFirstChild("OutputInventory")

    if not outputInventory or not outputInventory:IsA("Folder") then
        return false, "OutputInventory is missing"
    end

    local outputs = {}
    local storedItems = {}

    for _, storedItem in ipairs(outputInventory:GetChildren()) do
        if storedItem:IsA("IntValue") and storedItem.Value > 0 then
            if not ItemDefinitions[storedItem.Name] then
                return false, "Unknown output item: " .. storedItem.Name
            end

            outputs[storedItem.Name] = storedItem.Value

            table.insert(storedItems, storedItem)
        end
    end

    if next(outputs) == nil then
        return false, "Nothing to collect"
    end

    local added, addError = InventoryService.ExchangeItems(player, {}, outputs)

    if not added then
        return false, addError
    end

    for _, storedItem in ipairs(storedItems) do
        storedItem.Value = 0
    end

    return true, "Items collected"
end

function ProductionService.GetSessionId(player)
    local session = sessions[player]
    return session and session.Id
end

Players.PlayerRemoving:Connect(function(player) ProductionService.Close(player, "Leaving") end)
return ProductionService