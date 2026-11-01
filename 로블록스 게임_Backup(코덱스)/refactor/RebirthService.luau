-- [[ 위치: ServerScriptService > RebirthService ]]
-- [[ 역할: 환생 리셋/보존 로직 및 서버 보상 처리 ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RebirthConfig = require(ReplicatedStorage:WaitForChild("RebirthConfig"))

-- RemoteEvent 생성 (환생 요청 및 아우라 Toggle)
local RebirthEvents = ReplicatedStorage:FindFirstChild("RebirthEvents") or Instance.new("Folder")
RebirthEvents.Name = "RebirthEvents"
RebirthEvents.Parent = ReplicatedStorage

local requestRebirthRF = Instance.new("RemoteFunction")
requestRebirthRF.Name = "RequestRebirth"
requestRebirthRF.Parent = RebirthEvents

local toggleAuraRE = Instance.new("RemoteEvent")
toggleAuraRE.Name = "ToggleAura"
toggleAuraRE.Parent = RebirthEvents

-- 가상의 플레이어 데이터 세션 구조 (실제 DataStore 연동 지점)
local PlayerDataSession = {}

-- 리더보드 초기화 (누적 골드 & 환생 횟수 표시)
local function setupLeaderstats(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	-- 1. 로블록스 리더보드 표기용: 누적 골드 (TotalGold) - 절대 리셋 안 됨
	local totalGoldStat = Instance.new("IntValue")
	totalGoldStat.Name = "Total Gold"
	totalGoldStat.Value = 0
	totalGoldStat.Parent = leaderstats

	-- 2. 환생 횟수
	local rebirthStat = Instance.new("IntValue")
	rebirthStat.Name = "Rebirths"
	rebirthStat.Value = 0
	rebirthStat.Parent = leaderstats

	-- 내부 가상 세션 데이터 세팅
	PlayerDataSession[player.UserId] = {
		CurrentGold = 0,               -- [리셋 O] 현재 소비용 골드
		TotalGold = 0,                  -- [리셋 X] 누적 골드
		RebirthCount = 0,               -- [리셋 X] 환생 횟수

		-- 리셋되는 일반 재료 & 업그레이드
		CommonMaterials = { DirtyToppings = {}, WashedToppings = {}, Bases = {}, Dyes = {} }, -- [리셋 O]
		WorkshopUpgrades = { PumpLevel = 1, SpeedLevel = 1 }, -- [리셋 O]

		-- 영구 보존 데이터 (??)
		GachaCabinet = {},              -- [보존 O] 한정/희귀 가챠 바구니
		UnlockedGachaZones = { "Zone1" },-- [보존 O] 해금된 가챠 구역
		SlimeCollectionBook = {},       -- [보존 O] 슬라임 도감 및 수집 기록
		UnlockedAuras = {},             -- [보존 O] 소유한 아우라
		EquippedAura = nil,             -- 장착 중인 아우라

		-- 환생 보상 적용 스탯
		WorkerIncomeMultiplier = 1.0,   -- 노동자 수익 배율
		MaxWorkerBonus = 0              -- 추가 고용 가능 노동자 수
	}
end

Players.PlayerAdded:Connect(setupLeaderstats)

-- 환생 조건 검증 함수
local function checkRebirthConditions(player)
	local session = PlayerDataSession[player.UserId]
	if not session then return false, "데이터를 찾을 수 없습니다." end

	local config = RebirthConfig.GetStageConfig(session.RebirthCount)

	-- 1. 소비용 골드 확인
	if session.CurrentGold < config.RequiredGold then
		return false, "골드가 부족합니다. (필요: " .. config.RequiredGold .. ")"
	end

	-- 2. 필수 토핑 소유 확인 (DirtyBag 또는 CommonMaterials 내 확인)
	local hasTopping = false
	if session.CommonMaterials.WashedToppings[config.RequiredTopping] or session.CommonMaterials.DirtyToppings[config.RequiredTopping] then
		hasTopping = true
	end

	-- Character Tool(손에 든 아이템) 확인
	if not hasTopping and player.Character then
		local tool = player.Character:FindFirstChild(config.RequiredTopping)
		if tool then hasTopping = true end
	end

	if not hasTopping then
		return false, "환생 필수 토핑 [" .. config.RequiredTopping .. "]을(를) 소유하고 있지 않습니다."
	end

	return true, config
end

-- [환생 실행 처리]
requestRebirthRF.OnServerInvoke = function(player)
	local canRebirth, configOrReason = checkRebirthConditions(player)
	if not canRebirth then
		return false, configOrReason
	end

	local session = PlayerDataSession[player.UserId]
	local config = configOrReason

	----------------------------------------------------------------------------
	-- ?? 1. 리셋 항목 초기화 (Reset)
	----------------------------------------------------------------------------
	session.CurrentGold = 0 -- 소비용 골드 리셋
	session.CommonMaterials = { DirtyToppings = {}, WashedToppings = {}, Bases = {}, Dyes = {} } -- 일반 재료 초기화
	session.WorkshopUpgrades = { PumpLevel = 1, SpeedLevel = 1 } -- 일반 작업장 업그레이드 초기화

	----------------------------------------------------------------------------
	-- ?? 2. 보존 항목 유지 및 환생 보상 적용 (Preserve & Reward)
	----------------------------------------------------------------------------
	session.RebirthCount += 1

	-- 보상 적용
	session.WorkerIncomeMultiplier = config.WorkerIncomeMultiplier
	session.MaxWorkerBonus += config.MaxWorkerBonus

	-- 아우라 영구 해금 목록에 추가
	if config.UnlockedAura and not table.find(session.UnlockedAuras, config.UnlockedAura) then
		table.insert(session.UnlockedAuras, config.UnlockedAura)
	end

	-- 3. Leaderstats 반영 (누적 골드는 보존, 환생 횟수 증가)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Rebirths.Value = session.RebirthCount
		-- leaderstats["Total Gold"].Value 는 초기화하지 않고 그대로 유지
	end

	print(player.Name .. " 플레이어가 환생하였습니다! 현재 환생 수: " .. session.RebirthCount)
	return true, "환생에 성공했습니다!"
end

-- 아우라 On/Off 토글 기능
toggleAuraRE.OnServerEvent:Connect(function(player, auraName, enable)
	local session = PlayerDataSession[player.UserId]
	if not session then return end

	if enable then
		if table.find(session.UnlockedAuras, auraName) then
			session.EquippedAura = auraName
			print(player.Name .. " - 아우라 착용: " .. auraName)
			-- (이곳에 실제 아바타 Character 파티클 생성 연동)
		end
	else
		session.EquippedAura = nil
		print(player.Name .. " - 아우라 해제")
	end
end)