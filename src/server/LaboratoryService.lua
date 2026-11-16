local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Configs.LaboratoryConfig)
local Definitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local Money = require(script.Parent.MoneyService)
local Laboratory = {}
local profiles, sessions, nextAllowed = {}, {}, {}
local random = Random.new()
local tracks = {}
for _, track in ipairs(Config.Tracks) do tracks[track.Id] = true end

function Laboratory.Load(player, saved)
    if saved ~= nil and typeof(saved) ~= "table" then return false end
    local data = {}
    for name in pairs(tracks) do
        local level = saved and saved[name]
        if level == nil then level = 0 end
        if typeof(level) ~= "number" or level % 1 ~= 0 or level < 0 or level > Config.MaxLevel then return false end
        data[name] = level
    end
    profiles[player] = data
    return true
end

function Laboratory.GetData(player)
    return profiles[player] and table.clone(profiles[player])
end

function Laboratory.GetBonuses(player)
    local levels = profiles[player]
    local result = {}
    for name in pairs(tracks) do result[name] = Config.Bonus(name, levels and levels[name] or 0) end
    return result
end

function Laboratory.CanUse(player, object)
    if player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("Teleporting") or
        player:GetAttribute("ProductionMode") or player:GetAttribute("Milking") or not profiles[player] then return false end
    if typeof(object) ~= "Instance" or not object:IsA("Model") then return false end
    local definition = Definitions[object:GetAttribute("ItemName") or object.Name]
    local plot = workspace.Plots:FindFirstChild(player:GetAttribute("PlotName") or "")
    if not definition or not definition.Laboratory or not plot or
        plot:GetAttribute("OwnerUserId") ~= player.UserId or object.Parent ~= plot:FindFirstChild("PlacedObjects") or
        object:GetAttribute("OwnerUserId") ~= player.UserId then return false end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local prompt = object:FindFirstChild("ActionPrompt", true)
    local attachment = prompt and prompt.Parent
    return root ~= nil and humanoid ~= nil and humanoid.Health > 0 and attachment ~= nil and
        attachment:IsA("Attachment") and (root.Position - attachment.WorldPosition).Magnitude <= Config.InteractionDistance
end

local function snapshot(player, session)
    return {SessionId = session.Id, Attempt = session.Attempt, Station = session.Station,
        Levels = Laboratory.GetData(player), Money = Money.GetMoney(player)}
end

function Laboratory.Open(player, object)
    if not Laboratory.CanUse(player, object) then return nil end
    local session = sessions[player]
    if not session or session.Station ~= object then
        session = {Id = HttpService:GenerateGUID(false), Station = object, Attempt = 1}
        sessions[player] = session
    end
    return snapshot(player, session)
end

function Laboratory.Attempt(player, sessionId, attempt, track)
    local session = sessions[player]
    if not session or session.Id ~= sessionId or typeof(attempt) ~= "number" or
        attempt % 1 ~= 0 or typeof(track) ~= "string" or not tracks[track] then return nil end
    if not Laboratory.CanUse(player, session.Station) then return {SessionId = sessionId, Closed = true} end
    if session.Last and attempt == session.Last.Request then return session.Last end
    if attempt ~= session.Attempt then return nil end
    local levels = profiles[player]
    local level = levels[track]
    local row = Config.Levels[level + 1]
    local result = snapshot(player, session)
    result.Request, result.Track = attempt, track
    result.Accepted = false
    if os.clock() < (nextAllowed[player] or 0) then
        result.Message = "Please wait for the experiment to finish."
    elseif not row then
        result.Message = "Maximum level reached."
    elseif not Money.RemoveMoney(player, row.PriceCents) then
        result.Message = "Not enough money."
    else
        nextAllowed[player] = os.clock() + Config.AttemptCooldown
        result.Accepted = true
        result.Success = random:NextNumber() * 100 < row.Chance
        result.PriceCents = row.PriceCents
        result.Chance = row.Chance
        if result.Success then levels[track] = level + 1 end
        result.Message = result.Success and string.format("Research upgraded to +%d!", levels[track]) or
            "Experiment failed. Your level is safe."
    end
    session.Attempt += 1
    result.Attempt = session.Attempt
    result.Levels = Laboratory.GetData(player)
    result.Money = Money.GetMoney(player)
    session.Last = result
    return result
end

function Laboratory.Close(player, sessionId)
    local session = sessions[player]
    if session and (sessionId == nil or session.Id == sessionId) then sessions[player] = nil end
end

function Laboratory.Clear(player)
    profiles[player], sessions[player], nextAllowed[player] = nil, nil, nil
end

return Laboratory
