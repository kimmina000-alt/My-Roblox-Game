local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemCatalog = require(ReplicatedStorage.Shared.ItemCatalog)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RemoteService = require(script.Parent.RemoteService)

local CollectionBookService = {}

function CollectionBookService.Init()
	RemoteService.Get("RequestCollectionBook").OnServerInvoke = function(player)
		local data = PlayerDataService.WaitFor(player, 30)
		if not data then return nil, "데이터를 불러오지 못했습니다." end
		return data.CollectionBook
	end
end

function CollectionBookService.IsDiscovered(player, itemId)
	local data = PlayerDataService.Get(player)
	return data ~= nil and data.CollectionBook[itemId] == true and ItemCatalog.Get(itemId) ~= nil
end

return CollectionBookService
