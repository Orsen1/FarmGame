local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))
local plots = workspace:WaitForChild("Plots")
local AnimalConfig = require(ReplicatedStorage.Configs.AnimalConfig)
local services = script.Parent.Parent
local AnimalService = require(services.AnimalService)
local PlantService = require(services.PlantService)
local ProductionService = require(services.ProductionService)
local ProductionDataService = require(services.ProductionDataService)
local StorageService = require(services.StorageService)
local InventoryService = require(services.InventoryService)
local MoneyService = require(services.MoneyService)
local Laboratory = require(services.LaboratoryService)
local Journal = require(services.FarmJournalService)
local refundPercent = require(ReplicatedStorage.Configs.ConstructionDefinitions).DemolitionRefundPercent
local MAX_DISTANCE = 12

local ObjectRemovalService = {}

local function contents(object, itemName, definition)
    if AnimalConfig.Coops[itemName] then return AnimalService.GetReturns(object) end
    if definition.Recipes then return ProductionDataService.GetReturns(object) end
    if definition.Plantable then return PlantService.GetReturns(object) end
    return {}
end

function ObjectRemovalService.remove(player, object)
    if player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("Teleporting") then
        return false, "Player data is not ready."
    end

    if typeof(object) ~= "Instance" or not object:IsA("Model") then
        return false, "Object no longer exists."
    end

    local plotName = player:GetAttribute("PlotName")
    local plot = plotName and plots:FindFirstChild(plotName)
    local objects = plot and plot:FindFirstChild("PlacedObjects")

    if not plot or not objects or plot:GetAttribute("OwnerUserId") ~= player.UserId or object.Parent ~= objects or
        object:GetAttribute("OwnerUserId") ~= player.UserId then
        return false, "You can only remove objects on your own farm."
    end

    local itemName = object:GetAttribute("ItemName") or object.Name
    local definition = ItemDefinitions[itemName]

    if not definition or definition.Placeable ~= true or definition.FixedWarehouse then
        return false, "This object cannot be removed."
    end
    if definition.BuildsInto then return false, "Finish building before removing it." end

    if not Journal.TutorialComplete(player) then return false, "Finish your first harvest before removing the bed." end

    local character = player.Character
    local tool = character and character:FindFirstChild("EquippedItem")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")

    local inventory = player:FindFirstChild("Inventory")
    local slotNumber = player:GetAttribute("SelectedSlot") or 1
    local slot = inventory and inventory:FindFirstChild("Slot" .. slotNumber)

    if not tool or not tool:IsA("Tool") or tool:GetAttribute("ItemName") ~= "Shovel" or not slot or slot.ItemName.Value ~=
        "Shovel" or slot.Amount.Value <= 0 then
        return false, "Equip your shovel first."
    end

    if not humanoid or humanoid.Health <= 0 or not root then
        return false, "Your character is not ready."
    end

    local prompt = object:FindFirstChild("ActionPrompt", true)
    local attachment = prompt and prompt.Parent

    if not prompt or not prompt:IsA("ProximityPrompt") or not attachment or not attachment:IsA("Attachment") then
        return false, "The removal prompt is missing."
    end

    local distance = (root.Position - attachment.WorldPosition).Magnitude

    if distance ~= distance or distance > MAX_DISTANCE then
        return false, "Move closer to the object."
    end

    local paid = object:GetAttribute("PurchaseCents") or 0
    if not InventoryService.IsPurchaseCost(paid) then return false, "The recorded purchase cost is invalid." end
    local refund = math.floor(paid / 100) * refundPercent + math.floor((paid % 100) * refundPercent / 100)
    if refund > 0 and not MoneyService.CanAddMoney(player, refund) then
        return false, "Your balance cannot accept the refund."
    end

    local rows, reason = contents(object, itemName, definition)
    if not rows then return false, reason or "The contents could not be recovered." end
    local plan = StorageService.PlanReturns(player, rows)
    if not plan then return false, "Your items could not be returned. Try again." end

    if definition.Recipes then ProductionService.CloseStation(object) end
    if AnimalConfig.Coops[itemName] then AnimalService.CancelWorkAt(player, object) end
    if definition.Laboratory then Laboratory.Close(player) end
    StorageService.CommitReturns(player, plan)
    if refund > 0 then MoneyService.AddMoney(player, refund) end
    object:Destroy()
    Journal.Update(player)

    return true, refund > 0 and string.format("Removed. Refunded $%.2f.", refund / 100) or "Object removed."
end

return ObjectRemovalService
