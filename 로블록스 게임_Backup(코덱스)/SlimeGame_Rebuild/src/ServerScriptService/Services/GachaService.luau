local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local ItemCatalog = require(ReplicatedStorage.Shared.ItemCatalog)
local PlayerDataService = require(script.Parent.PlayerDataService)
local InventoryService = require(script.Parent.InventoryService)
local PlotService = require(script.Parent.PlotService)
local RemoteService = require(script.Parent.RemoteService)

local GachaService = {}

local function getMachine(player, poolId)
	local plot = PlotService.GetPlot(player)
	if not plot then return nil end
	return plot:FindFirstChild("GachaMachine_" .. poolId, true) or plot:FindFirstChild("GachaMachine", true)
end

local function nearMachine(player, machine)
	local part = machine and (machine:IsA("BasePart") and machine or machine:FindFirstChildWhichIsA("BasePart", true))
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local plot = PlotService.GetPlot(player)
	return part ~= nil and root ~= nil and plot ~= nil and machine:IsDescendantOf(plot)
		and (root.Position - part.Position).Magnitude <= 12
end

local function roll(pool)
	local valid, total = {}, 0
	for _, entry in ipairs(pool.Items) do
		local definition = ItemCatalog.Get(entry.ItemId)
		if definition and definition.Category == "Topping" and (entry.Weight or 0) > 0 then
			total += entry.Weight
			table.insert(valid, entry)
		end
	end
	if total <= 0 then return nil end
	local number = math.random() * total
	for _, entry in ipairs(valid) do
		number -= entry.Weight
		if number <= 0 then return entry.ItemId end
	end
	return valid[#valid].ItemId
end

local function tickFreeCoin(player, now)
	local data = PlayerDataService.Get(player)
	if not data then return end
	if data.Gacha.NextFreeCoinAt <= 0 then
		data.Gacha.NextFreeCoinAt = now + GameConfig.Gacha.FreeCoinIntervalSeconds
		return
	end
	if now < data.Gacha.NextFreeCoinAt then return end
	local intervals = math.floor((now - data.Gacha.NextFreeCoinAt) / GameConfig.Gacha.FreeCoinIntervalSeconds) + 1
	data.Gacha.Coins += intervals
	data.Gacha.NextFreeCoinAt += intervals * GameConfig.Gacha.FreeCoinIntervalSeconds
end

function GachaService.Init()
	RemoteService.Get("GachaAction").OnServerInvoke = function(player, action, poolId)
		local data = PlayerDataService.WaitFor(player, 30)
		if not data then return false, "데이터를 불러오는 중입니다." end
		poolId = math.floor(tonumber(poolId) or 1)
		local pool = GameConfig.Gacha.Pools[poolId]
		if not pool then return false, "가챠 기계를 찾을 수 없습니다." end
		local machine = getMachine(player, poolId)
		if not machine or not nearMachine(player, machine) then return false, "가챠 기계 가까이에서 이용해 주세요." end
		if data.RebirthCount < pool.MinimumRebirth then return false, "환생 횟수가 부족합니다." end
		data.Gacha.UnlockedZones[poolId] = true
		if action == "GetState" then
			return true, { Coins = data.Gacha.Coins, NextFreeCoinAt = data.Gacha.NextFreeCoinAt, PoolId = poolId }
		elseif action == "Roll" then
			if data.Gacha.Coins < 1 then return false, "가챠 코인이 없습니다." end
			if #data.Inventory.GachaCabinet >= GameConfig.Gacha.CabinetCapacity then return false, "가챠 보관함이 가득 찼습니다." end
			local itemId = roll(pool)
			if not itemId then return false, "가챠 보상 목록이 비어 있습니다." end
			data.Gacha.Coins -= 1
			local added, reason = InventoryService.Add(player, itemId, 1, "Gacha")
			if not added then
				data.Gacha.Coins += 1
				return false, reason
			end
			return true, "캡슐을 열었습니다.", itemId
		end
		return false, "알 수 없는 요청입니다."
	end

	task.spawn(function()
		while true do
			task.wait(30)
			local now = os.time()
			for _, player in ipairs(Players:GetPlayers()) do tickFreeCoin(player, now) end
		end
	end)
end

return GachaService
