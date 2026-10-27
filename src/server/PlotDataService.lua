local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))

local PlantDataService = require(ServerScriptService:WaitForChild("PlantDataService"))
local ProductionDataService = require(ServerScriptService:WaitForChild("ProductionDataService"))
local PlantService = require(ServerScriptService:WaitForChild("PlantService"))

local models = ReplicatedStorage:WaitForChild("PlaceableModels")
local plants = ReplicatedStorage:WaitForChild("Plants")
local plots = workspace:WaitForChild("Plots")

local PlotDataService = {}

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
            local outputData, outputError = ProductionDataService.getData(object)
            if not outputData then
                return nil, outputError
            end
            savedObject.OutputInventory = outputData
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
        if typeof(savedObject) ~= "table" or typeof(savedObject.ItemName) ~= "string" then
            return false, "Invalid saved object"
        end

        local definition = ItemDefinitions[savedObject.ItemName]
        local template = models:FindFirstChild(savedObject.ItemName)

        if not definition or definition.Placeable ~= true or not template or not template:IsA("Model") then
            return false, "Missing definition or model: " .. savedObject.ItemName
        end

        local pivot = savedObject.Pivot

        if typeof(pivot) ~= "table" or #pivot ~= 12 then
            return false, "Invalid saved pivot"
        end

        for _, value in ipairs(pivot) do
            if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
                return false, "Invalid saved pivot"
            end
        end

        local object = template:Clone()

        object:SetAttribute("OwnerUserId", player.UserId)
        object:SetAttribute("ItemName", savedObject.ItemName)

        if definition.Recipes then
            local success, errorMessage = ProductionDataService.loadData(object, savedObject)
            if not success then
                object:Destroy()
                return false, errorMessage
            end
        end

        for _, part in ipairs(object:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Anchored = true
                part.CanQuery = true
            end
        end

        object:PivotTo(ground.CFrame * CFrame.new(table.unpack(pivot)))
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
