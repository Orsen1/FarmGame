local ReplicatedStorage = game:GetService("ReplicatedStorage")

local setSelectedSlotEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("SetSelectedSlotEvent")

setSelectedSlotEvent.OnServerEvent:Connect(function(player, slotNumber)

	if typeof(slotNumber) ~= "number" then
		return
	end
	
	if slotNumber < 1 or slotNumber > 6 then
		return
	end

	player:SetAttribute("SelectedSlot", slotNumber)
end)