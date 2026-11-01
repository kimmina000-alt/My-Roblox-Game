local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)
local InventoryService = require(script.Parent.InventoryService)
local BasePlacementService = require(script.Parent.BasePlacementService)
local WorkerService = require(script.Parent.WorkerService)
local RemoteService = require(script.Parent.RemoteService)

local RebirthService = {}
local processing = {}

local function findStage(rebirthCount)
	return GameConfig.RebirthStages[rebirthCount + 1]
end

local function rebirth(player)
	if processing[player] then return false, "이미 환생을 처리 중입니다." end
	processing[player] = true
	local data = PlayerDataService.WaitFor(player, 30)
	if not data then processing[player] = nil; return false, "플레이어 데이터를 불러오는 중입니다." end

	local stage = findStage(data.RebirthCount)
	if not stage then processing[player] = nil; return false, "모든 환생 단계를 완료했습니다." end
	if data.CurrentGold < stage.RequiredGold then
		processing[player] = nil
		return false, ("골드가 부족합니다. 필요 금액: %d"):format(stage.RequiredGold)
	end
	if not InventoryService.Has(player, stage.RequiredItemId, 1) then
		processing[player] = nil
		return false, "필수 아이템이 없습니다: " .. stage.RequiredItemId
	end

	data.CurrentGold = 0
	data.Inventory.DirtyBag = nil
	data.Inventory.CraftBasket = {}
	data.DisplayShelf = { Slots = {} }
	data.PlacedBases = {}
	local protectedPlacements = {}
	for placementId, placement in pairs(data.PlacedToppings) do
		if type(placement) == "table" and placement.Protected == true then
			protectedPlacements[placementId] = placement
		end
	end
	data.PlacedToppings = protectedPlacements
	data.UnlockedZones = { Zone_1 = true }
	data.Pump = {
		Capacity = GameConfig.Pump.InitialCapacity,
		Current = GameConfig.Pump.InitialCapacity,
		AutoRefillLevel = 0,
	}
	data.Workers.IncomeMultiplier = stage.WorkerIncomeMultiplier
	data.Workers.ExtraSlots += stage.AdditionalWorkerSlots
	data.Workers.Owned = math.min(data.Workers.Owned, 1 + data.Workers.ExtraSlots)
	data.Workers.Placed = {}
	data.Workers.BagCount = data.Workers.Owned
	data.Workers.SelectedForPlacement = false
	data.RebirthCount += 1
	if stage.AuraId then data.Aura.Unlocked[stage.AuraId] = true end

	InventoryService.SyncVisuals(player)
	BasePlacementService.Sync(player)
	WorkerService.Sync(player)
	PlayerDataService.Sync(player)
	PlayerDataService.Save(player)
	processing[player] = nil
	return true, "환생 완료!", data.RebirthCount
end

function RebirthService.Init()
	RemoteService.Get("RequestRebirth").OnServerInvoke = rebirth
	RemoteService.Get("ToggleAura").OnServerInvoke = function(player, auraId, enabled)
		if type(auraId) ~= "string" or type(enabled) ~= "boolean" then return false end
		local data = PlayerDataService.Get(player)
		if not data then return false end
		if enabled then
			if not data.Aura.Unlocked[auraId] then return false end
			data.Aura.Equipped = auraId
		else
			data.Aura.Equipped = nil
		end
		player:SetAttribute("EquippedAura", data.Aura.Equipped)
		return true, data.Aura.Equipped
	end
end

return RebirthService
