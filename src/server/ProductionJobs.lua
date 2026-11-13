local ReplicatedStorage = game:GetService("ReplicatedStorage")
local definitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local recipes = require(ReplicatedStorage.Configs.ProductionRecipes)
local active = {}
local Jobs = {}

local function definition(object)
    return definitions[object:GetAttribute("ItemName") or object.Name]
end

function Jobs.IsRunning(object)
    return object:GetAttribute("ProductionPhase") == "Processing"
end

function Jobs.CanWrite(object, recipe)
    local output = object:FindFirstChild("OutputInventory")
    if not output or not output:IsA("Folder") then return false end
    for name, amount in pairs(recipe.Outputs) do
        local value = output:FindFirstChild(name)
        if value and (not value:IsA("IntValue") or value.Value < 0 or value.Value > 9007199254740991 - amount) then return false end
    end
    return true
end

function Jobs.Advance(object)
    if not Jobs.IsRunning(object) then return end
    local now = workspace:GetServerTimeNow()
    if now < object:GetAttribute("ProductionStartedAt") + object:GetAttribute("ProductionDuration") then return end
    local recipe = recipes[object:GetAttribute("ActiveRecipe")]
    if not recipe or not Jobs.CanWrite(object, recipe) then return end
    local output = object.OutputInventory
    for name, amount in pairs(recipe.Outputs) do
        local value = output:FindFirstChild(name)
        if not value then value = Instance.new("IntValue");value.Name = name;value.Parent = output end
        value.Value += amount
    end
    active[object] = nil
    object:SetAttribute("Busy", false)
    object:SetAttribute("ProductionPhase", nil)
    object:SetAttribute("ActiveRecipe", nil)
    object:SetAttribute("ProductionStartedAt", nil)
    object:SetAttribute("ProductionDuration", nil)
end

function Jobs.Start(object, recipeId, remaining)
    local recipe = recipes[recipeId]
    object:SetAttribute("ActiveRecipe", recipeId)
    object:SetAttribute("ProductionStartedAt", workspace:GetServerTimeNow() - (recipe.Duration - (remaining or recipe.Duration)))
    object:SetAttribute("ProductionDuration", recipe.Duration)
    object:SetAttribute("ProductionPhase", "Processing")
    object:SetAttribute("Busy", true)
    active[object] = true
end

function Jobs.Step()
    for object in pairs(active) do
        if not object:IsDescendantOf(workspace) then active[object] = nil
        else Jobs.Advance(object) end
    end
end

function Jobs.Validate(object, saved)
    local item = definition(object)
    if not item or not item.AutomaticProduction then return saved == nil end
    if saved == nil then return true end
    if typeof(saved) ~= "table" then return false end
    local stock = saved.MilkStock
    if typeof(stock) ~= "number" or stock % 1 ~= 0 or stock < 0 or stock > item.MilkTank.Capacity then return false end
    local job = saved.Job
    if job == nil then return true end
    if typeof(job) ~= "table" or not table.find(item.Recipes, job.RecipeId) then return false end
    local recipe = recipes[job.RecipeId]
    return typeof(job.Remaining) == "number" and job.Remaining >= 0 and job.Remaining <= recipe.Duration and
        typeof(job.SavedAt) == "number" and job.SavedAt >= 0 and job.SavedAt <= 9007199254740991 and job.SavedAt % 1 == 0
end

function Jobs.GetData(object)
    local item = definition(object)
    if not item or not item.AutomaticProduction then return end
    Jobs.Advance(object)
    local data = {MilkStock = object:GetAttribute("MilkStock") or 0}
    if Jobs.IsRunning(object) then
        data.Job = {RecipeId = object:GetAttribute("ActiveRecipe"), SavedAt = os.time(),
            Remaining = math.max(0, object:GetAttribute("ProductionStartedAt") + object:GetAttribute("ProductionDuration") - workspace:GetServerTimeNow())}
    end
    if not Jobs.Validate(object, data) then return nil, "Invalid production state" end
    return data
end

function Jobs.Load(object, saved)
    active[object] = nil
    local item = definition(object)
    if not item or not item.AutomaticProduction then return end
    object:SetAttribute("MilkStock", saved and saved.MilkStock or 0)
    if saved and saved.Job then
        local job = saved.Job
        local remaining = math.max(0, job.Remaining - math.max(0, os.time() - job.SavedAt))
        Jobs.Start(object, job.RecipeId, remaining)
        Jobs.Advance(object)
    end
end

return Jobs
