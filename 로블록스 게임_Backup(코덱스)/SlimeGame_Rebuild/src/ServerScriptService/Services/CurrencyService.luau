local PlayerDataService = require(script.Parent.PlayerDataService)

local CurrencyService = {}

function CurrencyService.AddGold(player, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then return false end
	local data = PlayerDataService.Get(player)
	if not data then return false end
	data.CurrentGold += amount
	data.LifetimeGold += amount
	PlayerDataService.Sync(player)
	return true
end

function CurrencyService.SpendGold(player, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then return false end
	local data = PlayerDataService.Get(player)
	if not data or data.CurrentGold < amount then return false end
	data.CurrentGold -= amount
	PlayerDataService.Sync(player)
	return true
end

return CurrencyService
