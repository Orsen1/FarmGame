local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))

local PlantDataService = require(ServerScriptService:WaitForChild("PlantDataService"))
local ProductionDataService = require(ServerScriptService:WaitForChild("ProductionDataService"))
local PlantService = require(ServerScriptService:WaitForChild("PlantService"))
local PlacementModels = require(ReplicatedStorage:WaitForChild("PlacementScripts"):WaitForChild("PlacementModels"))
local StorageService = require(ServerScriptService:WaitForChild("StorageService"))
local ConstructionService = require(ServerScriptService:WaitForChild("ConstructionService"))
local AnimalService = require(ServerScriptService:WaitForChild("AnimalService"))
local AnimalConfig = require(ReplicatedStorage.Configs.AnimalConfig)
local StarterHouseLayout = require(ReplicatedStorage.PlacementScripts.StarterHouseLayout)
local houseConfig = require(ReplicatedStorage.Configs.StarterHouseConfig)

local models = ReplicatedStorage:WaitForChild("PlaceableModels")
local plants = ReplicatedStorage:WaitForChild("Plants")
local plots = workspace:WaitForChild("Plots")

local PlotDataService = {}

local function savedPlacement(savedObject)
    if typeof(savedObject) ~= "table" or typeof(savedObject.ItemName) ~= "string" then
        return nil, nil, "Invalid saved object"
    end
    local definition = ItemDefinitions[savedObject.ItemName]
    local template = PlacementModels.getTemplate(savedObject.ItemName, savedObject.ConstructionStage)
    if not definition or not definition.Placeable or not template or not template:IsA("Model") then
        return nil, nil, "Missing definition or model: " .. savedObject.ItemName
    end
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
        local itemName = object:GetAttribute("ItemName") or object.Name
        local definition = ItemDefinitions[itemName]

        if not object:IsA("Model") or not definition or definition.Placeable ~= true then
            return nil, "Unknown placed object: " .. object.Name
        end

        local relativePivot = ground.CFrame:ToObjectSpace(object:GetPivot())

        local savedObject = {
            ItemName = itemName,
            Pivot = {relativePivot:GetComponents()}
        }

        savedObject.Plant = PlantDataService.getData(object)

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

        if definition.StorageSlots then
            local data, reason = StorageService.getData(object)

            if not data then
                return nil, reason
            end

            savedObject.StorageInventory = data
        end

        if AnimalConfig.Coops[itemName] then
            local contents, reason = AnimalService.Snapshot(object)
            if not contents then return nil, reason end
            savedObject.Animals = contents.Animals
            savedObject.AnimalFeedStock = contents.FeedStock
            local outputItem = AnimalConfig.Coops[itemName].EggItem
            savedObject.OutputInventory = outputItem and {[outputItem] = contents.Eggs} or {}
        end

        table.insert(result, savedObject)
    end

    return result
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
        local template, pivot, placementError = savedPlacement(savedObject)
        if not template then return false, placementError end
        local definition = ItemDefinitions[savedObject.ItemName]

        local object = template:Clone()

        object:SetAttribute("OwnerUserId", player.UserId)
        object:SetAttribute("ItemName", savedObject.ItemName)

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
                return false, reason
            end
        end

        if definition.Recipes or AnimalConfig.Coops[savedObject.ItemName] then
            local success, errorMessage = ProductionDataService.loadData(object, savedObject)
            if not success then
                object:Destroy()
                return false, errorMessage
            end
        end

        if definition.StorageSlots then
            local success, reason = StorageService.loadData(object, savedObject)
            if not success then
                object:Destroy()
                return false, reason
            end
        end

        if AnimalConfig.Coops[savedObject.ItemName] then
            local success, reason = AnimalService.loadData(object, savedObject.Animals, savedObject.AnimalFeedStock)
            if not success then object:Destroy();return false, reason end
        end

        for _, part in ipairs(object:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Anchored = true
                part.CanQuery = true
            end
        end

        object:PivotTo(ground.CFrame * pivot)
        object.Parent = objects

        if definition.Plantable then
            local isValid, errorMessage = PlantDataService.loadData(template, object, savedObject)
            if not isValid then
                object:Destroy()
                return false, errorMessage
            end
        end
    end

    return true
end

return PlotDataService
