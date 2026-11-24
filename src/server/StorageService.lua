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
local lastSessionId = 0
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

local function warehouseReady(object)
    return object:GetAttribute("ItemName") == "Warehouse"
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

local function prepareBuilding(player, plot, saved)
    local ready = saved.Stage == #stages
    local itemName = ready and "Warehouse" or "WarehouseBlueprint"
    local building = PlacementModels.getTemplate(itemName, saved.Stage):Clone()
    building.Name = itemName
    building:SetAttribute("ItemName", itemName)
    building:SetAttribute("OwnerUserId", player.UserId)
    if not ready then
        building:SetAttribute("ConstructionStage", saved.Stage)
        local valid, reason = ConstructionService.loadData(building, saved.ConstructionDeposits)
        if not valid then building:Destroy();return nil, reason end
    end

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
    local stock = saved.StorageInventory
    if stock == nil then stock = {} end
    if not StorageService.ValidRows(stock, pageSize) or (stage ~= #stages and next(stock)) then
        return false, "Invalid saved storage"
    end
    local deposits = saved.ConstructionDeposits
    local emptyStage = stage == 0 and saved.Purchased ~= true and
        (deposits == nil or (typeof(deposits) == "table" and next(deposits) == nil))
    local site = WarehouseSite.Ensure(plot)
    if stage >= 0 and not emptyStage then
        local building, reason = prepareBuilding(player, plot, saved)
        if not building then return false, reason end
        building.Parent = site
    end
    local folder = player:FindFirstChild("StorageInventory")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "StorageInventory"
        InventoryService.CreateSlots(folder, pageSize)
    end
    local rows = {}
    for index = 1, pageSize do
        rows[index] = stock[index] or {ItemName = "", Amount = 0}
    end
    InventoryService.WriteSlots(folder, rows)
    folder.Parent = player
    returns[player] = table.clone(savedReturns)
    revisions[player] = 0
    player:SetAttribute("WarehouseReady", stage == #stages)
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
    if warehouseReady(object) then
        local data = InventoryService.ReadSlots(player:FindFirstChild("StorageInventory"), pageSize)
        if not data then return nil, "Invalid warehouse inventory" end
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

local function ownedPlot(player)
    local plot = plots:FindFirstChild(player:GetAttribute("PlotName") or "")
    if plot and plot:GetAttribute("OwnerUserId") == player.UserId then return plot end
end

local function currentObject(plot)
    local site = plot and plot:FindFirstChild("WarehouseSite")
    return site and (WarehouseSite.GetBuilding(plot) or site:FindFirstChild("WarehouseMarker"))
end

local function canAccess(player, object, prompt)
    if player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("ProductionMode") or
        player:GetAttribute("Milking") or player:GetAttribute("Teleporting") or not returns[player] then
        return false
    end

    local plot = ownedPlot(player)
    if not object or object ~= currentObject(plot) or object:GetAttribute("OwnerUserId") ~= player.UserId then
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
    return true, plot
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

function StorageService.MoveSlot(player, sessionId, fromArea, toArea, fromIndex, toIndex, expectedFrom, expectedTo)
    local session = sessions[player]
    if (fromArea ~= "Player" and fromArea ~= "Storage") or (toArea ~= "Player" and toArea ~= "Storage") or not session or
        session.Id ~= sessionId or not session.Ready or not canAccess(player, session.Object, session.Prompt) then
        return false, "Storage is not available"
    end

    local folder = player:FindFirstChild("StorageInventory")

    local fromFolder = fromArea == "Storage" and folder or player:FindFirstChild("Inventory")

    local toFolder = toArea == "Storage" and folder or player:FindFirstChild("Inventory")

    return InventoryService.MoveBetweenSlots(fromFolder, fromArea == "Storage" and pageSize or 6, toFolder,
        toArea == "Storage" and pageSize or 6, fromIndex, toIndex, expectedFrom, expectedTo)
end

function StorageService.CountReturns(player, matches)
    local count = 0
    for _, row in ipairs(returns[player] or {}) do
        if matches(row.ItemName) then count += row.Amount end
    end
    return count
end

function StorageService.PlanReturns(player, rows)
    if not returns[player] or player:GetAttribute("DataLoaded") ~= true then return nil end
    local warehouse = currentObject(ownedPlot(player))
    local inventory = InventoryService.GetInventory(player)
    if not inventory or not warehouse or warehouse:GetAttribute("OwnerUserId") ~= player.UserId then return nil end
    local storage
    if warehouseReady(warehouse) then
        storage = InventoryService.ReadSlots(player:FindFirstChild("StorageInventory"), pageSize)
        if not storage then return nil end
    end

    local overflow = table.clone(returns[player])
    for _, source in ipairs(rows) do
        if not InventoryService.IsValidObjectRow(source) or source.Amount < 1 then return nil end
        local row = table.clone(source)
        if storage then InventoryService.ReceiveInto(storage, row, row.Amount) end
        if row.Amount > 0 then InventoryService.ReceiveInto(inventory, row, row.Amount) end
        if row.Amount > 0 then table.insert(overflow, row) end
    end
    return {Storage = storage, Inventory = inventory, Overflow = overflow}
end

function StorageService.CommitReturns(player, plan)
    if plan.Storage then InventoryService.WriteSlots(player.StorageInventory, plan.Storage) end
    InventoryService.WriteSlots(player.Inventory, plan.Inventory)
    if #plan.Overflow > #returns[player] then
        returns[player] = plan.Overflow
        revisions[player] += 1
        player:SetAttribute("StorageReturnCount", #plan.Overflow)
    end
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

function StorageService.Open(player, prompt)
    local object = currentObject(ownedPlot(player))
    if not canAccess(player, object, prompt) then return end
    local ready = warehouseReady(object)
    if not ready and #returns[player] == 0 then return end
    lastSessionId += 1
    sessions[player] = {Id = lastSessionId, Object = object, Prompt = prompt, Ready = ready}
    storageEvent:FireClient(player, "Open", lastSessionId, prompt, ready, returnPage(player, 1),
        object.Name == "WarehouseMarker")
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
    if prompt.Name == "StoragePrompt" or prompt.Name == "ReturnsPrompt" then
        StorageService.Open(player, prompt)
    elseif prompt.Name == "WarehouseBuyPrompt" then
        local success, message = StorageService.BuyBlueprint(player, prompt)
        if not success and message then
            remotes.AnimalFeedback:FireClient(player, prompt:FindFirstAncestorOfClass("Model"), false, message, prompt.Name)
        end
    end
end)

local function takeReturn(player, session, index, revision, amount, destination)
    local items = returns[player]
    local row = items[index]
    if revision ~= revisions[player] or not row then return 0, "Returns changed. Choose the item again." end
    if not isInteger(amount, 1, row.Amount) then return 0, "Choose a valid amount." end
    local toStorage = destination == "Storage"
    if toStorage and not session.Ready then return 0, "Finish building your warehouse first." end
    if not toStorage and destination ~= "Player" then return 0, "Choose a destination." end

    local folder = player:FindFirstChild(toStorage and "StorageInventory" or "Inventory")
    local remaining = table.clone(row)
    local moved = InventoryService.ReceiveRow(folder, toStorage and pageSize or 6, remaining, amount)
    local name = toStorage and "storage" or "inventory"
    if moved == 0 then return 0, "Make room in your " .. name .. "." end

    if remaining.Amount == 0 then
        table.remove(items, index)
    else
        items[index] = remaining
    end
    revisions[player] += 1
    player:SetAttribute("StorageReturnCount", #items)
    return moved, string.format("Moved %d to %s.", moved, name)
end

storageEvent.OnServerEvent:Connect(function(player, action, sessionId, page, slot, revision, amount, destination)
    if action == "OpenHud" then StorageService.Open(player);return end
    local session = sessions[player]
    if not session or session.Id ~= sessionId then return end
    if action == "Close" then sessions[player] = nil;return end
    if not canAccess(player, session.Object, session.Prompt) then
        sessions[player] = nil
        storageEvent:FireClient(player, "Closed", sessionId)
        return
    end
    if action ~= "Page" and action ~= "Take" then return end

    local moved, message
    if not isInteger(page, 1, math.max(1, math.ceil(#returns[player] / pageSize))) then
        page, moved, message = 1, 0, "Returns changed. Choose the item again."
    elseif action == "Take" and isInteger(slot, 1, pageSize) then
        moved, message = takeReturn(player, session, (page - 1) * pageSize + slot, revision, amount, destination)
    end
    storageEvent:FireClient(player, "Page", sessionId, returnPage(player, page), message, moved)
end)

return StorageService
