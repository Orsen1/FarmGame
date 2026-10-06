local MoneyService = {}

local function formatMoney(cents)
	return "$" .. string.format("%.2f", cents / 100)
end

function MoneyService.Initialize(player)
	local playerData = Instance.new("Folder")
	playerData.Name = "PlayerData"
	playerData.Parent = player

	local moneyCents = Instance.new("IntValue")
	moneyCents.Name = "MoneyCents"
	moneyCents.Value = 0
	moneyCents.Parent = playerData

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local moneyDisplay = Instance.new("StringValue")
	moneyDisplay.Name = "Money"
	moneyDisplay.Value = formatMoney(moneyCents.Value)
	moneyDisplay.Parent = leaderstats

	moneyCents.Changed:Connect(function()
		moneyDisplay.Value = formatMoney(moneyCents.Value)
	end)
end

function MoneyService.AddMoney(player, amount)
	local moneyCents = player.PlayerData:WaitForChild("MoneyCents")
	moneyCents.Value += amount
end

function MoneyService.RemoveMoney(player, amount)
	local moneyCents = player.PlayerData:WaitForChild("MoneyCents")

	if moneyCents.Value < amount then
		return false
	end

	moneyCents.Value -= amount
	return true
end

function MoneyService.GetMoney(player)
	return player.PlayerData.MoneyCents.Value
end

return MoneyService