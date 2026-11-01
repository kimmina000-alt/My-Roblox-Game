-- ServerScriptService > RebirthService (Script)
-- PlayerDataService owns saved progression and leaderstats; this script owns rebirth rules.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local RebirthConfig = require(ReplicatedStorage:WaitForChild("RebirthConfig"))

local function getOrCreate(parent, className, name)
	local object = parent:FindFirstChild(name)
	if object and object.ClassName == className then return object end
	if object then object:Destroy() end
	object = Instance.new(className)
	object.Name = name
	object.Parent = parent
	return object
end

local rebirthEvents = getOrCreate(ReplicatedStorage, "Folder", "RebirthEvents")
local requestRebirth = getOrCreate(rebirthEvents, "RemoteFunction", "RequestRebirth")
local toggleAura = getOrCreate(rebirthEvents, "RemoteEvent", "ToggleAura")

local function tableContainsItem(value, itemName)
	if type(value) ~= "table" then return value == itemName end
	for key, child in pairs(value) do
		if key == itemName or child == itemName then return true end
		if type(child) == "table" and tableContainsItem(child, itemName) then return true end
	end
	return false
end

local function playerOwnsRequiredTopping(player, data, itemName)
	if tableContainsItem(data.CommonMaterials, itemName) or tableContainsItem(data.GachaCabinet, itemName) then
		return true
	end
	local containers = {}
	local backpack = player:FindFirstChild("Backpack")
	if backpack then table.insert(containers, backpack) end
	if player.Character then table.insert(containers, player.Character) end
	for _, container in ipairs(containers) do
		for _, item in ipairs(container:GetChildren()) do
			if item:IsA("Tool") and item.Name == itemName then return true end
		end
	end
	return false
end

local function removeResettableTools(player)
	local keepAttributes = { "IsGachaItem", "IsEventTopping", "IsLimitedItem" }
	local containers = {}
	local backpack = player:FindFirstChild("Backpack")
	if backpack then table.insert(containers, backpack) end
	if player.Character then table.insert(containers, player.Character) end
	for _, container in ipairs(containers) do
		for _, item in ipairs(container:GetChildren()) do
			if item:IsA("Tool") then
				local keep = false
				for _, attribute in ipairs(keepAttributes) do
					if item:GetAttribute(attribute) == true then keep = true break end
				end
				if not keep then item:Destroy() end
			end
		end
	end
end

local function applyRebirth(player, data, config)
	data.CurrentGold = 0
	data.CommonMaterials = {
		DirtyToppings = {}, WashedToppings = {}, Bases = {}, Dyes = {}, Fragrances = {},
	}
	data.WorkshopUpgrades = { PumpLevel = 1, SpeedLevel = 1 }
	data.RebirthCount += 1
	data.WorkerIncomeMultiplier = config.WorkerIncomeMultiplier or 1
	data.MaxWorkerBonus += config.MaxWorkerBonus or 0

	if config.UnlockedAura and not table.find(data.UnlockedAuras, config.UnlockedAura) then
		table.insert(data.UnlockedAuras, config.UnlockedAura)
	end
	removeResettableTools(player)
	PlayerDataService.Sync(player)
	player:SetAttribute("RebirthCount", data.RebirthCount)
	player:SetAttribute("MaxWorkers", 1 + data.MaxWorkerBonus)
	return data.RebirthCount
end

requestRebirth.OnServerInvoke = function(player)
	local data = PlayerDataService.WaitForData(player, 30)
	if not data then return false, "플레이어 데이터를 불러오는 중입니다." end

	local config = RebirthConfig.GetStageConfig(data.RebirthCount)
	if not config then return false, "현재 환생 단계를 모두 완료했습니다." end
	if data.CurrentGold < config.RequiredGold then
		return false, ("골드가 부족합니다. (필요: %d)"):format(config.RequiredGold)
	end
	if not playerOwnsRequiredTopping(player, data, config.RequiredTopping) then
		return false, ("환생 재료 [%s]가 필요합니다."):format(config.RequiredTopping)
	end

	local rebirthCount = applyRebirth(player, data, config)
	return true, ("환생 완료! 현재 환생 횟수: %d"):format(rebirthCount)
end

toggleAura.OnServerEvent:Connect(function(player, auraName, enabled)
	if type(auraName) ~= "string" or type(enabled) ~= "boolean" then return end
	local data = PlayerDataService.GetData(player)
	if not data then return end
	if enabled then
		if not table.find(data.UnlockedAuras, auraName) then return end
		data.EquippedAura = auraName
	else
		data.EquippedAura = nil
	end
	player:SetAttribute("EquippedAura", data.EquippedAura)
end)

Players.PlayerAdded:Connect(function(player)
	local data = PlayerDataService.WaitForData(player, 30)
	if data then
		player:SetAttribute("RebirthCount", data.RebirthCount)
		player:SetAttribute("MaxWorkers", 1 + data.MaxWorkerBonus)
		player:SetAttribute("EquippedAura", data.EquippedAura)
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		local data = PlayerDataService.WaitForData(player, 30)
		if data then
			player:SetAttribute("RebirthCount", data.RebirthCount)
			player:SetAttribute("MaxWorkers", 1 + data.MaxWorkerBonus)
			player:SetAttribute("EquippedAura", data.EquippedAura)
		end
	end)
end
