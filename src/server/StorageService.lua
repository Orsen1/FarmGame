local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local MoneyService = require(script.Parent.MoneyService)
local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))
local PlacementModels = require(ReplicatedStorage.PlacementScripts.PlacementModels)
local ConstructionService = require(script.Parent.ConstructionService)
local WarehouseSite = require(script.Parent.WarehouseSite)
local stages = require(ReplicatedStorage.Configs.ConstructionDefinitions).WarehouseBlueprint.Stages

local plots = workspace:WaitForChild("Plots")
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

local StorageService = {}
local returns = {}
local sessions = {}
local revisions = {}
local pageSize = ItemDefinitions.Warehouse.StorageSlots
local blueprintPrice = ItemDefinitions.WarehouseBlueprint.SitePriceCents

local storageEvent = remotes:FindFirstChild("StorageEvent")

if not storageEvent then
    storageEvent = Instance.new("RemoteEvent")
    storageEvent.Name = "StorageEvent"
    storageEvent.Parent = remotes
end

local function isInteger(value, minimum, maximum)
    return typeof(value) == "number" and value % 1 == 0 and value >= minimum and value <= maximum
end

local function getCapacity(object)
    local itemName = object:GetAttribute("ItemName") or object.Name
    local definition = ItemDefinitions[itemName]
    local count = definition and definition.StorageSlots

    if isInteger(count, 1, 120) then
        return count
    end
end

local function getInventory(object)
    local count = getCapacity(object)

    if not count then
        return nil, "This object has no storage"
    end

    local folder = object:FindFirstChild("StorageInventory")

    if folder then
        if not folder:IsA("Folder") then
            return nil, "Invalid StorageInventory"
        end

        return folder, count
    end

    folder = Instance.new("Folder")
    folder.Name = "StorageInventory"

    InventoryService.CreateSlots(folder, count)

    folder.Parent = object

    return folder, count
end

function StorageService.getData(object)
    local folder, count = getInventory(object)

    if not folder then
        return nil, count
    end

    if #folder:GetChildren() ~= count then
        return nil, "Invalid storage slot count"
    end

    local data = {}

    for index = 1, count do
        local slot = folder:FindFirstChild("Slot" .. index)
        local name = slot and slot:FindFirstChild("ItemName")
        local amount = slot and slot:FindFirstChild("Amount")

        if not slot or not slot:IsA("Folder") or not name or not name:IsA("StringValue") or not amount or
            not amount:IsA("IntValue") then
            return nil, "Invalid storage slot"
        end

        local row = {
            ItemName = name.Value,
            Amount = amount.Value,
            ObjectData = slot:GetAttribute("ObjectData")
        }

        if not InventoryService.IsValidObjectRow(row) then
            return nil, "Invalid stored item"
        end

        data[index] = row
    end

    return data
end

function StorageService.ValidRows(data, count)
    if typeof(data) ~= "table" or not count then
        return false
    end

    for index, row in pairs(data) do
        if not isInteger(index, 1, count) or not InventoryService.IsValidObjectRow(row) then
            return false
        end
    end
    return true
end

function StorageService.loadData(object, savedObject)
    local data = savedObject.StorageInventory
    if data == nil then data = {} end
    if not StorageService.ValidRows(data, getCapacity(object)) then
        return false, "Invalid saved storage"
    end

    local rows, reason = StorageService.getData(object)

    if not rows then
        return false, reason
    end

    local folder = object.StorageInventory

    for index = 1, #rows do
        local row = data[index] or {
            ItemName = "",
            Amount = 0
        }

        local slot = folder:FindFirstChild("Slot" .. index)
        slot.ItemName.Value = row.ItemName
        slot.Amount.Value = row.Amount
        slot:SetAttribute("ObjectData", row.ObjectData)
    end

    return true
end

local function prepareBuilding(player, plot, saved)
    local ready = saved.Stage == #stages
    local itemName = ready and "Warehouse" or "WarehouseBlueprint"
    local building = PlacementModels.getTemplate(itemName, saved.Stage):Clone()
    building.Name = itemName
    building:SetAttribute("ItemName", itemName)
    building:SetAttribute("OwnerUserId", player.UserId)
    local valid, reason
    if ready then
        valid, reason = StorageService.loadData(building, saved)
    else
        building:SetAttribute("ConstructionStage", saved.Stage)
        valid, reason = ConstructionService.loadData(building, saved.ConstructionDeposits)
    end
    if not valid then building:Destroy();return nil, reason end

    WarehouseSite.PrepareBuilding(building, ready)
    building:PivotTo(WarehouseSite.GetPivot(plot))
    return building
end

function StorageService.Load(player, plot, saved, savedReturns)
    if WarehouseSite.GetBuilding(plot) then return false, "Warehouse already exists" end
    if saved == nil then saved = {Stage = -1} end
    if typeof(saved) ~= "table" or not isInteger(saved.Stage, -1, #stages) then
        return false, "Invalid warehouse stage"
    end
    if savedReturns == nil then savedReturns = {} end
    if typeof(savedReturns) ~= "table" or not StorageService.ValidRows(savedReturns, #savedReturns) then
        return false, "Invalid warehouse returns"
    end
    for index = 1, #savedReturns do
        if not savedReturns[index] or savedReturns[index].Amount == 0 then
            return false, "Incomplete warehouse returns"
        end
    end

    local stage = saved.Stage
    local deposits = saved.ConstructionDeposits
    local emptyStage = stage == 0 and saved.Purchased ~= true and
        (deposits == nil or (typeof(deposits) == "table" and next(deposits) == nil))
    local site = WarehouseSite.Ensure(plot)
    if stage >= 0 and not emptyStage then
        local building, reason = prepareBuilding(player, plot, saved)
        if not building then return false, reason end
        building.Parent = site
    end
    returns[player] = table.clone(savedReturns)
    revisions[player] = 0
    player:SetAttribute("StorageReturnCount", #savedReturns)
    WarehouseSite.SetMarkerOwner(plot, WarehouseSite.GetBuilding(plot) and 0 or player.UserId)
    return true
end

function StorageService.Snapshot(player, plot)
    local object = WarehouseSite.GetBuilding(plot)
    if plot:GetAttribute("OwnerUserId") ~= player.UserId or not returns[player] or
        (object and object:GetAttribute("OwnerUserId") ~= player.UserId) then
        return nil, "Warehouse is not ready"
    end
    if not object then
        return {Stage = -1}, table.clone(returns[player])
    end
    if getCapacity(object) then
        local data, reason = StorageService.getData(object)
        if not data then return nil, reason end
        return {Stage = #stages, StorageInventory = data}, table.clone(returns[player])
    end
    local deposits, reason = ConstructionService.getData(object)
    if not deposits then return nil, reason end
    return {Stage = object:GetAttribute("ConstructionStage"), Purchased = true, ConstructionDeposits = deposits},
        table.clone(returns[player])
end

function StorageService.Clear(player)
    sessions[player], returns[player], revisions[player] = nil, nil, nil
end

local function canAccess(player, object, prompt)
    if player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("ProductionMode") or
        player:GetAttribute("Milking") or player:GetAttribute("Teleporting") or not returns[player] then
        return false
    end

    local plotName = player:GetAttribute("PlotName")
    local plot = plotName and plots:FindFirstChild(plotName)

    local site = plot and plot:FindFirstChild("WarehouseSite")
    if not site or not object or plot:GetAttribute("OwnerUserId") ~= player.UserId or
        object:GetAttribute("OwnerUserId") ~= player.UserId then
        return false
    end
    local building = WarehouseSite.GetBuilding(plot)
    if object ~= (building or site.WarehouseMarker) then
        return false
    end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not root or not humanoid or humanoid.Health <= 0 then
        return false
    end

    if prompt then
        local attachment = prompt.Parent
        if prompt.Enabled and prompt:IsDescendantOf(object) and attachment and attachment:IsA("Attachment") and
            (root.Position - attachment.WorldPosition).Magnitude <= prompt.MaxActivationDistance then
            return true, plot
        end
        return false
    end
    return getCapacity(object) ~= nil
end

function StorageService.BuyBlueprint(player, prompt)
    local marker = prompt:FindFirstAncestorOfClass("Model")
    local allowed, plot = canAccess(player, marker, prompt)
    if not allowed or marker ~= plot.WarehouseSite.WarehouseMarker or WarehouseSite.GetBuilding(plot) then
        return false
    end
    local building, reason = prepareBuilding(player, plot, {Stage = 0})
    if not building then return false, reason end
    if not MoneyService.RemoveMoney(player, blueprintPrice) then
        building:Destroy()
        return false, string.format("You need $%.2f", blueprintPrice / 100)
    end
    building.Parent = plot.WarehouseSite
    WarehouseSite.SetMarkerOwner(plot, 0)
    return true
end

function StorageService.MoveSlot(player, object, fromArea, toArea, fromIndex, toIndex, expectedFrom, expectedTo)
    local session = sessions[player]
    if (fromArea ~= "Player" and fromArea ~= "Storage") or (toArea ~= "Player" and toArea ~= "Storage") or not session or
        session.Object ~= object or not session.Ready or not canAccess(player, object, session.Prompt) then
        return false, "Storage is not available"
    end

    local folder, count = getInventory(object)

    if not folder then
        return false, count
    end

    local fromFolder = fromArea == "Storage" and folder or player:FindFirstChild("Inventory")

    local toFolder = toArea == "Storage" and folder or player:FindFirstChild("Inventory")

    return InventoryService.MoveBetweenSlots(fromFolder, fromArea == "Storage" and count or 6, toFolder,
        toArea == "Storage" and count or 6, fromIndex, toIndex, expectedFrom, expectedTo)
end

local function returnPage(player, page)
    local items = returns[player]
    local pages = math.max(1, math.ceil(#items / pageSize))
    page = math.clamp(page, 1, pages)
    local rows = {}
    for i = (page - 1) * pageSize + 1, math.min(page * pageSize, #items) do
        local row = items[i]
        table.insert(rows, {ItemName = row.ItemName, Amount = row.Amount})
    end
    return {Page = page, Pages = pages, Rows = rows, Revision = revisions[player]}
end

function StorageService.Open(player, object, prompt)
    if not canAccess(player, object, prompt) then return end
    local ready = getCapacity(object) ~= nil
    if not ready and #returns[player] == 0 then return end
    if ready and not StorageService.getData(object) then return end
    sessions[player] = {Object = object, Prompt = prompt, Ready = ready}
    storageEvent:FireClient(player, "Open", object, prompt, ready, returnPage(player, 1))
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
    if prompt.Name == "StoragePrompt" or prompt.Name == "ReturnsPrompt" then
        StorageService.Open(player, prompt:FindFirstAncestorOfClass("Model"), prompt)
    elseif prompt.Name == "WarehouseBuyPrompt" then
        local success, message = StorageService.BuyBlueprint(player, prompt)
        if not success and message then
            remotes.AnimalFeedback:FireClient(player, prompt:FindFirstAncestorOfClass("Model"), false, message, prompt.Name)
        end
    end
end)

storageEvent.OnServerEvent:Connect(function(player, action, page, slot, revision)
    local session = sessions[player]
    if action == "Close" then sessions[player] = nil;return end
    if not session or not canAccess(player, session.Object, session.Prompt) or
        not isInteger(page, 1, math.max(1, math.ceil(#returns[player] / pageSize))) then
        return
    end

    local message
    if action == "Take" then
        if revision ~= revisions[player] or not isInteger(slot, 1, pageSize) then return end
        local index = (page - 1) * pageSize + slot
        local row = returns[player][index]
        if not row then return end
        local added
        if row.ObjectData then
            added = InventoryService.ExchangeForObject(player, {}, row.ItemName, row.ObjectData)
        else
            added = InventoryService.AddItem(player, row.ItemName, row.Amount)
        end
        if added then
            table.remove(returns[player], index)
            revisions[player] += 1
            player:SetAttribute("StorageReturnCount", #returns[player])
        else
            message = "Make room in your inventory to take this item."
        end
    elseif action ~= "Page" then
        return
    end
    storageEvent:FireClient(player, "Page", session.Object, returnPage(player, page), message)
end)

return StorageService
