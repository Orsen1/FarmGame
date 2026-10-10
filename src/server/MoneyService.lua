local MoneyService = {}
local MAX_INTEGER = 9007199254740991

local function isValidAmount(amount)
	return typeof(amount) == "number"
		and amount >= 0
		and amount <= MAX_INTEGER
		and amount % 1 == 0
end

local function getMoneyValue(player)
	local playerData = player:FindFirstChild("PlayerData")
	return playerData and playerData:FindFirstChild("MoneyCents")
end

local function formatMoney(cents)
	return "$" .. string.format("%.2f", cents / 100)
end

function MoneyService.Initialize(player)
	if getMoneyValue(player) then
		return
	end

	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then
		playerData = Instance.new("Folder")
		playerData.Name = "PlayerData"
		playerData.Parent = player
	end

	local moneyCents = Instance.new("IntValue")
	moneyCents.Name = "MoneyCents"
	moneyCents.Value = 0
	moneyCents.Parent = playerData

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local moneyDisplay = leaderstats:FindFirstChild("Money")
	if not moneyDisplay then
		moneyDisplay = Instance.new("StringValue")
		moneyDisplay.Name = "Money"
		moneyDisplay.Parent = leaderstats
	end
	moneyDisplay.Value = formatMoney(moneyCents.Value)

	moneyCents.Changed:Connect(function()
		moneyDisplay.Value = formatMoney(moneyCents.Value)
	end)
end

function MoneyService.CanAddMoney(player, amount)
	if not isValidAmount(amount) then
		return false
	end

	local moneyCents = getMoneyValue(player)
	return moneyCents ~= nil
		and isValidAmount(moneyCents.Value)
		and moneyCents.Value <= MAX_INTEGER - amount
end

function MoneyService.AddMoney(player, amount)
	if not MoneyService.CanAddMoney(player, amount) then
		return false
	end

	local moneyCents = getMoneyValue(player)
	moneyCents.Value = moneyCents.Value + amount
	return true
end

function MoneyService.RemoveMoney(player, amount)
	if not isValidAmount(amount) then
		return false
	end

	local moneyCents = getMoneyValue(player)
	if not moneyCents or not isValidAmount(moneyCents.Value)
		or moneyCents.Value < amount then
		return false
	end

	moneyCents.Value = moneyCents.Value - amount
	return true
end

function MoneyService.GetMoney(player)
	local moneyCents = getMoneyValue(player)
	return moneyCents and moneyCents.Value
end

return MoneyService
