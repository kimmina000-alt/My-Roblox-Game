-- [[ 위치: ServerScriptService > SlimeZoneServer ]]
-- [[ 역할: 마우스 Raycast 클릭 위치 기반 토핑 진열 & 회수 시스템 ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- 리모트 이벤트 세팅
local workerEvent = ReplicatedStorage:FindFirstChild("WorkerShopEvent") or Instance.new("RemoteEvent", ReplicatedStorage)
workerEvent.Name = "WorkerShopEvent"

local placeToppingEvent = ReplicatedStorage:FindFirstChild("PlaceToppingEvent") or Instance.new("RemoteFunction", ReplicatedStorage)
placeToppingEvent.Name = "PlaceToppingEvent"

--------------------------------------------------------------------------------
-- ?? 기본 설정값
--------------------------------------------------------------------------------
local MAX_REBIRTH_LIMIT = 10
local WORKER_BASE_PRICE = 50
local REBIRTH_BASE_PRICE = 1000

local ZONE_CONFIG = {
	["Zone_1"] = { Price = 0, DefaultUnlocked = true },
	["Zone_2"] = { Price = 100, DefaultUnlocked = false },
	["Zone_3"] = { Price = 300, DefaultUnlocked = false },
	["Zone_4"] = { Price = 600, DefaultUnlocked = false },
}

local GOLD_STAT_NAME = "Gold"
local REBIRTH_STAT_NAME = "Rebirth"
local BASE_GOLD_PER_PAD = 10

--------------------------------------------------------------------------------
-- 데이터 세션 관리
--------------------------------------------------------------------------------
local playerData = {} 

local function getPlayerData(player)
	local userId = player.UserId
	if not playerData[userId] then
		playerData[userId] = {
			UnlockedZones = {},
			ActivePads = {},
			SpawnedWorkers = {},
			RebirthCount = 0
		}
	end
	return playerData[userId]
end

local function getLeaderstat(player, statName)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild(statName)
end

--------------------------------------------------------------------------------
-- Worker AI & 스폰
--------------------------------------------------------------------------------
local function refreshActivePads(player, housingPlot)
	local data = getPlayerData(player)
	data.ActivePads = {}
	local slimeZoneFolder = housingPlot:FindFirstChild("SlimeZone")
	if not slimeZoneFolder then return end

	for zoneName, isUnlocked in pairs(data.UnlockedZones) do
		if isUnlocked then
			local zonePart = slimeZoneFolder:FindFirstChild(zoneName)
			if zonePart then
				local padsFolder = zonePart:FindFirstChild("SlimePads")
				if padsFolder then
					for _, pad in ipairs(padsFolder:GetChildren()) do
						if pad:IsA("BasePart") then
							table.insert(data.ActivePads, pad)
						end
					end
				end
			end
		end
	end
end

local function startWorkerAI(player, workerModel)
	local humanoid = workerModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	for _, part in ipairs(workerModel:GetDescendants()) do
		if part:IsA("BasePart") then part.Anchored = false end
	end

	task.spawn(function()
		while workerModel and workerModel.Parent do
			local data = getPlayerData(player)
			local validPads = data.ActivePads or {}

			if #validPads > 0 then
				local targetPad = validPads[math.random(1, #validPads)]
				humanoid:MoveTo(targetPad.Position)

				if humanoid.MoveToFinished:Wait() then
					local goldStat = getLeaderstat(player, GOLD_STAT_NAME)
					if goldStat then
						local bonusMultiplier = 1 + (data.RebirthCount * 0.5)
						goldStat.Value = goldStat.Value + math.floor(BASE_GOLD_PER_PAD * bonusMultiplier)
					end

					local originalSize = targetPad.Size
					local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
					local tweenUp = TweenService:Create(targetPad, tweenInfo, {Size = originalSize + Vector3.new(0.2, 0.2, 0.2)})
					local tweenDown = TweenService:Create(targetPad, tweenInfo, {Size = originalSize})

					tweenUp:Play()
					tweenUp.Completed:Wait()
					tweenDown:Play()
				end
			end
			task.wait(math.random(1, 3))
		end
	end)
end

local function spawnWorker(player)
	local data = getPlayerData(player)
	local housingPlots = Workspace:FindFirstChild("HousingPlots")
	if not housingPlots then return end

	local playerPlot = housingPlots:FindFirstChild("PlayerHousing_1")
	if not playerPlot then return end

	local workerFolder = playerPlot:FindFirstChild("Worker") or Instance.new("Folder", playerPlot)
	workerFolder.Name = "Worker"

	local workerTemplate = ReplicatedStorage:FindFirstChild("WorkerTemplate")
	if not workerTemplate then
		workerTemplate = Instance.new("Model")
		workerTemplate.Name = "WorkerTemplate"
		local part = Instance.new("Part", workerTemplate)
		part.Name = "HumanoidRootPart"
		part.Size = Vector3.new(2, 2, 2)
		part.Shape = Enum.PartType.Ball
		part.Color = Color3.fromRGB(100, 220, 100)
		Instance.new("Humanoid", workerTemplate)
		workerTemplate.PrimaryPart = part
	end

	local newWorker = workerTemplate:Clone()
	newWorker.Name = "Worker_" .. (#data.SpawnedWorkers + 1)

	local spawnCFrame = CFrame.new(0, 5, 0)
	local zone1 = playerPlot:FindFirstChild("SlimeZone") and playerPlot.SlimeZone:FindFirstChild("Zone_1")
	if zone1 then spawnCFrame = zone1.CFrame * CFrame.new(0, 3, 0) end

	newWorker:PivotTo(spawnCFrame)
	newWorker.Parent = workerFolder

	table.insert(data.SpawnedWorkers, newWorker)
	startWorkerAI(player, newWorker)
end

--------------------------------------------------------------------------------
-- ??? 마우스 클릭 기반 배치 & 회수 통신 (RemoteFunction)
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- ??? 마우스 클릭 기반 배치 & 회수 통신 (RemoteFunction)
--------------------------------------------------------------------------------
placeToppingEvent.OnServerInvoke = function(player, hitPart, hitPosition)
	if not hitPart or not hitPosition then return end

	local character = player.Character
	if not character then return end

	-- 1. 진열되어 있는 '토핑'을 클릭한 경우 -> 회수
	if hitPart:GetAttribute("IsPlacedTopping") then
		local itemName = hitPart:GetAttribute("ToppingName")
		local backpack = player:FindFirstChild("Backpack")

		if backpack then
			-- ?? 인벤토리 및 손에 들고 있는 아이템 개수 확인
			local backpackItems = backpack:GetChildren()
			local holdingTool = character:FindFirstChildOfClass("Tool")

			local totalItemCount = #backpackItems + (holdingTool and 1 or 0)

			-- 아이템이 1개라도 있으면 회수 불가 처리
			if totalItemCount > 0 then
				return "알림", "?? 인벤토리가 비어있을 때만 토핑을 회수할 수 있습니다!"
			end

			-- 인벤토리가 완전히 비어있을 때만 회수 진행
			local templateTool = ReplicatedStorage:FindFirstChild(itemName)
			local retrievedTool = templateTool and templateTool:Clone() or Instance.new("Tool")

			if not templateTool then
				retrievedTool.Name = itemName
				local handle = Instance.new("Part", retrievedTool)
				handle.Name = "Handle"
				handle.Size = Vector3.new(1, 1, 1)
			end

			retrievedTool.Parent = backpack
			hitPart:Destroy()
			return "회수완료", itemName .. " 회수 완료!"
		end
		return
	end

	-- 2. ToppingPad 판을 클릭한 경우 -> 손의 토핑 진열
	if hitPart.Name == "ToppingPad" or hitPart.Parent.Name == "ToppingPad" or hitPart:GetAttribute("IsToppingPad") then
		local holdingTool = character:FindFirstChildOfClass("Tool")
		if holdingTool then
			local itemName = holdingTool.Name

			-- ?? [더러운 토핑 감지 로직]
			local isDirty = (itemName == "dirtyTopping") or string.find(string.lower(itemName), "dirty")

			if isDirty then
				return "알림", "?? 토핑이 더러워서 진열할 수 없습니다! 먼저 세척해 주세요."
			end

			-- 세척된 깨끗한 토핑만 진열 처리
			holdingTool:Destroy()

			-- 클릭한 지점 오프셋 계산 (판 약간 위)
			local spawnPos = hitPosition + Vector3.new(0, 0.6, 0)

			local toppingMesh = Instance.new("Part")
			toppingMesh.Name = "PlacedTopping_" .. itemName
			toppingMesh.Size = Vector3.new(1.2, 1.2, 1.2)
			toppingMesh.Color = Color3.fromRGB(255, 170, 200)
			toppingMesh.Material = Enum.Material.SmoothPlastic
			toppingMesh.Position = spawnPos
			toppingMesh.Anchored = true
			toppingMesh.CanCollide = true
			toppingMesh.CanQuery = true
			toppingMesh:SetAttribute("IsPlacedTopping", true)
			toppingMesh:SetAttribute("ToppingName", itemName)
			toppingMesh.Parent = Workspace

			return "진열완료", itemName .. " 진열 완료!"
		else
			return "알림", "손에 토핑을 들고 판을 클릭하여 진열하세요!"
		end
	end
end
--------------------------------------------------------------------------------
-- Zone 해금 및 플레이어 세팅
--------------------------------------------------------------------------------
local function setupDisplayPad(padObj)
	local padPart = padObj:IsA("BasePart") and padObj or padObj:FindFirstChildWhichIsA("BasePart")
	if not padPart then return end

	padPart.Name = "ToppingPad"
	padPart.Anchored = true
	padPart.CanTouch = true
	padPart.CanQuery = true
	padPart:SetAttribute("IsToppingPad", true)

	local oldPrompt = padPart:FindFirstChildOfClass("ProximityPrompt")
	if oldPrompt then oldPrompt:Destroy() end
end

local function unlockZone(player, housingPlot, zonePart, config)
	local data = getPlayerData(player)
	zonePart.Transparency = 0.2
	zonePart.CanCollide = true
	data.UnlockedZones[zonePart.Name] = true
	refreshActivePads(player, housingPlot)

	local unlockPad = zonePart:FindFirstChild("UnlockPad")
	if unlockPad then unlockPad:Destroy() end

	task.spawn(function()
		local displayPadsFolder = zonePart:WaitForChild("DisplayPads", 5)
		if displayPadsFolder then
			for _, dPad in ipairs(displayPadsFolder:GetChildren()) do setupDisplayPad(dPad) end
			displayPadsFolder.ChildAdded:Connect(setupDisplayPad)
		end
	end)
end

function setupPlayerHousing(player)
	local housingPlots = Workspace:FindFirstChild("HousingPlots")
	if not housingPlots then return end

	local playerPlot = housingPlots:FindFirstChild("PlayerHousing_1")
	if not playerPlot then return end

	local slimeZoneFolder = playerPlot:FindFirstChild("SlimeZone")
	if not slimeZoneFolder then return end

	for zoneName, config in pairs(ZONE_CONFIG) do
		local zonePart = slimeZoneFolder:FindFirstChild(zoneName)
		if zonePart then
			if config.DefaultUnlocked then
				unlockZone(player, playerPlot, zonePart, config)
			else
				zonePart.Transparency = 0.8
				zonePart.CanCollide = false
				local unlockPad = zonePart:FindFirstChild("UnlockPad")
				if unlockPad then
					local prompt = unlockPad:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt", unlockPad)
					prompt.ObjectText = zoneName .. " 구매"
					prompt.ActionText = config.Price .. " Gold (E)"
					prompt.HoldDuration = 0.5
					prompt.RequiresLineOfSight = false

					prompt.Triggered:Connect(function(buyer)
						if buyer ~= player then return end
						local goldStat = getLeaderstat(buyer, GOLD_STAT_NAME)
						if goldStat and goldStat.Value >= config.Price then
							goldStat.Value = goldStat.Value - config.Price
							unlockZone(player, playerPlot, zonePart, config)
						end
					end)
				end
			end
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	getPlayerData(player)
	local stats = Instance.new("Folder", player)
	stats.Name = "leaderstats"
	local gold = Instance.new("IntValue", stats)
	gold.Name = GOLD_STAT_NAME
	gold.Value = 300
	local rebirth = Instance.new("IntValue", stats)
	rebirth.Name = REBIRTH_STAT_NAME
	rebirth.Value = 0

	task.wait(1)
	setupPlayerHousing(player)
end)

workerEvent.OnServerEvent:Connect(function(player, action)
	local data = getPlayerData(player)
	local goldStat = getLeaderstat(player, GOLD_STAT_NAME)

	if action == "BuyWorker" then
		local maxAllowedWorkers = data.RebirthCount + 1
		if #data.SpawnedWorkers >= maxAllowedWorkers then return end
		local price = WORKER_BASE_PRICE * (#data.SpawnedWorkers + 1)
		if goldStat and goldStat.Value >= price then
			goldStat.Value = goldStat.Value - price
			spawnWorker(player)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player) playerData[player.UserId] = nil end)