local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local configs = ReplicatedStorage:WaitForChild("Configs")

local ItemDefinitions = require(configs:WaitForChild("ItemDefinitions"))
local ConstructionDefinitions = require(configs:WaitForChild("ConstructionDefinitions"))
local InventoryService = require(ServerScriptService:WaitForChild("InventoryService"))
local PlacementModels = require(ReplicatedStorage:WaitForChild("PlacementScripts"):WaitForChild("PlacementModels"))

local ConstructionService = {}

function ConstructionService.Build(player, object)
    if player:GetAttribute("DataLoaded") ~= true or object:GetAttribute("OwnerUserId") ~= player.UserId or
        not object:IsDescendantOf(workspace) then
        return false, "Construction is not available"
    end

    local itemName = object:GetAttribute("ItemName") or object.Name
    local definition = ItemDefinitions[itemName]
    local construction = ConstructionDefinitions[itemName]

    if not definition or not definition.BuildsInto or not construction or not construction.Stages then
        return false, "Missing construction definition"
    end

    local stage = object:GetAttribute("ConstructionStage")

    if stage == nil then
        stage = 0
    end

    if typeof(stage) ~= "number" or stage % 1 ~= 0 or stage < 0 or stage >= #construction.Stages then
        return false, "Invalid construction stage"
    end

    local nextStage = stage + 1
    local step = construction.Stages[nextStage]
    local isComplete = nextStage == #construction.Stages

    local nextItemName = isComplete and definition.BuildsInto or itemName
    local nextDefinition = ItemDefinitions[nextItemName]

    if not nextDefinition or nextDefinition.Placeable ~= true or (isComplete and nextDefinition.BuildsInto) then
        return false, "Invalid construction result"
    end

    local template

    if isComplete then
        template = PlacementModels.getTemplate(nextItemName)
    else
        template = PlacementModels.getTemplate(itemName, nextStage)
    end

    if not template then
        return false, "Missing model for the next construction stage"
    end

    local prompt = template:FindFirstChild("ActionPrompt", true)

    if not prompt or not prompt:IsA("ProximityPrompt") then
        return false, "ActionPrompt is missing in " .. template.Name
    end

    local nextObject = template:Clone()
    nextObject.Name = nextItemName

    nextObject:SetAttribute("ItemName", nextItemName)
    nextObject:SetAttribute("OwnerUserId", player.UserId)

    if isComplete then
        nextObject:SetAttribute("ConstructionStage", nil)
    else
        nextObject:SetAttribute("ConstructionStage", nextStage)
    end

    for _, part in ipairs(nextObject:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanQuery = true
        end
    end

    nextObject:PivotTo(object:GetPivot())

    local removed, reason = InventoryService.ExchangeItems(player, step.Inputs, {})

    if not removed then
        nextObject:Destroy()
        return false, reason
    end

    nextObject.Parent = object.Parent
    object:Destroy()

    return true, isComplete and "Construction completed" or step.DisplayName
end

return ConstructionService
