-- [[ 위치: ServerScriptService > SlimeZoneServer ]]
-- [[ 역할: 마우스 Raycast 클릭 위치 기반 토핑 진열 & 회수 시스템 ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))

-- 리모트 이벤트 세팅
local workerEvent = ReplicatedStorage:FindFirstChild("WorkerShopEvent") or Instance.new("RemoteEvent", ReplicatedStorage)
workerEvent.Name = "WorkerShopEvent"

local placeToppingEvent = ReplicatedStorage:FindFirstChild("PlaceToppingEvent") or Instance.new("RemoteFunction", ReplicatedStorage)
placeToppingEvent.Name = "PlaceToppingEvent"

--------------------------------------------------------------------------------
-- ?? 기본 설정값
--------------------------------------------------------------------------------
local WORKER_BASE_PRICE = 50



local BASE_GOLD_PER_PAD = 10

--------------------------------------------------------------------------------
-- 데이터 세션 관리
--------------------------------------------------------------------------------
local function getPlayerData(player)
	return PlayerDataService.WaitForData(player, 30)
end

local function getRuntime(player)
	return PlayerDataService.GetRuntime(player)
end
local function findPlayerPlot(player)
	local housingPlots = Workspace:FindFirstChild("HousingPlots")
	if not housingPlots then return nil end

	for _, plot in ipairs(housingPlots:GetChildren()) do
		if plot:GetAttribute("OwnerUserId") == player.UserId then return plot end
	end
	for _, plot in ipairs(housingPlots:GetChildren()) do
		if plot:GetAttribute("OwnerUserId") == nil then
			plot:SetAttribute("OwnerUserId", player.UserId)
			return plot
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- Worker AI & 스폰
--------------------------------------------------------------------------------
local function refreshActivePads(player, housingPlot)
	local data = getPlayerData(player)
	local runtime = getRuntime(player)
	if not data or not runtime then return end
	runtime.ActivePads = {}

	local slimeZoneFolder = housingPlot:FindFirstChild("SlimeZone")
	if not slimeZoneFolder then return end
	for zoneName, isUnlocked in pairs(data.UnlockedZones) do
		if isUnlocked then
			local zonePart = slimeZoneFolder:FindFirstChild(zoneName)
			local padsFolder = zonePart and zonePart:FindFirstChild("SlimePads")
			if padsFolder then
				for _, pad in ipairs(padsFolder:GetChildren()) do
					if pad:IsA("BasePart") then table.insert(runtime.ActivePads, pad) end
				end
			end
		end
	end
end
local function startWorkerAI(player, workerModel)
	if workerModel:GetAttribute("WorkerLoopRunning") then return end
	local humanoid = workerModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	for _, part in ipairs(workerModel:GetDescendants()) do
		if part:IsA("BasePart") then part.Anchored = false end
	end

	workerModel:SetAttribute("WorkerLoopRunning", true)
	task.spawn(function()
		while workerModel.Parent and player.Parent do
			local data = getPlayerData(player)
			local runtime = getRuntime(player)
			if not data or not runtime then break end
			local pads = runtime.ActivePads
			if #pads > 0 then
				local targetPad = pads[math.random(1, #pads)]
				if targetPad.Parent then
					humanoid:MoveTo(targetPad.Position)
					if humanoid.MoveToFinished:Wait() then
						local multiplier = data.WorkerIncomeMultiplier or 1
						PlayerDataService.AddGold(player, math.floor(BASE_GOLD_PER_PAD * multiplier))
						local originalSize = targetPad.Size
						local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
						local tweenUp = TweenService:Create(targetPad, tweenInfo, { Size = originalSize + Vector3.new(0.2, 0.2, 0.2) })
						local tweenDown = TweenService:Create(targetPad, tweenInfo, { Size = originalSize })
						tweenUp:Play()
						tweenUp.Completed:Wait()
						if targetPad.Parent then tweenDown:Play() end
					end
				end
			end
			task.wait(math.random(1, 3))
		end
		if workerModel.Parent then workerModel:SetAttribute("WorkerLoopRunning", false) end
	end)
end
local function spawnWorker(player, requestedIndex)
	local data = getPlayerData(player)
	local runtime = getRuntime(player)
	local playerPlot = findPlayerPlot(player)
	if not data or not runtime or not playerPlot then return nil end

	local workerFolder = playerPlot:FindFirstChild("Worker")
	if not workerFolder then
		workerFolder = Instance.new("Folder")
		workerFolder.Name = "Worker"
		workerFolder.Parent = playerPlot
	end

	local workerIndex = requestedIndex or (#runtime.SpawnedWorkers + 1)
	local workerName = "Worker_" .. workerIndex
	local worker = workerFolder:FindFirstChild(workerName)
	if not worker then
		local template = ReplicatedStorage:FindFirstChild("WorkerTemplate")
		if not template then
			template = Instance.new("Model")
			template.Name = "WorkerTemplate"
			local rootPart = Instance.new("Part")
			rootPart.Name = "HumanoidRootPart"
			rootPart.Size = Vector3.new(2, 2, 2)
			rootPart.Shape = Enum.PartType.Ball
			rootPart.Color = Color3.fromRGB(100, 220, 100)
			rootPart.Parent = template
			Instance.new("Humanoid").Parent = template
			template.PrimaryPart = rootPart
		end

		worker = template:Clone()
		worker.Name = workerName
		worker:SetAttribute("WorkerLevel", worker:GetAttribute("WorkerLevel") or 1)
		worker:SetAttribute("GoldMultiplier", worker:GetAttribute("GoldMultiplier") or 1)
		worker:SetAttribute("WalkSpeed", worker:GetAttribute("WalkSpeed") or 12)
		local zone1 = playerPlot:FindFirstChild("SlimeZone") and playerPlot.SlimeZone:FindFirstChild("Zone_1")
		local spawnCFrame = zone1 and (zone1.CFrame * CFrame.new(0, 3, 0)) or CFrame.new(0, 5, 0)
		worker:PivotTo(spawnCFrame)
		worker.Parent = workerFolder
	end

	if not table.find(runtime.SpawnedWorkers, worker) then table.insert(runtime.SpawnedWorkers, worker) end
	data.Workers.Owned = math.max(data.Workers.Owned or 0, workerIndex)
	startWorkerAI(player, worker)
	return worker
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
local function setupPlayerHousing(player)
	local data = getPlayerData(player)
	local playerPlot = findPlayerPlot(player)
	if not data or not playerPlot then return end
	local slimeZoneFolder = playerPlot:FindFirstChild("SlimeZone")
	if not slimeZoneFolder then return end

	for zoneName, config in pairs(ZoneConfig) do
		local zonePart = slimeZoneFolder:FindFirstChild(zoneName)
		if zonePart then
			if config.DefaultUnlocked or data.UnlockedZones[zoneName] then
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
						if buyer == player and PlayerDataService.SpendGold(buyer, config.Price) then
							unlockZone(player, playerPlot, zonePart, config)
						end
					end)
				end
			end
		end
	end
	for workerIndex = 1, (data.Workers.Owned or 0) do
		if not spawnWorker(player, workerIndex) then break end
	end
end
local function initializePlayer(player)
	local data = PlayerDataService.WaitForData(player, 30)
	if not data then return end
	task.wait(1)
	setupPlayerHousing(player)
end

Players.PlayerAdded:Connect(initializePlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(initializePlayer, player)
end
workerEvent.OnServerEvent:Connect(function(player, action)
	local data = getPlayerData(player)
	local runtime = getRuntime(player)
	if not data or not runtime then return end

	if action == "BuyWorker" then
		local maxAllowedWorkers = 1 + (data.MaxWorkerBonus or 0)
		if #runtime.SpawnedWorkers >= maxAllowedWorkers then return end
		local price = WORKER_BASE_PRICE * (#runtime.SpawnedWorkers + 1)
		if PlayerDataService.SpendGold(player, price) then
			spawnWorker(player)
		end
	end
end)

