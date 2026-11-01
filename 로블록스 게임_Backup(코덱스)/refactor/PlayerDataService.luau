-- Place as a ModuleScript named PlayerDataService under ServerScriptService.
-- This module is the single owner of player currency, progression and persistence.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DATASTORE = DataStoreService:GetDataStore("SlimeGame_PlayerData_v1")
local AUTOSAVE_SECONDS = 60
local MAX_ATTEMPTS = 3

local PlayerDataService = {}
local sessions = {}
local loading = {}

local function makeDefaultData()
	return {
		SchemaVersion = 1,
		CurrentGold = 300,
		LifetimeGold = 0,
		RebirthCount = 0,
		UnlockedZones = { Zone_1 = true },
		CommonMaterials = {
			DirtyToppings = {},
			WashedToppings = {},
			Bases = {},
			Dyes = {},
			Fragrances = {},
		},
		GachaCabinet = {},
		UnlockedGachaZones = { Zone1 = true },
		CollectionBook = {},
		UnlockedAuras = {},
		EquippedAura = nil,
		WorkerIncomeMultiplier = 1,
		MaxWorkerBonus = 0,
		Workers = { Owned = 0, Upgrades = {} },
		WorkshopUpgrades = { PumpLevel = 1, SpeedLevel = 1 },
	}
end

local function mergeDefaults(loaded)
	local data = makeDefaultData()
	if type(loaded) ~= "table" then
		return data
	end

	for key, value in pairs(loaded) do
		data[key] = value
	end
	data.SchemaVersion = 1
	data.CurrentGold = math.max(0, math.floor(tonumber(data.CurrentGold) or 0))
	data.LifetimeGold = math.max(0, math.floor(tonumber(data.LifetimeGold) or 0))
	data.RebirthCount = math.max(0, math.floor(tonumber(data.RebirthCount) or 0))
	data.UnlockedZones = type(data.UnlockedZones) == "table" and data.UnlockedZones or { Zone_1 = true }
	data.CommonMaterials = type(data.CommonMaterials) == "table" and data.CommonMaterials or makeDefaultData().CommonMaterials
	for _, key in ipairs({ "DirtyToppings", "WashedToppings", "Bases", "Dyes", "Fragrances" }) do
		if type(data.CommonMaterials[key]) ~= "table" then
			data.CommonMaterials[key] = {}
		end
	end
	data.GachaCabinet = type(data.GachaCabinet) == "table" and data.GachaCabinet or {}
	data.UnlockedGachaZones = type(data.UnlockedGachaZones) == "table" and data.UnlockedGachaZones or {}
	data.CollectionBook = type(data.CollectionBook) == "table" and data.CollectionBook or {}
	data.UnlockedAuras = type(data.UnlockedAuras) == "table" and data.UnlockedAuras or {}
	data.WorkerIncomeMultiplier = math.max(1, tonumber(data.WorkerIncomeMultiplier) or 1)
	data.MaxWorkerBonus = math.max(0, math.floor(tonumber(data.MaxWorkerBonus) or 0))
	data.Workers = type(data.Workers) == "table" and data.Workers or { Owned = 0, Upgrades = {} }
	data.Workers.Owned = math.max(0, math.floor(tonumber(data.Workers.Owned) or 0))
	data.Workers.Upgrades = type(data.Workers.Upgrades) == "table" and data.Workers.Upgrades or {}
	data.WorkshopUpgrades = type(data.WorkshopUpgrades) == "table" and data.WorkshopUpgrades or { PumpLevel = 1, SpeedLevel = 1 }
	return data
end

local function getOrCreateValue(parent, className, name)
	local value = parent:FindFirstChild(name)
	if value and value.ClassName == className then
		return value
	end
	if value then value:Destroy() end
	value = Instance.new(className)
	value.Name = name
	value.Parent = parent
	return value
end

local function syncLeaderstats(player, data)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	getOrCreateValue(stats, "IntValue", "Gold").Value = data.LifetimeGold
	getOrCreateValue(stats, "IntValue", "Current Gold").Value = data.CurrentGold
	getOrCreateValue(stats, "IntValue", "Rebirths").Value = data.RebirthCount
	player:SetAttribute("CurrentGold", data.CurrentGold)
end

local function loadPlayer(player)
	if sessions[player.UserId] or loading[player.UserId] then return end
	loading[player.UserId] = true

	local key = "u_" .. player.UserId
	local loadedData
	local succeeded = false
	for attempt = 1, MAX_ATTEMPTS do
		local ok, result = pcall(function()
			return DATASTORE:GetAsync(key)
		end)
		if ok then
			loadedData = result
			succeeded = true
			break
		end
		warn(("[PlayerDataService] Load attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(result)))
		task.wait(attempt)
	end

	if not succeeded then
		loading[player.UserId] = nil
		if RunService:IsStudio() then
			warn("[PlayerDataService] DataStore unavailable in Studio; using temporary, unsaved data.")
			sessions[player.UserId] = {
				Data = makeDefaultData(),
				Runtime = { ActivePads = {}, SpawnedWorkers = {} },
				CanSave = false,
			}
			syncLeaderstats(player, sessions[player.UserId].Data)
		else
			player:Kick("데이터를 불러오지 못했습니다. 잠시 후 다시 접속해 주세요.")
		end
		return
	end

	local isNew = loadedData == nil
	local data = mergeDefaults(loadedData)
	if isNew then data.CurrentGold = 300 end
	sessions[player.UserId] = {
		Data = data,
		Runtime = { ActivePads = {}, SpawnedWorkers = {} },
		CanSave = true,
	}
	loading[player.UserId] = nil
	syncLeaderstats(player, data)
end

function PlayerDataService.GetData(player)
	local session = sessions[player.UserId]
	return session and session.Data or nil
end

function PlayerDataService.WaitForData(player, timeoutSeconds)
	local deadline = os.clock() + (timeoutSeconds or 30)
	while player.Parent and not sessions[player.UserId] and os.clock() < deadline do
		task.wait(0.1)
	end
	local session = sessions[player.UserId]
	return session and session.Data or nil
end

function PlayerDataService.GetRuntime(player)
	local session = sessions[player.UserId]
	if not session then return nil end
	return session.Runtime
end

function PlayerDataService.Sync(player)
	local data = PlayerDataService.GetData(player)
	if data then syncLeaderstats(player, data) end
	return data
end

function PlayerDataService.AddGold(player, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then return false end
	local data = PlayerDataService.GetData(player)
	if not data then return false end
	data.CurrentGold += amount
	data.LifetimeGold += amount
	syncLeaderstats(player, data)
	return true
end

function PlayerDataService.SpendGold(player, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then return false end
	local data = PlayerDataService.GetData(player)
	if not data or data.CurrentGold < amount then return false end
	data.CurrentGold -= amount
	syncLeaderstats(player, data)
	return true
end

function PlayerDataService.SetCurrentGold(player, amount)
	local data = PlayerDataService.GetData(player)
	if not data then return false end
	data.CurrentGold = math.max(0, math.floor(tonumber(amount) or 0))
	syncLeaderstats(player, data)
	return true
end

local function savePlayer(player)
	local session = sessions[player.UserId]
	if not session or not session.CanSave then return end
	local snapshot = session.Data
	local key = "u_" .. player.UserId
	for attempt = 1, MAX_ATTEMPTS do
		local ok, err = pcall(function()
			DATASTORE:UpdateAsync(key, function()
				return snapshot
			end)
		end)
		if ok then return end
		warn(("[PlayerDataService] Save attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(err)))
		task.wait(attempt)
	end
end

Players.PlayerAdded:Connect(loadPlayer)
Players.PlayerRemoving:Connect(function(player)
	savePlayer(player)
	sessions[player.UserId] = nil
	loading[player.UserId] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadPlayer, player)
end

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_SECONDS)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(savePlayer, player)
		end
	end
end)

game:BindToClose(function()
	local remaining = 0
	for _, player in ipairs(Players:GetPlayers()) do
		remaining += 1
		task.spawn(function()
			savePlayer(player)
			remaining -= 1
		end)
	end
	local deadline = os.clock() + 25
	while remaining > 0 and os.clock() < deadline do task.wait(0.1) end
end)

return PlayerDataService
