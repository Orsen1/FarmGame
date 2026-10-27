local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local configs = ReplicatedStorage:WaitForChild("Configs")

local ItemDefinitions = require(configs:WaitForChild("ItemDefinitions"))
local ProductionRecipes = require(configs:WaitForChild("ProductionRecipes"))
local InventoryService = require(ServerScriptService:WaitForChild("InventoryService"))

local plots = workspace:WaitForChild("Plots")

local ProductionService = {}

local activeStations = {}
local activePlayers = {}

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
        next(recipe.Outputs) == nil or typeof(recipe.Duration) ~= "number" or recipe.Duration ~= recipe.Duration or
        recipe.Duration < 0 or recipe.Duration == math.huge then
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

function ProductionService.Start(player, station, recipeId)
    if typeof(station) ~= "Instance" or not station:IsA("Model") or typeof(recipeId) ~= "string" then
        return false, "Invalid station or recipe"
    end

    local allowed, reason = canUse(player, station)

    if not allowed then
        return false, reason
    end

    if activeStations[station] then
        return false, "Station is busy"
    end

    if activePlayers[player] then
        return false, "You are already working at a station"
    end

    local recipe, recipeError = getRecipe(station, recipeId)

    if not recipe then
        return false, recipeError
    end

    local canExchange, exchangeError = InventoryService.CanExchangeItems(player, recipe.Inputs, {}) -- now we dont need that for handmill

    if not canExchange then
        return false, exchangeError
    end

    activeStations[station] = true
    activePlayers[player] = true

    station:SetAttribute("Busy", true)
    station:SetAttribute("ActiveRecipe", recipeId)

    local ran, success, message = xpcall(function()
        local deadline = os.clock() + recipe.Duration

        while os.clock() < deadline do
            task.wait(math.max(0, math.min(0.25, deadline - os.clock())))

            local stillAllowed, cancelReason = canUse(player, station)

            if not stillAllowed then
                return false, cancelReason
            end
        end

        local stillAllowed, cancelReason = canUse(player, station)

        if not stillAllowed then
            return false, cancelReason
        end

        local outputInventory = station:FindFirstChild("OutputInventory")

        if not outputInventory or not outputInventory:IsA("Folder") then
            return false, "OutputInventory is missing"
        end

        for itemName, amount in pairs(recipe.Outputs) do
            if typeof(amount) ~= "number" or amount < 1 or amount % 1 ~= 0 then
                return false, "Invalid output amount"
            end

            local storedItem = outputInventory:FindFirstChild(itemName)

            if storedItem and not storedItem:IsA("IntValue") then
                return false, "Invalid output item: " .. itemName
            end
        end

        local removed, removeError = InventoryService.ExchangeItems(player, recipe.Inputs, {})

        if not removed then
            return false, removeError
        end

        for itemName, amount in pairs(recipe.Outputs) do
            local storedItem = outputInventory:FindFirstChild(itemName)

            if not storedItem then
                storedItem = Instance.new("IntValue")
                storedItem.Name = itemName
                storedItem.Value = 0
                storedItem.Parent = outputInventory
            end

            storedItem.Value = storedItem.Value + amount
        end

        return true
    end, debug.traceback)

    activeStations[station] = nil
    activePlayers[player] = nil

    if station.Parent then
        station:SetAttribute("Busy", false)
        station:SetAttribute("ActiveRecipe", nil)
    end

    if not ran then
        warn("[PRODUCTION ERROR]", success)
        return false, "Production failed unexpectedly"
    end

    if not success then
        return false, message
    end

    return true, "Production completed"
end

function ProductionService.Collect(player, station)
    if typeof(station) ~= "Instance" or not station:IsA("Model") then
        return false, "Invalid station"
    end

    local allowed, reason = canUse(player, station)

    if not allowed then
        return false, reason
    end

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

            outputs[storedItem.Name] =
                (outputs[storedItem.Name] or 0) + storedItem.Value

            table.insert(storedItems, storedItem)
        end
    end

    if next(outputs) == nil then
        return false, "Nothing to collect"
    end

    local added, addError = InventoryService.ExchangeItems(
        player,
        {},
        outputs
    )

    if not added then
        return false, addError
    end

    for _, storedItem in ipairs(storedItems) do
        storedItem.Value = 0
    end

    return true, "Items collected"
end

return ProductionService
