local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))

local plots = workspace:WaitForChild("Plots")
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

local StorageService = {}

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

function StorageService.loadData(object, savedObject)
    local count = getCapacity(object)

    if not count then
        return false, "This object has no storage"
    end

    local data = savedObject.StorageInventory

    if data == nil then
        data = {}
    end

    if typeof(data) ~= "table" then
        return false, "Invalid saved storage"
    end

    for index, row in pairs(data) do
        if not isInteger(index, 1, count) or not InventoryService.IsValidObjectRow(row) then
            return false, "Invalid saved storage slot"
        end
    end

    local rows, reason = StorageService.getData(object)

    if not rows then
        return false, reason
    end

    local folder = object.StorageInventory

    for index = 1, count do
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

function StorageService.CanUse(player, object)
    if player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("ProductionMode") ==
        true or typeof(object) ~= "Instance" or not object:IsA("Model") then
        return false
    end

    local plotName = player:GetAttribute("PlotName")
    local plot = plotName and plots:FindFirstChild(plotName)
    local objects = plot and plot:FindFirstChild("PlacedObjects")

    if not objects or object.Parent ~= objects or plot:GetAttribute("OwnerUserId") ~= player.UserId or
        object:GetAttribute("OwnerUserId") ~= player.UserId or not getCapacity(object) then
        return false
    end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not root or not humanoid or humanoid.Health <= 0 then
        return false
    end

    for _, prompt in ipairs(object:GetDescendants()) do
        local attachment = prompt.Parent

        if prompt:IsA("ProximityPrompt") and prompt.Name == "StoragePrompt" and attachment and
            attachment:IsA("Attachment") then

            local distance = (root.Position - attachment.WorldPosition).Magnitude

            if distance == distance and distance <= prompt.MaxActivationDistance then
                return true
            end
        end
    end

    return false
end

function StorageService.MoveSlot(player, object, fromArea, toArea, fromIndex, toIndex, expectedFrom, expectedTo)
    if (fromArea ~= "Player" and fromArea ~= "Storage") or (toArea ~= "Player" and toArea ~= "Storage") or
        not StorageService.CanUse(player, object) then
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

storageEvent.OnServerEvent:Connect(function(player, object)
    if not StorageService.CanUse(player, object) then
        storageEvent:FireClient(player, object, false, "Storage is not available")
        return
    end

    local data, reason = StorageService.getData(object)

    storageEvent:FireClient(player, object, data ~= nil, reason)
end)

return StorageService
