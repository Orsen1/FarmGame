local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))

local PlantDataService = require(ServerScriptService:WaitForChild("PlantDataService"))
local ProductionDataService = require(ServerScriptService:WaitForChild("ProductionDataService"))
local PlacementModels = require(ReplicatedStorage:WaitForChild("PlacementScripts"):WaitForChild("PlacementModels"))
local ConstructionService = require(ServerScriptService:WaitForChild("ConstructionService"))
local AnimalService = require(ServerScriptService:WaitForChild("AnimalService"))
local InventoryService = require(ServerScriptService.InventoryService)
local AnimalConfig = require(ReplicatedStorage.Configs.AnimalConfig)
local BedConfig = require(ReplicatedStorage.Configs.GardenBedConfig)
local BedLayout = require(ReplicatedStorage.PlacementScripts.GardenBedLayout)
local StarterHouseLayout = require(ReplicatedStorage.PlacementScripts.StarterHouseLayout)
local houseConfig = require(ReplicatedStorage.Configs.StarterHouseConfig)

local plots = workspace:WaitForChild("Plots")

local PlotDataService = {}

function PlotDataService.getTemplate(savedObject)
    if typeof(savedObject) ~= "table" or typeof(savedObject.ItemName) ~= "string" then
        return nil, "Invalid saved object"
    end
    local definition = ItemDefinitions[savedObject.ItemName]
    local template = PlacementModels.getTemplate(savedObject.ItemName, savedObject.ConstructionStage)
    if not definition or not definition.Placeable or not template or not template:IsA("Model") then
        return nil, "Missing definition or model: " .. savedObject.ItemName
    end
    if savedObject.BedLevel ~= nil and not BedConfig.ValidLevel(savedObject.ItemName, savedObject.BedLevel) then
        return nil, "Invalid saved garden bed level"
    end
    if savedObject.BuildingId ~= nil and (typeof(savedObject.BuildingId) ~= "string" or #savedObject.BuildingId == 0) then
        return nil, "Invalid saved building identity"
    end
    return template
end

local function savedPlacement(savedObject)
    local template, reason = PlotDataService.getTemplate(savedObject)
    if not template then return nil, nil, reason end
    local pivot = savedObject.Pivot
    if typeof(pivot) ~= "table" or #pivot ~= 12 then return nil, nil, "Invalid saved pivot" end
    for index = 1, 12 do
        local value = pivot[index]
        if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
            return nil, nil, "Invalid saved pivot"
        end
    end
    local frame = CFrame.new(table.unpack(pivot))
    if math.abs(frame.RightVector.Magnitude - 1) > 0.01 or math.abs(frame.UpVector.Magnitude - 1) > 0.01 or
        math.abs(frame.LookVector.Magnitude - 1) > 0.01 or frame.RightVector:Cross(frame.UpVector):Dot(frame.ZVector) < 0.99 then
        return nil, nil, "Invalid saved rotation"
    end
    return template, frame
end

function PlotDataService.migrateStarterHouse(plot, data)
    local version = data.StarterHouseMigrationVersion
    if version == nil then version = 0 end
    if typeof(version) ~= "number" or version < 0 or version % 1 ~= 0 then
        return nil, false, "Invalid starter house migration version"
    end
    if version >= houseConfig.MigrationVersion then return data, false end
    local savedObjects = data.PlacedObjects
    if savedObjects == nil then savedObjects = {} end
    if typeof(savedObjects) ~= "table" then return nil, false, "Invalid placed objects" end
    local objectCount = 0
    for index in pairs(savedObjects) do
        if typeof(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #savedObjects then
            return nil, false, "Invalid placed object index"
        end
        objectCount += 1
    end
    if objectCount ~= #savedObjects then return nil, false, "Incomplete placed object list" end
    local remaining = {}
    for _, savedObject in ipairs(savedObjects) do
        local template, relative, reason = savedPlacement(savedObject)
        if not template then return nil, false, reason end
        local world = plot.Ground.CFrame * relative
        local transform = world * template:GetPivot():Inverse()
        local box, size = template:GetBoundingBox()
        local intersects = false
        if StarterHouseLayout.Overlaps(plot, transform * box, size) then
            for _, part in ipairs(template:GetDescendants()) do
                if part:IsA("BasePart") and (part.CanCollide or part.Transparency < 1) and
                    StarterHouseLayout.Overlaps(plot, transform * part.CFrame, part.Size) then
                    intersects = true
                    break
                end
            end
        end
        if not intersects then table.insert(remaining, savedObject) end
    end
    local migrated = table.clone(data)
    migrated.PlacedObjects = remaining
    migrated.StarterHouseMigrationVersion = houseConfig.MigrationVersion
    return migrated, true
end

local function getPlot(player)
    local plotName = player:GetAttribute("PlotName")
    local plot = plotName and plots:FindFirstChild(plotName)

    if plot and plot:GetAttribute("OwnerUserId") == player.UserId then
        return plot
    end
end

function PlotDataService.getData(player)
    local plot = getPlot(player)
    local ground = plot and plot:FindFirstChild("Ground")
    local objects = plot and plot:FindFirstChild("PlacedObjects")

    if not ground or not ground:IsA("BasePart") or not objects then
        return nil, "Plot is not ready"
    end

    local result = {}

    for _, object in ipairs(objects:GetChildren()) do
        local snapshot, reason = PlotDataService.snapshotObject(object)
        if not snapshot then return nil, reason end
        snapshot.Pivot = {ground.CFrame:ToObjectSpace(object:GetPivot()):GetComponents()}
        table.insert(result, snapshot)
    end
    return result
end

function PlotDataService.snapshotObject(object)
    local itemName = object:GetAttribute("ItemName") or object.Name
    local definition = ItemDefinitions[itemName]

    if not object:IsA("Model") or not definition or definition.Placeable ~= true then
        return nil, "Unknown placed object: " .. object.Name
    end

    local savedObject = {
        ItemName = itemName,
        PurchaseCents = object:GetAttribute("PurchaseCents"),
        BedLevel = object:GetAttribute("BedLevel"),
        BuildingId = object:GetAttribute("BuildingId")
    }
    if savedObject.PurchaseCents ~= nil and not InventoryService.IsPurchaseCost(savedObject.PurchaseCents) then
        return nil, "Invalid placed purchase cost"
    end

    if savedObject.BedLevel ~= nil and not BedConfig.ValidLevel(itemName, savedObject.BedLevel) then
        return nil, "Invalid garden bed level"
    end
    savedObject.Plant = PlantDataService.getData(object)
    if definition.Plantable and object:GetAttribute("Occupied") and not savedObject.Plant then
        return nil, "Plant progress is unavailable"
    end

    if definition.Recipes then
        local outputData, outputError, production = ProductionDataService.getData(object)
        if not outputData then
            return nil, outputError
        end
        savedObject.OutputInventory = outputData
        savedObject.Production = production
    end

    if definition.BuildsInto then
        local stage = object:GetAttribute("ConstructionStage")
        if stage == nil then
            stage = 0
        end
        if not PlacementModels.getTemplate(itemName, stage) then
            return nil, "Invalid construction stage in " .. itemName
        end
        local deposits, reason = ConstructionService.getData(object)
        if not deposits then
            return nil, reason
        end
        savedObject.ConstructionStage = stage
        if next(deposits) then
            savedObject.ConstructionDeposits = deposits
        end
    end

    if AnimalConfig.Coops[itemName] then
        local contents, reason = AnimalService.Snapshot(object)
        if not contents then return nil, reason end
        savedObject.Animals = contents.Animals
        savedObject.AnimalFeedStock = contents.FeedStock
        local outputItem = AnimalConfig.Coops[itemName].EggItem
        savedObject.OutputInventory = outputItem and {[outputItem] = contents.Eggs} or {}
    end

    return savedObject
end

function PlotDataService.loadData(player, savedObjects)
    local plot = getPlot(player)
    local ground = plot and plot:FindFirstChild("Ground")
    local objects = plot and plot:FindFirstChild("PlacedObjects")

    if not ground or not ground:IsA("BasePart") or not objects then
        return false, "Plot is not ready"
    end

    if typeof(savedObjects) ~= "table" or #objects:GetChildren() > 0 then
        return false, "Invalid data or plot is not empty"
    end

    for _, savedObject in ipairs(savedObjects) do
        local template, pivot, reason = savedPlacement(savedObject)
        if not template then return false, reason end
        local object, restoreError = PlotDataService.restoreObject(player, savedObject, template, ground.CFrame * pivot)
        if not object then return false, restoreError end
        object.Parent = objects
    end
    return true
end

function PlotDataService.restoreObject(player, savedObject, template, pivot, fromStorage)
    if savedObject.PurchaseCents ~= nil and not InventoryService.IsPurchaseCost(savedObject.PurchaseCents) then
        return nil, "Invalid saved purchase cost"
    end
    local definition = ItemDefinitions[savedObject.ItemName]

    local object = template:Clone()

    object:SetAttribute("OwnerUserId", player.UserId)
    object:SetAttribute("ItemName", savedObject.ItemName)
    object:SetAttribute("PurchaseCents", savedObject.PurchaseCents)
    object:SetAttribute("BuildingId", savedObject.BuildingId)

    object.Name = savedObject.ItemName

    if definition.BuildsInto then
        local stage = savedObject.ConstructionStage
        if stage == nil then
            stage = 0
        end
        object:SetAttribute("ConstructionStage", stage)
        local success, reason = ConstructionService.loadData(object, savedObject.ConstructionDeposits)
        if not success then
            object:Destroy()
            return nil, reason
        end
    end

    if definition.Recipes or AnimalConfig.Coops[savedObject.ItemName] then
        local success, errorMessage = ProductionDataService.loadData(object, savedObject, fromStorage)
        if not success then
            object:Destroy()
            return nil, errorMessage
        end
    end

    if AnimalConfig.Coops[savedObject.ItemName] then
        local success, reason = AnimalService.loadData(object, savedObject.Animals, savedObject.AnimalFeedStock)
        if not success then object:Destroy();return nil, reason end
    end

    for _, part in ipairs(object:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanQuery = true
        end
    end

    object:PivotTo(pivot)
    if savedObject.BedLevel and savedObject.BedLevel > 1 then
        BedLayout.Expand(object, savedObject.ItemName, savedObject.BedLevel)
    end
    if definition.Plantable then
        local isValid, errorMessage = PlantDataService.loadData(template, object, savedObject)
        if not isValid then
            object:Destroy()
            return nil, errorMessage
        end
    end
    return object
end

return PlotDataService
