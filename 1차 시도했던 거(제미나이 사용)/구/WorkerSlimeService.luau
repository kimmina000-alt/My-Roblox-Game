-- [[ 위치: ServerScriptService > WorkerSlimeService ]]
-- [[ 역할: 하우징 내 노동자 슬라임 오토 노동, Pathfinding, AFK 골드 생산 및 ASMR 제어 (찌그러짐 제거 버전)]]
-- [[  Floating Text 골드 연출, 속도/레벨 업그레이드 처리 ]]

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

-- RemoteEvent 생성 (상점 업그레이드용)
local upgradeWorkerEvent = ReplicatedStorage:FindFirstChild("UpgradeWorkerEvent")
if not upgradeWorkerEvent then
	upgradeWorkerEvent = Instance.new("RemoteEvent")
	upgradeWorkerEvent.Name = "UpgradeWorkerEvent"
	upgradeWorkerEvent.Parent = ReplicatedStorage
end

--------------------------------------------------------------------------------
-- ?? [기본 설정값]
--------------------------------------------------------------------------------
local CONFIG = {
	BASE_GOLD_PER_WORK = 10,
	WORK_INTERVAL = 0.1, -- 발판에 도달 후 작업 및 대기 시간 (초)

	WORK_SOUND_ID = "rbxassetid://127105730240202", -- 발판 밟을 때 재생되는 ASMR 소리
	SOUND_MAX_DISTANCE = 50,
	SOUND_MIN_DISTANCE = 5,

	RUN_ANIM_R6 = "rbxassetid://180436334",
	RUN_ANIM_R15 = "rbxassetid://913376220",
}
--------------------------------------------------------------------------------
-- ?? [WorkerSlime 등 뒤 3D Floating Text 연출]
--------------------------------------------------------------------------------
local function showFloatingGoldText(workerPart, goldAmount)
	if not workerPart then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GoldFloatingText"
	billboard.Size = UDim2.new(0, 120, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = workerPart
	billboard.Parent = workerPart

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "+" .. goldAmount .. " Gold!"
	textLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
	textLabel.TextStrokeColor3 = Color3.fromRGB(80, 50, 0)
	textLabel.TextStrokeTransparency = 0
	textLabel.TextSize = 20
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.Parent = billboard

	-- 위로 떠오르면서 투명해지는 애니메이션
	local tweenInfo = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tweenOffset = TweenService:Create(billboard, tweenInfo, {StudsOffset = Vector3.new(0, 4.5, 0)})
	local tweenText = TweenService:Create(textLabel, tweenInfo, {TextTransparency = 1, TextStrokeTransparency = 1})

	tweenOffset:Play()
	tweenText:Play()

	task.delay(1.2, function()
		billboard:Destroy()
	end)
end
--------------------------------------------------------------------------------
-- ?? 노동자 슬라임 뛰기 애니메이션 등록
--------------------------------------------------------------------------------
local function setupWorkerAnimation(worker)
	local humanoid = worker:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local animId = (humanoid.RigType == Enum.HumanoidRigType.R6) and CONFIG.RUN_ANIM_R6 or CONFIG.RUN_ANIM_R15
	
	local runAnimation = Instance.new("Animation")
	runAnimation.AnimationId = animId

	--if not animator then
	--	animator = Instance.new("Animator")
	--	animator.Parent = humanoid
	--end

	--local runAnimation = Instance.new("Animation")
	--runAnimation.AnimationId = animId

	local runTrack
	pcall(function()
		runTrack = animator:LoadAnimation(runAnimation)
		runTrack.Priority = Enum.AnimationPriority.Movement
	end)

	humanoid.Running:Connect(function(speed)
		if runTrack then
			if speed > 0.5 then
				if not runTrack.IsPlaying then
					runTrack:Play(0.10, 1, math.clamp(speed / 16, 0.8, 3.0))
				else
					-- 속도가 바뀌면 애니메이션 재생 속도도 즉시 변경
					runTrack:AdjustSpeed(math.clamp(speed / 16, 0.8, 3.0))
				end
			else
				if runTrack.IsPlaying then
					runTrack:Stop(0.15)
				end
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- ??? 노동자 슬라임 셋업 및 Attribute 설정
--------------------------------------------------------------------------------
local function setupWorkerAttributes(worker)
	if not worker:GetAttribute("WorkerLevel") then
		worker:SetAttribute("WorkerLevel", 1)
	end
	if not worker:GetAttribute("WalkSpeed") then
		worker:SetAttribute("WalkSpeed", 12)
	end
	if not worker:GetAttribute("GoldMultiplier") then
		worker:SetAttribute("GoldMultiplier", 1.0)
	end

	local humanoid = worker:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = worker:GetAttribute("WalkSpeed")

		worker:GetAttributeChangedSignal("WalkSpeed"):Connect(function()
			humanoid.WalkSpeed = worker:GetAttribute("WalkSpeed")
		end)
	end

	setupWorkerAnimation(worker)
end

--------------------------------------------------------------------------------
-- ?? [3D ASMR 공간 사운드 재생]
--------------------------------------------------------------------------------
local function playWorkSound(parentPart)
	local sound = parentPart:FindFirstChild("SlimeWorkASMR")or Instance.new("Sound", parentPart)
	--if not sound then
		--sound = Instance.new("Sound")
		sound.Name = "SlimeWorkASMR"
		sound.SoundId = CONFIG.WORK_SOUND_ID
		sound.Volume = 0.8
		--sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = CONFIG.SOUND_MIN_DISTANCE
		sound.RollOffMaxDistance = CONFIG.SOUND_MAX_DISTANCE
		--sound.Parent = parentPart
	--end

	sound.TimePosition = 0
	sound:Play()
end

--------------------------------------------------------------------------------
-- ?? Pathfinding 이동 및 노동 루프
--------------------------------------------------------------------------------
local function startWorkerLoop(housingFolder)
	local worker = housingFolder:FindFirstChild("WorkerSlime")
	local padsFolder = housingFolder:FindFirstChild("SlimePads")
	--local ownerUserId = housingFolder:GetAttribute("OwnerUserId")

	if not worker or not padsFolder then return end

	local humanoid = worker:FindFirstChildOfClass("Humanoid")
	local rootPart = worker:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end

	setupWorkerAttributes(worker)

	task.spawn(function()
		local pads = padsFolder:GetChildren()
		local currentPadIndex = 1

		while worker and worker.Parent and humanoid.Health > 0 do
			pads = padsFolder:GetChildren()
			if #pads == 0 then task.wait(2) continue end

			local targetPad = pads[currentPadIndex]
			if targetPad and targetPad:IsA("BasePart") then

				-- 1. Pathfinding 길찾기 이동
				local path = PathfindingService:CreatePath({
					AgentRadius = 2,
					AgentHeight = 3
				})
				pcall(function() path:ComputeAsync(rootPart.Position, targetPad.Position) end)
			

				if path.Status == Enum.PathStatus.Success then
					for _, waypoint in ipairs(path:GetWaypoints()) do
						humanoid:MoveTo(waypoint.Position)
						if not humanoid.MoveToFinished:Wait() then break end
					end
				else
					humanoid:MoveTo(targetPad.Position)
					humanoid.MoveToFinished:Wait()
				end

				-- 2. ?? 패드 도달 시: 찌그러짐 없이 소리만 재생 후 골드 지급
				playWorkSound(targetPad)

				local level = worker:GetAttribute("WorkerLevel") or 1
				local multiplier = worker:GetAttribute("GoldMultiplier") or 1.0
				local earnedGold = math.floor(CONFIG.BASE_GOLD_PER_WORK * level * multiplier)
				
                local ownerUserId = housingFolder:GetAttribute("OwnerUserId")
                local owner = ownerUserId and Players:GetPlayerByUserId(ownerUserId)
                if owner then
                    local data = PlayerDataService.GetData(owner)
                    local incomeMultiplier = data and data.WorkerIncomeMultiplier or 1
                    local finalGold = math.floor(earnedGold * incomeMultiplier)
                    PlayerDataService.AddGold(owner, finalGold)
                    showFloatingGoldText(rootPart, finalGold)
                end
				-- 3. 패드에서 1초간 작업 대기 후 다음 패드로 이동
				task.wait(CONFIG.WORK_INTERVAL)
				currentPadIndex = (currentPadIndex % #pads) + 1
			else
				task.wait(1)
			end
		end
	end)
end
--------------------------------------------------------------------------------
-- ?? [상점 업그레이드 이벤트 처리]
--------------------------------------------------------------------------------
upgradeWorkerEvent.OnServerEvent:Connect(function(player, upgradeType)
    local data = PlayerDataService.GetData(player)
    if not data then return end

    local housingPlots = workspace:FindFirstChild("HousingPlots")
    if not housingPlots then return end
    local playerHousing
    for _, plot in ipairs(housingPlots:GetChildren()) do
        if plot:GetAttribute("OwnerUserId") == player.UserId then
            playerHousing = plot
            break
        end
    end
    if not playerHousing then
        local plots = housingPlots:GetChildren()
        if #plots == 1 and plots[1]:GetAttribute("OwnerUserId") == nil then playerHousing = plots[1] end
    end
    local worker = playerHousing and playerHousing:FindFirstChild("WorkerSlime")
    if not worker then return end

    if upgradeType == "Speed" then
        local currentSpeed = worker:GetAttribute("WalkSpeed") or 12
        if PlayerDataService.SpendGold(player, math.floor(currentSpeed * 15)) then
            worker:SetAttribute("WalkSpeed", currentSpeed + 4)
        end
    elseif upgradeType == "Level" then
        local currentLevel = worker:GetAttribute("WorkerLevel") or 1
        if PlayerDataService.SpendGold(player, currentLevel * 100) then
            worker:SetAttribute("WorkerLevel", currentLevel + 1)
        end
    end
end)

local housingPlotsFolder = workspace:WaitForChild("HousingPlots", 10) or workspace

local function onHousingAdded(housingFolder)
	if housingFolder:IsA("Folder") or housingFolder:IsA("Model") then
		startWorkerLoop(housingFolder)
	end
end

for _, plot in ipairs(housingPlotsFolder:GetChildren()) do
	onHousingAdded(plot)
end

housingPlotsFolder.ChildAdded:Connect(onHousingAdded)

print("[WorkerSlimeService] WorkerSlime 찌그러짐 제거 및 패드 사운드 전용 설정 적용 완료!")