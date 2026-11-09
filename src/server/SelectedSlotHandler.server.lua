local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local EquipmentService = require(ServerScriptService:WaitForChild("Equipment"):WaitForChild("EquipmentService"))
local InventoryService = require(ServerScriptService:WaitForChild("InventoryService"))
local storageModule = ServerScriptService:FindFirstChild("StorageService")
local StorageService = storageModule and require(storageModule)

local moveInventorySlotEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("MoveInventorySlotEvent")
local setSelectedSlotEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("SetSelectedSlotEvent")

local watched = {}

setSelectedSlotEvent.OnServerEvent:Connect(function(player, slotNumber)

    if typeof(slotNumber) ~= "number" then
        return
    end

    if slotNumber < 1 or slotNumber > 6 or slotNumber % 1 ~= 0 then
        return
    end

    player:SetAttribute("SelectedSlot", slotNumber)
end)

moveInventorySlotEvent.OnServerEvent:Connect(function(player, fromIndex, toIndex, expectedFrom, expectedTo, fromArea,
    toArea, storageObject)
    if player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("ProductionMode") == true then
        moveInventorySlotEvent:FireClient(player, false, "Inventory is not available")
        return
    end

    fromArea = fromArea or "Player"
    toArea = toArea or "Player"

    local success, reason

    if fromArea == "Player" and toArea == "Player" then
        success, reason = InventoryService.MoveSlot(player, fromIndex, toIndex, expectedFrom, expectedTo)
    elseif StorageService then
        success, reason = StorageService.MoveSlot(player, storageObject, fromArea, toArea, fromIndex, toIndex,
            expectedFrom, expectedTo)
    else
        success, reason = false, "Storage is not available"
    end

    moveInventorySlotEvent:FireClient(player, success, reason)
end)

local function bindPlayer(player)
    if watched[player] then
        return
    end

    watched[player] = true

    local function update()
        EquipmentService.update(player)
    end

    player:GetAttributeChangedSignal("SelectedSlot"):Connect(update)
    player:GetAttributeChangedSignal("DataLoaded"):Connect(update)

    player.CharacterAdded:Connect(function(character)
        character:WaitForChild("Humanoid", 10)

        if player.Character == character then
            update()
        end
    end)

    local inventory = player:WaitForChild("Inventory", 30)

    if not inventory then
        return
    end

    for i = 1, 6 do
        local slot = inventory:WaitForChild("Slot" .. i)

        slot:WaitForChild("ItemName").Changed:Connect(update)
        slot:WaitForChild("Amount").Changed:Connect(update)
    end

    update()
end

Players.PlayerAdded:Connect(bindPlayer)

Players.PlayerRemoving:Connect(function(player)
    watched[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(bindPlayer, player)
end
