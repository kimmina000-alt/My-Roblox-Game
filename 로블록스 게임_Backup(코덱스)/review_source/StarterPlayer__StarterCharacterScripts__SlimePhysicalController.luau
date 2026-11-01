-- [[ 위치: StarterPlayer > StarterCharacterScripts > LocalScript ]]
-- [[ 역할: 점프/충돌/이동 ASMR 사운드 제어 (찌그러짐 연출 제거 버전) ]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

--------------------------------------------------------------------------------
-- [설정값 및 주요 변수]
--------------------------------------------------------------------------------
local CONFIG = {
	MOVE_SOUND_ID = "rbxassetid://120915211582418",   -- 이동 소리
	JUMP_SOUND_ID = "rbxassetid://140606674696399",   -- 점프 소리
	IMPACT_SOUND_ID = "rbxassetid://106771269229569", -- 충돌 소리
	EAT_SOUND_ID = "rbxassetid://108647800821322",    -- 먹이 섭취 소리

	ROLLOFF_MAX_DISTANCE = 30,
	MOVE_SOUND_INTERVAL = 0.35,

	BASE_PITCH = 1.0,
	MIN_PITCH = 0.5,

	WALL_IMPACT_SPEED = 10,
	WALL_DEBOUNCE_TIME = 0.3,
}
local lastWallImpactTime = 0

--------------------------------------------------------------------------------
-- [3D ASMR 사운드 생성 및 인스턴스화]
--------------------------------------------------------------------------------
local function createASMRSound(name, soundId, volume)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.RollOffMaxDistance = CONFIG.ROLLOFF_MAX_DISTANCE
	sound.RollOffMinDistance = 5
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = rootPart
	return sound
end

local moveSound = createASMRSound("SlimeMoveSound", CONFIG.MOVE_SOUND_ID, 0.6)
local jumpSound = createASMRSound("SlimeJumpSound", CONFIG.JUMP_SOUND_ID, 0.7)
local impactSound = createASMRSound("SlimeImpactSound", CONFIG.IMPACT_SOUND_ID, 0.8)
local eatSound = createASMRSound("SlimeEatSound", CONFIG.EAT_SOUND_ID, 0.9)

--------------------------------------------------------------------------------
-- [체급/Scale 기반 사운드 피치 계산]
--------------------------------------------------------------------------------
local function updateSoundPitch()
	local currentScale = character:GetAttribute("SlimeSize") or 1
	local calculatedPitch = CONFIG.BASE_PITCH / math.clamp(currentScale, 1, 3)
	local finalPitch = math.max(calculatedPitch, CONFIG.MIN_PITCH)

	moveSound.PlaybackSpeed = finalPitch
	jumpSound.PlaybackSpeed = finalPitch
	impactSound.PlaybackSpeed = finalPitch
	eatSound.PlaybackSpeed = finalPitch + 0.2
end

--------------------------------------------------------------------------------
-- [사운드 전용 효과 처리 (찌그러짐 삭제)]
--------------------------------------------------------------------------------
local function playImpactEffect(soundToPlay)
	updateSoundPitch()
	if soundToPlay then
		soundToPlay.TimePosition = 0
		soundToPlay:Play()
	end
end

--------------------------------------------------------------------------------
-- [이동 및 충돌 루프]
--------------------------------------------------------------------------------
task.spawn(function()
	while task.wait(CONFIG.MOVE_SOUND_INTERVAL) do
		if humanoid.FloorMaterial ~= Enum.Material.Air and rootPart.AssemblyLinearVelocity.Magnitude > 2 then
			updateSoundPitch()
			moveSound:Play()
		end
	end
end)

rootPart.Touched:Connect(function(hit)
	if hit:IsDescendantOf(character) then return end
	if hit.Parent:FindFirstChildOfClass("Humanoid") then return end 
	if hit.Name == "JellyPellet" or hit.Parent.Name == "JellyPellets" or hit:GetAttribute("IsPellet") then return end

	local now = tick()
	if now - lastWallImpactTime < CONFIG.WALL_DEBOUNCE_TIME then return end

	local vel = rootPart.AssemblyLinearVelocity
	local flatVelocity = Vector3.new(vel.X, 0, vel.Z)
	local speed = flatVelocity.Magnitude

	if speed > CONFIG.WALL_IMPACT_SPEED then
		local characterHeight = character:GetExtentsSize().Y
		local wallTopY = hit.Position.Y + (hit.Size.Y / 2)
		local rootY = rootPart.Position.Y

		if (wallTopY - (rootY - characterHeight / 2)) < (characterHeight * 0.4) then return end

		local moveDir = flatVelocity.Unit
		local lookDir = rootPart.CFrame.LookVector
		local forwardDot = moveDir:Dot(lookDir)

		if forwardDot > 0.4 then
			lastWallImpactTime = now
			playImpactEffect(impactSound)
		end
	end
end)

local lastSize = character:GetAttribute("SlimeSize") or 1
character:GetAttributeChangedSignal("SlimeSize"):Connect(function()
	local newSize = character:GetAttribute("SlimeSize") or 1
	if newSize > lastSize then
		updateSoundPitch()
		eatSound.TimePosition = 0
		eatSound:Play()
	end
	lastSize = newSize
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		humanoid.WalkSpeed = 32
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		humanoid.WalkSpeed = 16
	end
end)