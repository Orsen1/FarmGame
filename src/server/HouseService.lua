local ReplicatedStorage = game:GetService("ReplicatedStorage")
local config = require(ReplicatedStorage.Configs.StarterHouseConfig)
local ConstructionService = require(script.Parent.ConstructionService)
local InventoryService = require(script.Parent.InventoryService)
local ProductionDataService = require(script.Parent.ProductionDataService)
local models = ReplicatedStorage:WaitForChild("FarmModels")
local Journal = require(script.Parent.FarmJournalService)
local HouseService = {}
local prefix = "ConstructionDeposited_"
local skinFolders = {"Foundation", "Walls", "Roof", "Windows", "Door", "Porch", "Chimney", "Decorations", "Collision", "Furniture"}

function HouseService.GetHouse(station)
    local stations = station.Parent
    local house = stations and stations.Name == "Stations" and stations.Parent
    if house and house:IsA("Model") and house.Name == "StarterHouse" and house:GetAttribute("Permanent") then
        return house
    end
end

function HouseService.GetStep(house)
    local upgrade = config.Levels[(house:GetAttribute("HouseLevel") or -1) + 1]
    return upgrade and upgrade.Stages[(house:GetAttribute("HouseUpgradeStage") or 0) + 1], upgrade
end

function HouseService.SetOwner(house, userId)
    house:SetAttribute("OwnerUserId", userId)
    for _, station in house.Stations:GetChildren() do station:SetAttribute("OwnerUserId", userId) end
end

local function applySkin(house, level, stage)
    local upgrade = config.Levels[level + 1]
    local step = upgrade and stage > 0 and upgrade.Stages[stage]
    local name = step and step.Model or level >= 0 and config.Levels[level].Model or "StarterHouse"
    local template = models:FindFirstChild(name)
    if not template then return false, "House model is missing" end
    local transform = house:GetPivot() * template:GetPivot():Inverse()
    for _, name in ipairs(skinFolders) do
        local source = template:FindFirstChild(name)
        if source then
            local old = house:FindFirstChild(name)
            if old then old:Destroy() end
            local folder = source:Clone()
            for _, part in folder:GetDescendants() do
                if part:IsA("BasePart") then part.CFrame = transform * part.CFrame end
            end
            folder.Parent = house
        end
    end
    for _, station in house.Stations:GetChildren() do
        local broken = station:FindFirstChild("BrokenDetails")
        if broken then
            for _, part in broken:GetDescendants() do
                if part:IsA("BasePart") then
                    part.Transparency = level >= 0 and 1 or 0
                    part.CanCollide, part.CanQuery = false, false
                    part.CastShadow = level < 0
                end
            end
        end
    end
    house:SetAttribute("HouseLevel", level)
    house:SetAttribute("HouseUpgradeStage", stage)
    return true
end

local function deposits(house, step)
    local result = {}
    for name, required in pairs(step and step.Inputs or {}) do
        local count = house:GetAttribute(prefix .. name) or 0
        if typeof(count) ~= "number" or count < 0 or count % 1 ~= 0 or count > required then return end
        if count > 0 then result[name] = count end
    end
    return result
end

function HouseService.GetData(house)
    local step = HouseService.GetStep(house)
    local materials = deposits(house, step)
    if not materials then return end
    local saved = {Level = house:GetAttribute("HouseLevel") or -1,
        Stage = house:GetAttribute("HouseUpgradeStage") or 0, Materials = materials, Stations = {}}
    for _, entry in ipairs(config.Objects) do
        local output, reason, production = ProductionDataService.getData(house.Stations[entry.Id])
        if not output then return nil, reason end
        saved.Stations[entry.Id] = {OutputInventory = output, Production = production}
    end
    return saved
end

function HouseService.Load(house, saved)
    if saved == nil then saved = {Level = -1} end
    if typeof(saved) ~= "table" then return false, "Invalid house data" end
    local level, stage = saved.Level, saved.Stage == nil and 0 or saved.Stage
    if typeof(level) ~= "number" or level % 1 ~= 0 or level < -1 or level >= 0 and not config.Levels[level] then
        return false, "Invalid house level"
    end
    local upgrade = config.Levels[level + 1]
    if typeof(stage) ~= "number" or stage < 0 or stage % 1 ~= 0 or stage > 0 and (not upgrade or not upgrade.Stages[stage + 1]) then
        return false, "Invalid house upgrade stage"
    end
    local step = upgrade and upgrade.Stages[stage + 1]
    local materials = saved.Materials == nil and {} or saved.Materials
    local stations = saved.Stations == nil and {} or saved.Stations
    if typeof(materials) ~= "table" or typeof(stations) ~= "table" then return false, "Invalid house inventory" end
    for name, count in pairs(materials) do
        if not step or not step.Inputs[name] or typeof(count) ~= "number" or count < 0 or count % 1 ~= 0 or count > step.Inputs[name] then
            return false, "Invalid house materials"
        end
    end
    for _, entry in ipairs(config.Objects) do
        local state = stations[entry.Id]
        if state == nil then state = {} end
        if typeof(state) ~= "table" then return false, "Invalid house station" end
        local loaded, reason = ProductionDataService.loadData(house.Stations[entry.Id], state)
        if not loaded then return false, reason end
    end
    local applied, reason = applySkin(house, level, stage)
    if not applied then return false, reason end
    for name in pairs(house:GetAttributes()) do
        if string.sub(name, 1, #prefix) == prefix then house:SetAttribute(name, nil) end
    end
    for name, count in pairs(materials) do house:SetAttribute(prefix .. name, count) end
    return true
end

function HouseService.Build(player, house)
    local plotName = player:GetAttribute("PlotName")
    local plot = plotName and workspace.Plots:FindFirstChild(plotName)
    if player:GetAttribute("DataLoaded") ~= true or not plot or plot:GetAttribute("OwnerUserId") ~= player.UserId or
        plot:FindFirstChild("StarterHouse") ~= house or house:GetAttribute("OwnerUserId") ~= player.UserId then
        return false, "This is not your farmhouse"
    end
    local step, upgrade = HouseService.GetStep(house)
    if not step then return false, "No further upgrades yet" end
    if not models:FindFirstChild(upgrade.Model) or step.Model and not models:FindFirstChild(step.Model) then
        return false, "House model is missing"
    end
    local materials = deposits(house, step)
    if not materials then return false, "Invalid house materials" end
    local payment, complete = ConstructionService.PlanDeposit(player, step.Inputs, materials)
    if not payment then return false, complete end
    if not next(payment) then return false, "Bring the remaining materials" end
    local exchanged, reason = InventoryService.ExchangeItems(player, payment, {})
    if not exchanged then return false, reason end
    if not complete then
        for name, count in pairs(materials) do house:SetAttribute(prefix .. name, count) end
        return true, "Materials added"
    end
    for name in pairs(step.Inputs) do house:SetAttribute(prefix .. name, nil) end
    local level = house:GetAttribute("HouseLevel") or -1
    local stage = (house:GetAttribute("HouseUpgradeStage") or 0) + 1
    if stage == #upgrade.Stages then level, stage = level + 1, 0 end
    applySkin(house, level, stage)
    Journal.Update(player)
    return true, stage == 0 and "Farmhouse restored!" or "Stage completed"
end

return HouseService
