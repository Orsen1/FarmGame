local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local EquipmentService = require(ServerScriptService:WaitForChild("Equipment"):WaitForChild("EquipmentService"))

local setSelectedSlotEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("SetSelectedSlotEvent")

local watched = {}

setSelectedSlotEvent.OnServerEvent:Connect(function(player, slotNumber)

    if typeof(slotNumber) ~= "number" then
        return
    end

    if slotNumber < 1 or slotNumber > 6 then
        return
    end

    player:SetAttribute("SelectedSlot", slotNumber)
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