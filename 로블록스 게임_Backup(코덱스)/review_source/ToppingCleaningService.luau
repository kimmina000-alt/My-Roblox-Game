-- [[ 위치: ServerScriptService > ToppingCleaningService ]]
-- [[ 역할: 더러운 토핑 지급, 세척 시스템, 슬라임 확률형 결과 처리, 도구 동기화 삭제 및 자동 착용 ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ItemDataModule = require(ReplicatedStorage:WaitForChild("ItemDataModule"))

--------------------------------------------------------------------------------
-- 1. 통신용 RemoteFunction / RemoteEvent 생성
--------------------------------------------------------------------------------
local cleanToppingEvent = ReplicatedStorage:FindFirstChild("CleanToppingEvent")
if not cleanToppingEvent then
	cleanToppingEvent = Instance.new("RemoteFunction")
	cleanToppingEvent.Name = "CleanToppingEvent"
	cleanToppingEvent.Parent = ReplicatedStorage
end

local toolActionEvent = ReplicatedStorage:FindFirstChild("ToolActionEvent")
if not toolActionEvent then
	toolActionEvent = Instance.new("RemoteEvent")
	toolActionEvent.Name = "ToolActionEvent"
	toolActionEvent.Parent = ReplicatedStorage
end

--------------------------------------------------------------------------------
-- 2. 토핑 데이터 정의
--------------------------------------------------------------------------------
--local TOPPING_DATA = {
--	{ Name = "구슬 토핑", Weight = 50, Rarity = "Common", SoundId = "rbxassetid://9114223160" },
--	{ Name = "크런치 폼볼", Weight = 30, Rarity = "Rare", SoundId = "rbxassetid://9114223160" },
--	{ Name = "바삭한 칩", Weight = 15, Rarity = "Epic", SoundId = "rbxassetid://9114223160" },
--	{ Name = "갤럭시 펄", Weight = 5, Rarity = "Legendary", SoundId = "rbxassetid://9114223160" }
--}

--local function getRandomTopping()
--	local totalWeight = 0
--	for _, data in ipairs(TOPPING_DATA) do totalWeight += data.Weight end
--	local rand = math.random(1, totalWeight)
--	local current = 0
--	for _, data in ipairs(TOPPING_DATA) do
--		current += data.Weight
--		if rand <= current then return data end
--	end
--	return TOPPING_DATA[1]
--end
local function getRandomTopping()
	local toppings = ItemDataModule.GetItemsByCategory(ItemDataModule.Category.Topping)
	local itemList = {}
	local totalWeight = 0

	for name, data in pairs(toppings) do
		local rarityInfo = ItemDataModule.Rarity[data.Rarity]
		local weight = rarityInfo and rarityInfo.Weight or 10
		totalWeight += weight
		table.insert(itemList, { Name = name, Data = data, Weight = weight })
	end

	local rand = math.random(1, totalWeight)
	local current = 0
	for _, item in ipairs(itemList) do
		current += item.Weight
		if rand <= current then
			return {
				Name = item.Name,
				Rarity = item.Data.Rarity,
				SoundId = item.Data.SoundId
			}
		end
	end
end
--------------------------------------------------------------------------------
-- 3. 더러운 토핑 Tool 생성 함수
--------------------------------------------------------------------------------
local function createDirtyToppingTool()
	local tool = Instance.new("Tool")
	tool.Name = "DirtyTopping"
	tool.RequiresHandle = true

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1.2, 1.2, 1.2)
	handle.Color = Color3.fromRGB(110, 85, 60)
	handle.Material = Enum.Material.Mud
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	return tool
end

--------------------------------------------------------------------------------
-- 4. 토핑 머신 ProximityPrompt 연결
--------------------------------------------------------------------------------
local function bindToppingMachine(machinePart)
	if not machinePart then return end

	local prompt = machinePart:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.ObjectText = "토핑 추출기"
		prompt.ActionText = "더러운 토핑 뽑기"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = machinePart
	end

	prompt.Triggered:Connect(function(player)
		local backpack = player:FindFirstChild("Backpack")
		local character = player.Character

		local hasTool = false
		if backpack then
			for _, item in ipairs(backpack:GetChildren()) do
				if item:IsA("Tool") then hasTool = true; break end
			end
		end
		if character and not hasTool then
			for _, item in ipairs(character:GetChildren()) do
				if item:IsA("Tool") then hasTool = true; break end
			end
		end

		if hasTool then return end

		if character then
			local dirtyTool = createDirtyToppingTool()
			local humanoid = character:FindFirstChildOfClass("Humanoid")

			-- ?? [수정] 생성 즉시 손에 착용하도록 설정
			if humanoid then
				dirtyTool.Parent = backpack
				humanoid:EquipTool(dirtyTool)
			else
				dirtyTool.Parent = backpack
			end
		end
	end)
end

task.spawn(function()
	task.wait(1)
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj.Name == "ToppingMachine" then
			bindToppingMachine(obj)
		end
	end
end)

--------------------------------------------------------------------------------
-- 5. 클라이언트 요청 처리 (진열/버리기)
--------------------------------------------------------------------------------
toolActionEvent.OnServerEvent:Connect(function(player, action, tool)
	if action == "DestroyTool" and tool and tool:IsA("Tool") then
		if tool.Parent == player.Backpack or tool.Parent == player.Character then
			tool:Destroy()
		end
	elseif action == "DropTool" and tool and tool:IsA("Tool") then
		local char = player.Character
		if char and (tool.Parent == player.Backpack or tool.Parent == char) then
			tool.Parent = Workspace
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildOfClass("BasePart")
			if hrp and handle then
				handle.CFrame = hrp.CFrame * CFrame.new(0, 0, -3.5)
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- 6. 세척 검증 및 보상 지급 (RemoteFunction)
--------------------------------------------------------------------------------
local activeSessions = {}

cleanToppingEvent.OnServerInvoke = function(player, action)
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character

	local dirtyTool = nil
	if character then dirtyTool = character:FindFirstChild("DirtyTopping") end
	if not dirtyTool and backpack then dirtyTool = backpack:FindFirstChild("DirtyTopping") end

	if action == "Start" then
		if not dirtyTool then return { Success = false, Reason = "더러운 토핑이 없습니다." } end
		activeSessions[player.UserId] = true
		return { Success = true }

	elseif action == "Complete" then
		if not activeSessions[player.UserId] then return { Success = false, Reason = "세션 오류" } end
		if not dirtyTool then return { Success = false, Reason = "토핑이 사라졌습니다." } end

		activeSessions[player.UserId] = nil
		dirtyTool:Destroy() -- 세척 완료 시 기존 더러운 토핑 삭제

		-- 세척 완료 보상 토핑 생성
		local rewardData = getRandomTopping()
		local newTool = Instance.new("Tool")
		newTool.Name = rewardData.Name
		newTool.RequiresHandle = true

		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(1, 1, 1)
		handle.Material = Enum.Material.SmoothPlastic

		if rewardData.Name == "구슬 토핑" or rewardData.Name == "크런치 폼볼" then
			handle.Shape = Enum.PartType.Ball
		end
		handle.Parent = newTool

		-- ?? [수정] 세척 완료 후 새 토핑 바로 손에 들기
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and backpack then
				newTool.Parent = backpack
				humanoid:EquipTool(newTool)
			else
				newTool.Parent = backpack
			end
		end

		return { Success = true, Topping = rewardData }
	end

	return { Success = false, Reason = "잘못된 요청" }
end