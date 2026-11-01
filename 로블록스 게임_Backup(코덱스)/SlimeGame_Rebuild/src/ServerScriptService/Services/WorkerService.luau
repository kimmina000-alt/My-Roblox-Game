local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CurrencyService = require(script.Parent.CurrencyService)
local PlotService = require(script.Parent.PlotService)
local SlimePadIncomeService = require(script.Parent.SlimePadIncomeService)
local InventoryService = require(script.Parent.InventoryService)
local RemoteService = require(script.Parent.RemoteService)

local WorkerService = {}
local workerFractions = {}
local workerStates = setmetatable({}, { __mode = "k" })
local boundPrompts = setmetatable({}, { __mode = "k" })

local function getWorkerFolder(plot)
	local folder = plot:FindFirstChild("Workers")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Workers"
		folder.Parent = plot
	end
	return folder
end

local function relativePath(root, target)
	local names, node = {}, target
	while node and node ~= root do table.insert(names, 1, node.Name); node = node.Parent end
	return node == root and table.concat(names, "/") or nil
end

local function resolvePath(root, path)
	local node = root
	for segment in string.gmatch(path or "", "[^/]+") do
		node = node:FindFirstChild(segment)
		if not node then return nil end
	end
	return node
end

local function zoneIsUnlocked(plot, pad, data)
	local padId = pad:GetAttribute("PadId")
	if padId and data.UnlockedPads[padId] ~= true then return false end
	local node = pad
	while node and node ~= plot do
		if node:IsA("Model") and node.Name:match("^Zone_%d+$") then
			return data.UnlockedZones[node.Name] == true
		end
		node = node.Parent
	end
	return false
end

local function publishInventory(player)
	local snapshot = InventoryService.GetSnapshot(player)
	if snapshot then RemoteService.Get("InventoryUpdated"):FireClient(player, snapshot) end
end

local function setPlacementSelected(player, selected)
	local data = PlayerDataService.Get(player)
	if not data then return false, "데이터를 불러오는 중입니다." end
	if selected and data.Workers.BagCount <= 0 then return false, "가방에 배치할 노동자가 없습니다." end
	data.Workers.SelectedForPlacement = selected == true
	RemoteService.Get("WorkerSelectionChanged"):FireClient(player, data.Workers.SelectedForPlacement)
	publishInventory(player)
	return true, data.Workers.SelectedForPlacement and "노동자를 선택했습니다. 베이스 슬라임을 클릭하거나 E를 눌러 배치하세요." or "노동자 선택을 해제했습니다."
end

local function createWorkerToken(player)
	local data = PlayerDataService.Get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not data or not backpack then return end
	local character = player.Character
	local token
	for _, container in ipairs({ backpack, character }) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and child:GetAttribute("SlimeGameWorkerToken") == true then
					token = child
					break
				end
			end
		end
		if token then break end
	end
	if data.Workers.BagCount <= 0 then
		if token then token:Destroy() end
		return
	end
	if not token then
		token = Instance.new("Tool")
		token.Name = "노동자"
		token.RequiresHandle = true
		token.CanBeDropped = false
		token:SetAttribute("SlimeGameWorkerToken", true)
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Shape = Enum.PartType.Ball
		handle.Size = Vector3.new(1.1, 1.1, 1.1)
		handle.Color = Color3.fromRGB(245, 205, 145)
		handle.Material = Enum.Material.SmoothPlastic
		handle.CanCollide, handle.CanTouch, handle.CanQuery, handle.Massless = false, false, false, true
		handle.Parent = token
		token.Equipped:Connect(function()
			local current = PlayerDataService.Get(player)
			if current and current.Workers.BagCount > 0 then setPlacementSelected(player, true) end
		end)
		token.Unequipped:Connect(function()
			local current = PlayerDataService.Get(player)
			if current and current.Workers.BagCount > 0 then setPlacementSelected(player, false) end
		end)
		token.Parent = backpack
	end
	token.Name = "노동자 ×" .. data.Workers.BagCount
	token:SetAttribute("StackCount", data.Workers.BagCount)
	if token.Parent ~= character and token.Parent ~= backpack then token.Parent = backpack end
end

local function findWalkAnimationId(character)
	local animate = character and character:FindFirstChild("Animate")
	if not animate then return nil end
	local runFallback
	for _, object in ipairs(animate:GetDescendants()) do
		if object:IsA("Animation") and object.AnimationId ~= "" then
			local name = string.lower(object.Name)
			if string.find(name, "walk") then return object.AnimationId end
			if string.find(name, "run") then runFallback = object.AnimationId end
		end
	end
	return runFallback
end

local function cloneCharacter(player)
	local character = player.Character
	if not character then return nil end
	local oldArchivable = character.Archivable
	character.Archivable = true
	local ok, clone = pcall(function() return character:Clone() end)
	character.Archivable = oldArchivable
	if ok then return clone end
	warn("[WorkerService] Could not clone player avatar: " .. tostring(clone))
	return nil
end

local function playWalkAnimation(worker, animationId)
	local humanoid = worker:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	animationId = animationId or (humanoid.RigType == Enum.HumanoidRigType.R6
		and "rbxassetid://180426354" or "rbxassetid://507777826")
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
	animation:Destroy()
	if not ok or not track then warn("[WorkerService] Could not load walk animation: " .. tostring(track)); return end
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Movement
	humanoid.Running:Connect(function(speed)
		if not track.Parent then return end
		if speed > 0.5 then
			if not track.IsPlaying then track:Play(0.12) end
		elseif track.IsPlaying then
			track:Stop(0.18)
		end
	end)
end

local function createWorkerModel(player, plot, workerId)
	local worker = cloneCharacter(player)
	local animationId = findWalkAnimationId(worker)
	if not worker then
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local template = ReplicatedStorage:FindFirstChild("WorkerTemplate") or (assets and assets:FindFirstChild("WorkerTemplate"))
		if template and template:IsA("Model") then worker = template:Clone() end
	end
	if not worker or not worker:FindFirstChildOfClass("Humanoid") then
		if worker then worker:Destroy() end
		return nil
	end
	worker.Name = "Worker_" .. workerId
	worker:SetAttribute("OwnerUserId", player.UserId)
	worker:SetAttribute("WorkerId", workerId)
	for _, object in ipairs(worker:GetDescendants()) do
		if object:IsA("Script") or object:IsA("LocalScript") or object:IsA("Tool")
			or object:IsA("ProximityPrompt") or object:IsA("ClickDetector") or object:IsA("ForceField") then
			object:Destroy()
		elseif object:IsA("BasePart") and object.Parent and object.Parent:IsA("Accessory") then
			object.CanCollide, object.CanTouch, object.CanQuery, object.Massless = false, false, false, true
		end
	end
	local humanoid = worker:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.NameDisplayDistance, humanoid.HealthDisplayDistance = 0, 0
	humanoid.AutoRotate = true
	local root = worker:FindFirstChild("HumanoidRootPart", true)
	if not root or not root:IsA("BasePart") then worker:Destroy(); return nil end
	worker.PrimaryPart = root
	for _, object in ipairs(worker:GetDescendants()) do
		if object:IsA("BasePart") then object.Anchored = false end
	end
	worker.Parent = getWorkerFolder(plot)
	pcall(function() root:SetNetworkOwner(nil) end)
	playWalkAnimation(worker, animationId)
	return worker
end

local function getUnlockedPads(plot, data)
	local entries, byPath = {}, {}
	local zones = plot:FindFirstChild("SlimeZone")
	if not zones then return entries, byPath end
	for zoneName, unlocked in pairs(data.UnlockedZones or {}) do
		local zone = unlocked and zones:FindFirstChild(zoneName)
		if zone then
			for _, pad in ipairs(zone:GetDescendants()) do
				if pad:IsA("BasePart") and pad:GetAttribute("IsBasePad") == true
					and data.UnlockedPads[pad:GetAttribute("PadId")] == true then
					local path = relativePath(plot, pad)
					local baseRecord
					for _, record in ipairs(data.PlacedBases or {}) do
						if record.PadPath == path then baseRecord = record; break end
					end
					local surface = baseRecord and plot:FindFirstChild("PlacedBases")
						and plot.PlacedBases:FindFirstChild("PlacedBase_" .. baseRecord.PlacementId)
					local entry = { Pad = pad, Path = path, Rate = SlimePadIncomeService.CalculateRate(data, path), Surface = surface }
					table.insert(entries, entry)
					byPath[path] = entry
				end
			end
		end
	end
	table.sort(entries, function(a, b) return a.Path < b.Path end)
	return entries, byPath
end

local function getRandomTarget(entry, humanoid)
	local pad = entry.Pad
	local margin = math.min(GameConfig.Workers.MovementMargin, math.max(0.5, math.min(pad.Size.X, pad.Size.Z) / 3))
	local x = (math.random() * 2 - 1) * math.max(0.25, pad.Size.X / 2 - margin)
	local z = (math.random() * 2 - 1) * math.max(0.25, pad.Size.Z / 2 - margin)
	local topY = entry.Surface and entry.Surface.Parent
		and (entry.Surface.Position.Y + entry.Surface.Size.Y / 2)
		or (pad.Position.Y + pad.Size.Y / 2)
	local world = pad.CFrame:PointToWorldSpace(Vector3.new(x, 0, z))
	return Vector3.new(world.X, topY + humanoid.HipHeight + 1, world.Z)
end

local function countWorkerSteps(state, entry, root, humanoid, elapsed)
	if not entry.Surface or not entry.Surface.Parent then
		state.LastPosition, state.Progress = nil, 0
		return 0
	end
	local localPosition = entry.Pad.CFrame:PointToObjectSpace(root.Position)
	local topY = entry.Surface and entry.Surface.Parent
		and (entry.Surface.Position.Y + entry.Surface.Size.Y / 2)
		or (entry.Pad.Position.Y + entry.Pad.Size.Y / 2)
	local onPad = math.abs(localPosition.X) <= entry.Pad.Size.X / 2
		and math.abs(localPosition.Z) <= entry.Pad.Size.Z / 2
		and root.Position.Y >= topY + 1 and root.Position.Y <= topY + 9
	if not onPad then state.LastPosition, state.Progress = nil, 0; return 0 end
	local steps = 0
	if state.LastPosition then
		local delta = root.Position - state.LastPosition
		local distance = Vector3.new(delta.X, 0, delta.Z).Magnitude
		distance = math.min(distance, math.max(0.5, humanoid.WalkSpeed * elapsed * 1.5))
		state.Progress = (state.Progress or 0) + distance
		local stepLength = GameConfig.SlimePadIncome.StudsPerStep
		steps = math.floor(state.Progress / stepLength)
		state.Progress -= steps * stepLength
	else
		state.Progress = 0
	end
	state.LastPosition = root.Position
	return steps
end

local function guideWorker(worker, homeEntry, routeEntries, entriesByPath, walkSpeed, elapsed)
	local humanoid = worker:FindFirstChildOfClass("Humanoid")
	local root = worker:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then return 0 end
	humanoid.WalkSpeed = walkSpeed
	local state = workerStates[worker] or {}
	workerStates[worker] = state
	if #routeEntries == 0 then
		if state.Path then humanoid:MoveTo(root.Position) end
		state.Path, state.Target, state.NextTargetAt, state.LastPosition, state.Progress = nil, nil, nil, nil, 0
		return 0
	end
	local entry = entriesByPath[state.Path]
	if not entry then
		entry = homeEntry or routeEntries[1]
		state.Path, state.Target, state.NextTargetAt, state.LastPosition, state.Progress = entry.Path, nil, 0, nil, 0
		worker:PivotTo(CFrame.new(getRandomTarget(entry, humanoid)))
	end
	local now = os.clock()
	if not state.Target or (root.Position - state.Target).Magnitude <= GameConfig.Workers.TargetReachDistance
		or now >= (state.NextTargetAt or 0) then
		-- Walk the unlocked pads in a stable loop. Random selection could repeatedly
		-- choose the home pad and make newly unlocked zones look unreachable.
		local currentIndex = table.find(routeEntries, entry) or 0
		local nextIndex = (currentIndex % #routeEntries) + 1
		local nextEntry = routeEntries[nextIndex]
		if nextEntry.Path ~= entry.Path then
			state.LastPosition, state.Progress = nil, 0
		end
		entry = nextEntry
		state.Path = entry.Path
		local target = getRandomTarget(entry, humanoid)
		local distance = (root.Position - target).Magnitude
		state.Target = target
		state.NextTargetAt = now + math.max(2, distance / math.max(walkSpeed, 1) + 1)
		humanoid:MoveTo(target)
	end
	entry = entriesByPath[state.Path]
	if not entry then return 0 end
	return countWorkerSteps(state, entry, root, humanoid, elapsed)
end

local function ensurePlacedModels(player, plot, records)
	local folder = getWorkerFolder(plot)
	local wanted = {}
	for _, record in ipairs(records or {}) do
		local workerId = math.floor(tonumber(record.WorkerId) or 0)
		if workerId > 0 then
			local name = "Worker_" .. workerId
			wanted[name] = true
			if not folder:FindFirstChild(name) then createWorkerModel(player, plot, workerId) end
		end
	end
	for _, worker in ipairs(folder:GetChildren()) do
		if not wanted[worker.Name] then workerStates[worker] = nil; worker:Destroy() end
	end
end

local function syncPromptOccupancy(plot, data)
	local occupied = {}
	for _, record in ipairs(data.Workers.Placed or {}) do occupied[record.PadPath] = true end
	local hasBase = {}
	for _, record in ipairs(data.PlacedBases or {}) do hasBase[record.PadPath] = true end
	for _, pad in ipairs(plot:FindFirstChild("SlimeZone") and plot.SlimeZone:GetDescendants() or {}) do
		if pad:IsA("BasePart") and pad:GetAttribute("IsBasePad") == true then
			local prompt = pad:FindFirstChild("WorkerPlacePrompt")
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt:SetAttribute("PadOccupied", occupied[relativePath(plot, pad)] == true)
				prompt:SetAttribute("HasPlacedBase", hasBase[relativePath(plot, pad)] == true)
				prompt.Enabled = zoneIsUnlocked(plot, pad, data)
			end
		end
	end
end

local function publishWorkerState(player, plot, data)
	createWorkerToken(player)
	syncPromptOccupancy(plot, data)
	PlayerDataService.Sync(player)
	publishInventory(player)
	RemoteService.Get("WorkerSelectionChanged"):FireClient(player, data.Workers.SelectedForPlacement == true)
end

local function placeWorker(player, plot, pad)
	local data = PlayerDataService.Get(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not data or not root or PlotService.GetPlot(player) ~= plot or not pad:IsDescendantOf(plot)
		or pad:GetAttribute("IsBasePad") ~= true or not zoneIsUnlocked(plot, pad, data) then return end
	if (root.Position - pad.Position).Magnitude > 12 then return end
	if not data.Workers.SelectedForPlacement or data.Workers.BagCount <= 0 then return end
	local path = relativePath(plot, pad)
	local hasBase = false
	for _, base in ipairs(data.PlacedBases or {}) do
		if base.PadPath == path then hasBase = true; break end
	end
	if not hasBase then return end
	for _, record in ipairs(data.Workers.Placed) do
		if record.PadPath == path then return end
	end
	local usedIds = {}
	for _, record in ipairs(data.Workers.Placed) do usedIds[tonumber(record.WorkerId)] = true end
	local workerId
	for candidate = 1, data.Workers.Owned do
		if not usedIds[candidate] then workerId = candidate; break end
	end
	if not workerId then return end
	table.insert(data.Workers.Placed, { WorkerId = workerId, PadPath = path })
	data.Workers.BagCount -= 1
	data.Workers.SelectedForPlacement = data.Workers.BagCount > 0
	ensurePlacedModels(player, plot, data.Workers.Placed)
	publishWorkerState(player, plot, data)
	return true, "노동자를 베이스 위에 배치했습니다."
end

local function findOpenBasedPad(plot, data)
	if not plot then return nil end
	local occupied = {}
	for _, record in ipairs(data.Workers.Placed or {}) do
		occupied[record.PadPath] = true
	end
	local _, entriesByPath = getUnlockedPads(plot, data)
	for _, base in ipairs(data.PlacedBases or {}) do
		local entry = entriesByPath[base.PadPath]
		if entry and entry.Surface and entry.Surface.Parent and not occupied[base.PadPath] then
			return entry
		end
	end
	return nil
end

local function bindPlotPrompts(player, plot)
	local zones = plot and plot:FindFirstChild("SlimeZone")
	if not zones then return end
	for _, pad in ipairs(zones:GetDescendants()) do
		if pad:IsA("BasePart") and pad:GetAttribute("IsBasePad") == true then
			local prompt = pad:FindFirstChild("WorkerPlacePrompt")
			if not prompt then
				prompt = Instance.new("ProximityPrompt")
				prompt.Name = "WorkerPlacePrompt"
				prompt.ActionText = "노동자 배치"
				prompt.ObjectText = "빈 패드"
				prompt.MaxActivationDistance = 8
				prompt.RequiresLineOfSight = false
				prompt.HoldDuration = 0
				prompt.Parent = pad
			end
			prompt.Enabled = true
			prompt:SetAttribute("WorkerPlacePrompt", true)
			prompt:SetAttribute("OwnerUserId", player.UserId)
			if not boundPrompts[prompt] then
				boundPrompts[prompt] = true
				local capturedPad = pad
				prompt.Triggered:Connect(function(triggeringPlayer)
					placeWorker(triggeringPlayer, plot, capturedPad)
				end)
			end
		end
	end
	local data = PlayerDataService.Get(player)
	if data then syncPromptOccupancy(plot, data) end
end

local function tickPlayer(player, elapsed)
	local data, plot = PlayerDataService.Get(player), PlotService.GetPlot(player)
	if not data or not plot then return end
	data.Workers.Placed = type(data.Workers.Placed) == "table" and data.Workers.Placed or {}
	ensurePlacedModels(player, plot, data.Workers.Placed)
	local routeEntries, entriesByPath = getUnlockedPads(plot, data)
	local level = math.clamp(math.floor(tonumber(data.Workers.Upgrades.IncomeLevel) or 0), 0, GameConfig.Workers.MaximumUpgradeLevel)
	local walkSpeed = math.min(GameConfig.Workers.BaseWalkSpeed + level * GameConfig.Workers.WalkSpeedPerUpgrade,
		GameConfig.Workers.MaximumWalkSpeed)
	local incomeMultiplier = (tonumber(data.Workers.IncomeMultiplier) or 1)
		* (1 + level * GameConfig.Workers.IncomeBonusPerUpgrade)
	local folder = getWorkerFolder(plot)
	local totalReward = 0
	for _, record in ipairs(data.Workers.Placed) do
		local workerId = math.floor(tonumber(record.WorkerId) or 0)
		local worker = workerId > 0 and folder:FindFirstChild("Worker_" .. workerId)
		local homeEntry = entriesByPath[record.PadPath]
		if worker and homeEntry then
			local steps = guideWorker(worker, homeEntry, routeEntries, entriesByPath, walkSpeed, elapsed)
			local entry = entriesByPath[workerStates[worker] and workerStates[worker].Path]
			local reward = entry and steps * entry.Rate * incomeMultiplier or 0
			if reward > 0 then
				totalReward += reward
				RemoteService.Get("WorkerIncomeFeedback"):FireClient(player, worker, reward)
			end
		elseif worker then
			guideWorker(worker, nil, routeEntries, entriesByPath, walkSpeed, elapsed)
		end
	end
	if totalReward > 0 then
		local balance = (workerFractions[player] or 0) + totalReward
		local payout = math.floor(balance)
		workerFractions[player] = balance - payout
		if payout > 0 then CurrencyService.AddGold(player, payout) end
	end
end

local function bindPlayer(player)
	local function onCharacter()
		task.delay(0.3, function()
			if player.Parent then createWorkerToken(player) end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	task.spawn(function()
		if not PlayerDataService.WaitFor(player, 30) then return end
		local deadline = os.clock() + 30
		local plot
		while player.Parent and not plot and os.clock() < deadline do
			plot = PlotService.GetPlot(player)
			if not plot then task.wait(0.2) end
		end
		if not plot then return end
		bindPlotPrompts(player, plot)
		createWorkerToken(player)
		ensurePlacedModels(player, plot, PlayerDataService.Get(player).Workers.Placed)
		RemoteService.Get("WorkerSelectionChanged"):FireClient(player, false)
	end)
end

function WorkerService.Sync(player)
	local data, plot = PlayerDataService.Get(player), PlotService.GetPlot(player)
	if not data or not plot then return end
	ensurePlacedModels(player, plot, data.Workers.Placed)
	bindPlotPrompts(player, plot)
	publishWorkerState(player, plot, data)
end

function WorkerService.Init()
	Players.PlayerRemoving:Connect(function(player) workerFractions[player] = nil end)
	Players.PlayerAdded:Connect(bindPlayer)
	for _, player in ipairs(Players:GetPlayers()) do bindPlayer(player) end

	RemoteService.Get("WorkerAction").OnServerInvoke = function(player, action, pad)
		local data = PlayerDataService.WaitFor(player, 30)
		if not data then return false, "데이터를 불러오는 중입니다." end
		data.Workers.Upgrades = type(data.Workers.Upgrades) == "table" and data.Workers.Upgrades or {}
		if action == "Buy" then
			local limit = 1 + data.Workers.ExtraSlots
			if data.Workers.Owned >= limit then return false, ("고용 한도에 도달했습니다. 현재 %d명까지 가능합니다."):format(limit) end
			local price = 50 * (data.Workers.Owned + 1)
			if not CurrencyService.SpendGold(player, price) then return false, ("골드가 부족합니다. 고용 비용은 %dG입니다."):format(price) end
			data.Workers.Owned += 1
			data.Workers.SelectedForPlacement = false
			local plot = PlotService.GetPlot(player)
			local entry = findOpenBasedPad(plot, data)
			if entry then
				table.insert(data.Workers.Placed, { WorkerId = data.Workers.Owned, PadPath = entry.Path })
				ensurePlacedModels(player, plot, data.Workers.Placed)
				publishWorkerState(player, plot, data)
				return true, "노동자를 베이스 슬라임 위에 배치했습니다. 이제 패드 위를 돌아다니며 골드를 벌어요.", data.Workers.BagCount
			end
			data.Workers.BagCount += 1
			if plot then publishWorkerState(player, plot, data) else
				createWorkerToken(player)
				publishInventory(player)
				PlayerDataService.Sync(player)
			end
			return true, "배치할 수 있는 베이스 패드가 없어 노동자를 인벤토리에 넣었습니다.", data.Workers.BagCount
		elseif action == "SelectForPlacement" then
			return setPlacementSelected(player, true)
		elseif action == "CancelPlacement" then
			return setPlacementSelected(player, false)
		elseif action == "PlaceAtPad" then
			local plot = PlotService.GetPlot(player)
			if not plot or typeof(pad) ~= "Instance" or not pad:IsA("BasePart") then
				return false, "배치할 베이스 패드를 찾지 못했습니다."
			end
			local ok, message = placeWorker(player, plot, pad)
			if not ok then return false, "빈 베이스 패드를 확인하고 가까이에서 다시 시도하세요." end
			return true, message
		elseif action == "UpgradeIncome" then
			if data.Workers.Owned <= 0 then return false, "먼저 노동자를 고용해 주세요." end
			local level = math.clamp(math.floor(tonumber(data.Workers.Upgrades.IncomeLevel) or 0), 0, GameConfig.Workers.MaximumUpgradeLevel)
			if level >= GameConfig.Workers.MaximumUpgradeLevel then return false, "노동자 강화가 최대 레벨입니다." end
			local price = math.floor(GameConfig.Workers.UpgradeBaseCost * GameConfig.Workers.UpgradeCostGrowth ^ level)
			if not CurrencyService.SpendGold(player, price) then return false, ("골드가 부족합니다. 다음 강화 비용은 %dG입니다."):format(price) end
			local oldSpeed = math.min(GameConfig.Workers.BaseWalkSpeed + level * GameConfig.Workers.WalkSpeedPerUpgrade,
				GameConfig.Workers.MaximumWalkSpeed)
			level += 1
			data.Workers.Upgrades.IncomeLevel = level
			local newSpeed = math.min(GameConfig.Workers.BaseWalkSpeed + level * GameConfig.Workers.WalkSpeedPerUpgrade,
				GameConfig.Workers.MaximumWalkSpeed)
			return true, ("노동자 Lv.%d 강화: 속도 %d→%d, 걸음 수익 +25%% (비용 %dG)"):format(level, oldSpeed, newSpeed, price), level
		end
		return false, "알 수 없는 요청입니다."
	end

	task.spawn(function()
		local lastTick = os.clock()
		while true do
			task.wait(GameConfig.SlimePadIncome.TickSeconds)
			local now = os.clock()
			local elapsed = math.min(now - lastTick, GameConfig.SlimePadIncome.TickSeconds * 3)
			lastTick = now
			for _, player in ipairs(Players:GetPlayers()) do tickPlayer(player, elapsed) end
		end
	end)
end

return WorkerService
