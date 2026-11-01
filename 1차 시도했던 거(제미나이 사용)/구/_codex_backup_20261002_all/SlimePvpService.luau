-- [[ 위치: ServerScriptService > Script ]]
-- [[ 역할: PVP 영역 내 체급(Size) 기반 흡수, 튕김 물리 계산 및 먹이(JellyPellet) 스폰 ]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

--------------------------------------------------------------------------------
-- ?? [설정값 및 주요 변수]
--------------------------------------------------------------------------------
local CONFIG = {
	ABSORB_RATIO = 1.5,          -- 흡수 가능한 체급 차이 비율 (1.5배 이상)
	ABSORB_GAIN_RATE = 0.5,      -- 상대 체급 흡수 시 크기 증가 비율 (상대 크기의 50%)
	DEFAULT_SIZE = 1.0,          -- 플레이어 기본 크기 수치
	COLLISION_DEBOUNCE = 0.6,    -- 충돌 쿨타임 (초)

	PELLET_SIZE_GAIN = 0.1,      -- 먹이(JellyPellet) 획득 시 크기 증가량
	PELLET_RESPAWN_TIME = 3.0,   -- 먹이 재스폰 시간 (초)
	
	KNOCKBACK_POWER = 160,        -- ?? [수정] 뒤로 튕겨 나가는 속도 힘 (세 걸음 거리)
	KNOCKBACK_UP_POWER = 60,     -- ?? [수정] 튕길 때 살짝 위로 뜨는 힘 (마찰력 무시용)
	
	KNOCKBACK_FORCE = 30,  -- ?? [수정] 강한 밀쳐내기 힘
	KNOCKBACK_TIME = 0.05,  -- ?? [수정] 밀려나는 시간
	
	--KNOCKBACK_FORCE = 120,       -- 기본 튕김 밀쳐내기 힘 (Impulse)
	ABSORB_SOUND_ID = "rbxassetid://79712300185044", -- 흡수 시 '수풕-' 3D 오디오 ID
}

local collisionDebounceTable = {} -- [Player1_Player2] 형태의 쿨타임 관리 테이블

--------------------------------------------------------------------------------
-- ?? [플레이어 슬라임 크기(Scale/Attributes) 동기화 함수]
--------------------------------------------------------------------------------
local function getSlimeSize(character)
	local sizeVal = character:GetAttribute("SlimeSize")
	if not sizeVal then
		character:SetAttribute("SlimeSize", CONFIG.DEFAULT_SIZE)
		return CONFIG.DEFAULT_SIZE
	end
	return sizeVal
end

local function setSlimeSize(character, newSize)
	newSize = math.max(newSize, CONFIG.DEFAULT_SIZE)
	character:SetAttribute("SlimeSize", newSize)

	-- ?? 캐릭터의 Scale 속성을 조절하여 실제 체급 크기를 확대/축소
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		
		-- 방법 1: BodyScale 값 조절 (R15 아바타 표준)
		local depth = humanoid:FindFirstChild("BodyDepthScale")
		local height = humanoid:FindFirstChild("BodyHeightScale")
		local width = humanoid:FindFirstChild("BodyWidthScale")
		local head = humanoid:FindFirstChild("HeadScale")

		if depth then depth.Value = newSize end
		if height then height.Value = newSize end
		if width then width.Value = newSize end
		if head then head.Value = newSize end

		-- 방법 2: ScaleTo() 호환
		pcall(function()
			humanoid:ScaleTo(newSize)
		end)
	end
end

--------------------------------------------------------------------------------
-- ?? [흡수 3D 오디오 재생 함수]
--------------------------------------------------------------------------------
local function playAbsorbSound(position)
	local soundPart = Instance.new("Part")
	soundPart.Anchored = true
	soundPart.CanCollide = false
	soundPart.Transparency = 1
	soundPart.Position = position
	soundPart.Parent = Workspace

	local sound = Instance.new("Sound")
	sound.SoundId = CONFIG.ABSORB_SOUND_ID
	sound.Volume = 1.2
	sound.RollOffMaxDistance = 50
	sound.RollOffMinDistance = 5
	sound.Parent = soundPart

	sound:Play()
	sound.Ended:Connect(function()
		soundPart:Destroy()
	end)
end

--------------------------------------------------------------------------------
-- ?? [플레이어 간 충돌 처리 로직 (흡수 vs 튕김)]
--------------------------------------------------------------------------------
-- ?? 물리 인스턴스로 밀쳐내기 처리 함수 (네트워크 소유권 문제 해결)
local function applyKnockback(targetRoot, directionVector)
	local attachment = Instance.new("Attachment")
	attachment.Parent = targetRoot

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Attachment0 = attachment
	linearVelocity.MaxForce = 100000 -- 캐릭터 무게를 이기는 강한 힘
	linearVelocity.VectorVelocity = directionVector * CONFIG.KNOCKBACK_FORCE + Vector3.new(0, 30, 0) -- 위로 살짝 띄움
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.Parent = targetRoot

	-- 짧은 순간 밀어내고 제거
	task.delay(CONFIG.KNOCKBACK_TIME, function()
		linearVelocity:Destroy()
		attachment:Destroy()
	end)
end

local function onCharacterTouched(otherPart, characterA)
	local characterB = otherPart.Parent
	if not characterB or characterA == characterB then return end

	local playerA = Players:GetPlayerFromCharacter(characterA)
	local playerB = Players:GetPlayerFromCharacter(characterB)

	if not playerA or not playerB then return end

	local rootA = characterA:FindFirstChild("HumanoidRootPart")
	local rootB = characterB:FindFirstChild("HumanoidRootPart")
	local humA = characterA:FindFirstChildOfClass("Humanoid")
	local humB = characterB:FindFirstChildOfClass("Humanoid")

	if not rootA or not rootB or not humA or not humB then return end
	if humA.Health <= 0 or humB.Health <= 0 then return end

	local p1Id, p2Id = playerA.UserId, playerB.UserId
	local debounceKey = (p1Id < p2Id) and (p1Id .. "_" .. p2Id) or (p2Id .. "_" .. p1Id)

	if collisionDebounceTable[debounceKey] then return end
	collisionDebounceTable[debounceKey] = true
	task.delay(CONFIG.COLLISION_DEBOUNCE, function()
		collisionDebounceTable[debounceKey] = nil
	end)

	local sizeA = getSlimeSize(characterA)
	local sizeB = getSlimeSize(characterB)

	-- 1. [A가 B를 흡수]
	if sizeA >= sizeB * CONFIG.ABSORB_RATIO then
		humB.Health = 0
		setSlimeSize(characterA, sizeA + (sizeB * CONFIG.ABSORB_GAIN_RATE))
		playAbsorbSound(rootA.Position)

		-- 2. [B가 A를 흡수]
	elseif sizeB >= sizeA * CONFIG.ABSORB_RATIO then
		humA.Health = 0
		setSlimeSize(characterB, sizeB + (sizeA * CONFIG.ABSORB_GAIN_RATE))
		playAbsorbSound(rootB.Position)

		-- 3. ?? [동등 체급 튕김: LinearVelocity 물리를 통한 확실한 밀쳐내기]
	else
		local pushDir = (rootB.Position - rootA.Position)
		local flatDir = Vector3.new(pushDir.X, 0, pushDir.Z).Unit

		if flatDir.Magnitude == 0 or flatDir.X ~= flatDir.X then
			flatDir = Vector3.new(1, 0, 0)
		end

		applyKnockback(rootA, -flatDir)
		applyKnockback(rootB, flatDir)
	end
end
--------------------------------------------------------------------------------
-- ?? [먹이(JellyPellet) 상호작용 및 자동 스폰 로직]
--------------------------------------------------------------------------------
local function setupJellyPellet(pellet)
	local debounce = false
	pellet.Touched:Connect(function(hit)
		if debounce then return end
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)

		if player and character then
			local hum = character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				debounce = true

				-- 크기 증가
				local currentSize = getSlimeSize(character)
				setSlimeSize(character, currentSize + CONFIG.PELLET_SIZE_GAIN)

				-- 먹이 투명화 및 리스폰 대기
				pellet.Transparency = 1
				pellet.CanCollide = false

				task.wait(CONFIG.PELLET_RESPAWN_TIME)
				pellet.Transparency = 0
				pellet.CanCollide = true
				debounce = false
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- ?? [플레이어 접속 & 캐릭터 스폰 초기화]
--------------------------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		task.wait(0.2) -- 캐릭터 로드 대기
		setSlimeSize(character, CONFIG.DEFAULT_SIZE)

		local rootPart = character:WaitForChild("HumanoidRootPart")
		rootPart.Touched:Connect(function(hit)
			onCharacterTouched(hit, character)
		end)
	end)
end)

-- 맵 상의 기존 및 신규 JellyPellet 파트 바인딩 (Workspace 내 'JellyPellets' 폴더 참조)
task.spawn(function()
	local pelletFolder = Workspace:WaitForChild("JellyPellets", 5)
	if pelletFolder then
		for _, pellet in ipairs(pelletFolder:GetChildren()) do
			if pellet:IsA("BasePart") then
				setupJellyPellet(pellet)
			end
		end
		pelletFolder.ChildAdded:Connect(function(pellet)
			if pellet:IsA("BasePart") then
				setupJellyPellet(pellet)
			end
		end)
	end
end)

print("[SlimePvpService] PVP 체급 물리 및 먹이 시스템 활성화 완료!")