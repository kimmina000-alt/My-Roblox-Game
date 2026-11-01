local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local ItemCatalog = require(ReplicatedStorage.Shared.ItemCatalog)

local PlayerDataService = {}
local profiles = {}
local loading = {}
local saving = {}
local store
local storeInitError
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.DataStoreName)
	end)
	if ok then
		store = result
	else
		storeInitError = result
		warn("[PlayerDataService] DataStore unavailable during module load: " .. tostring(result))
	end
end

local function defaultProfile()
	return {
		SchemaVersion = GameConfig.SchemaVersion,
		CurrentGold = GameConfig.StartingGold,
		LifetimeGold = 0,
		RebirthCount = 0,
		Inventory = { DirtyBag = nil, CraftBasket = {}, GachaCabinet = {} },
		DisplayShelf = { Slots = {} },
		MaterialShelves = {
			BaseShelf = { Slots = {} }, DyeShelf = { Slots = {} },
			FragranceShelf = { Slots = {} }, SurfaceEffectShelf = { Slots = {} },
		},
		PlacedToppings = {},
		PlacedBases = {},
		UnlockedZones = { Zone_1 = true },
		UnlockedPads = { Pad_1 = true },
		Workers = { Owned = 0, BagCount = 0, Placed = {}, SelectedForPlacement = false, IncomeMultiplier = 1, ExtraSlots = 0, Upgrades = {} },
		Pump = { Capacity = GameConfig.Pump.InitialCapacity, Current = GameConfig.Pump.InitialCapacity, AutoRefillLevel = 0 },
		Gacha = { Coins = 0, NextFreeCoinAt = os.time() + GameConfig.Gacha.FreeCoinIntervalSeconds, UnlockedZones = { [1] = true } },
		CollectionBook = {},
		Aura = { Unlocked = {}, Equipped = nil },
	}
end

local function copyTable(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = copyTable(child) end
	return result
end

local function addLegacyItems(target, oldItems)
	if type(oldItems) ~= "table" then return end
	for oldName, amount in pairs(oldItems) do
		local itemId = ItemCatalog.GetIdFromLegacyName(oldName)
		local count = math.max(0, math.floor(tonumber(amount) or (amount and 1 or 0)))
		if itemId and count > 0 then
			target[itemId] = (target[itemId] or 0) + count
		end
	end
end

local function normalizeProfile(saved)
	local data = defaultProfile()
	if type(saved) ~= "table" then return data, true end

	data.CurrentGold = math.max(0, math.floor(tonumber(saved.CurrentGold) or 0))
	data.LifetimeGold = math.max(0, math.floor(tonumber(saved.LifetimeGold or saved.TotalGold) or 0))
	data.RebirthCount = math.max(0, math.floor(tonumber(saved.RebirthCount) or 0))
	data.UnlockedZones = type(saved.UnlockedZones) == "table" and saved.UnlockedZones or data.UnlockedZones
	data.UnlockedPads = type(saved.UnlockedPads) == "table" and saved.UnlockedPads or data.UnlockedPads
	data.UnlockedPads.Pad_1 = true
	data.CollectionBook = type(saved.CollectionBook) == "table" and saved.CollectionBook or {}
	if type(saved.UnlockedAuras) == "table" then
		for key, value in pairs(saved.UnlockedAuras) do
			local auraId = type(key) == "number" and value or key
			if type(auraId) == "string" then data.Aura.Unlocked[auraId] = true end
		end
	end
	data.Aura.Equipped = saved.EquippedAura
	data.Workers = type(saved.Workers) == "table" and saved.Workers or data.Workers
	data.Workers.Owned = math.max(0, math.floor(tonumber(data.Workers.Owned) or 0))
	data.Workers.Placed = type(data.Workers.Placed) == "table" and data.Workers.Placed or {}
	local placedWorkerCount = #data.Workers.Placed
	data.Workers.BagCount = math.clamp(math.floor(tonumber(data.Workers.BagCount) or math.max(0, data.Workers.Owned - placedWorkerCount)), 0, data.Workers.Owned)
	data.Workers.SelectedForPlacement = false
	data.Workers.IncomeMultiplier = math.max(1, tonumber(saved.WorkerIncomeMultiplier or data.Workers.IncomeMultiplier) or 1)
	data.Workers.ExtraSlots = math.max(0, math.floor(tonumber(saved.MaxWorkerBonus or data.Workers.ExtraSlots) or 0))
	data.Workers.Upgrades = type(data.Workers.Upgrades) == "table" and data.Workers.Upgrades or {}
	data.Pump = type(saved.Pump) == "table" and saved.Pump or data.Pump
	data.Pump.Capacity = math.max(1, math.floor(tonumber(data.Pump.Capacity) or GameConfig.Pump.InitialCapacity))
	data.Pump.Current = math.clamp(tonumber(data.Pump.Current) or data.Pump.Capacity, 0, data.Pump.Capacity)
	data.Pump.AutoRefillLevel = math.max(0, math.floor(tonumber(data.Pump.AutoRefillLevel) or 0))
	data.Gacha = type(saved.Gacha) == "table" and saved.Gacha or data.Gacha
	data.Gacha.Coins = math.max(0, math.floor(tonumber(data.Gacha.Coins) or 0))
	data.Gacha.NextFreeCoinAt = math.max(0, tonumber(data.Gacha.NextFreeCoinAt) or 0)
	if data.Gacha.NextFreeCoinAt == 0 then
		data.Gacha.NextFreeCoinAt = os.time() + GameConfig.Gacha.FreeCoinIntervalSeconds
	end
	data.Gacha.UnlockedZones = type(data.Gacha.UnlockedZones) == "table" and data.Gacha.UnlockedZones or { [1] = true }
	data.DisplayShelf = type(saved.DisplayShelf) == "table" and saved.DisplayShelf or data.DisplayShelf
	data.DisplayShelf.Slots = type(data.DisplayShelf.Slots) == "table" and data.DisplayShelf.Slots or {}
	data.MaterialShelves = type(saved.MaterialShelves) == "table" and saved.MaterialShelves or data.MaterialShelves
	data.PlacedToppings = type(saved.PlacedToppings) == "table" and saved.PlacedToppings or {}
	data.PlacedBases = type(saved.PlacedBases) == "table" and saved.PlacedBases or {}
	-- Preserve pads already occupied before individual pad unlocks were introduced.
	local function preserveOccupiedPad(record)
		local zoneIndex = type(record.PadPath) == "string" and tonumber(record.PadPath:match("Zone_(%d+)"))
		if not zoneIndex or zoneIndex < 1 or zoneIndex > 3 then return end
		local row = record.PadPath:match("FreePlacementArea_2$") and 2 or 1
		local padId = "Pad_" .. ((zoneIndex - 1) * 2 + row)
		data.UnlockedPads[padId] = true
	end
	for _, record in ipairs(data.PlacedBases) do preserveOccupiedPad(record) end
	for _, record in ipairs(data.PlacedToppings) do preserveOccupiedPad(record) end
	for _, record in ipairs(data.Workers.Placed) do preserveOccupiedPad(record) end

	local inventory = type(saved.Inventory) == "table" and saved.Inventory or nil
	if inventory then
		data.Inventory.DirtyBag = inventory.DirtyBag
		data.Inventory.CraftBasket = type(inventory.CraftBasket) == "table" and inventory.CraftBasket or {}
		data.Inventory.GachaCabinet = type(inventory.GachaCabinet) == "table" and inventory.GachaCabinet or {}
	else
		local common = type(saved.CommonMaterials) == "table" and saved.CommonMaterials or {}
		addLegacyItems(data.Inventory.CraftBasket, common.WashedToppings)
		addLegacyItems(data.Inventory.CraftBasket, common.Bases)
		addLegacyItems(data.Inventory.CraftBasket, common.Dyes)
		addLegacyItems(data.Inventory.CraftBasket, common.Fragrances)
		for oldName in pairs(type(common.DirtyToppings) == "table" and common.DirtyToppings or {}) do
			data.Inventory.DirtyBag = "topping_dirty"
			break
		end
		if type(saved.GachaCabinet) == "table" then
			for _, oldValue in pairs(saved.GachaCabinet) do
				local oldName = type(oldValue) == "table" and (oldValue.ItemId or oldValue.Name) or oldValue
				local itemId = ItemCatalog.GetIdFromLegacyName(oldName)
				if itemId then table.insert(data.Inventory.GachaCabinet, itemId) end
			end
		end
	end
	local heldItemId = saved.HeldItemId
	local heldDefinition = type(heldItemId) == "string" and ItemCatalog.Get(heldItemId)
	if heldDefinition and heldDefinition.Category == "Topping"
		and ((data.Inventory.CraftBasket[heldItemId] or 0) > 0 or table.find(data.Inventory.GachaCabinet, heldItemId)) then
		data.HeldItemId = heldItemId
	end

	data.SchemaVersion = GameConfig.SchemaVersion
	return data, false
end

local function syncLeaderstats(player, data)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	local function intValue(name, value)
		local object = stats:FindFirstChild(name)
		if not object then
			object = Instance.new("IntValue")
			object.Name = name
			object.Parent = stats
		end
		object.Value = value
	end
	intValue("Gold", data.LifetimeGold)
	intValue("Rebirths", data.RebirthCount)
	player:SetAttribute("CurrentGold", data.CurrentGold)
	player:SetAttribute("RebirthCount", data.RebirthCount)
	player:SetAttribute("MaxWorkers", 1 + data.Workers.ExtraSlots)
end

local function loadPlayer(player)
	if profiles[player] or loading[player] then return end
	loading[player] = true
	if not store then
		loading[player] = nil
		if RunService:IsStudio() then
			warn("[PlayerDataService] Using temporary, unsaved Studio data. Publish the place and enable Studio API access to test saving. " .. tostring(storeInitError))
			profiles[player] = { Data = defaultProfile(), CanSave = false }
			syncLeaderstats(player, profiles[player].Data)
		else
			player:Kick("데이터 저장소를 사용할 수 없습니다. 잠시 후 다시 접속해 주세요.")
		end
		return
	end
	local ok, saved = pcall(function()
		return store:GetAsync("u_" .. player.UserId)
	end)
	if not ok then
		loading[player] = nil
		if RunService:IsStudio() then
			warn("[PlayerDataService] DataStore unavailable in Studio; this session will not save.")
			profiles[player] = { Data = defaultProfile(), CanSave = false }
			syncLeaderstats(player, profiles[player].Data)
		else
			player:Kick("데이터를 불러오지 못했습니다. 잠시 후 다시 접속해 주세요.")
		end
		return
	end
	local data, isNew = normalizeProfile(saved)
	profiles[player] = { Data = data, CanSave = true, IsNew = isNew }
	loading[player] = nil
	syncLeaderstats(player, data)
end

function PlayerDataService.Init()
	Players.PlayerAdded:Connect(loadPlayer)
	Players.PlayerRemoving:Connect(function(player)
		PlayerDataService.Save(player)
		profiles[player] = nil
		loading[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do task.spawn(loadPlayer, player) end
	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveSeconds)
			for _, player in ipairs(Players:GetPlayers()) do task.spawn(PlayerDataService.Save, player) end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for _, player in ipairs(Players:GetPlayers()) do
			pending += 1
			task.spawn(function()
				PlayerDataService.Save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do task.wait(0.1) end
	end)
end

function PlayerDataService.Get(player)
	local profile = profiles[player]
	return profile and profile.Data or nil
end

function PlayerDataService.WaitFor(player, timeout)
	local deadline = os.clock() + (timeout or 30)
	while player.Parent and not profiles[player] and loading[player] and os.clock() < deadline do task.wait(0.1) end
	return PlayerDataService.Get(player)
end

function PlayerDataService.Sync(player)
	local data = PlayerDataService.Get(player)
	if data then syncLeaderstats(player, data) end
	return data
end

function PlayerDataService.Save(player)
	local profile = profiles[player]
	if not profile or not profile.CanSave or saving[player] then return false end
	saving[player] = true
	local snapshot = copyTable(profile.Data)
	local ok, err = pcall(function()
		store:UpdateAsync("u_" .. player.UserId, function()
			return snapshot
		end)
	end)
	saving[player] = nil
	if not ok then warn("[PlayerDataService] Save failed for " .. player.Name .. ": " .. tostring(err)) end
	return ok
end

return PlayerDataService
