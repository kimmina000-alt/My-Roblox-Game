-- [[ 위치: ServerScriptService > DisplayShelfServer ]]
-- [[ 역할: 3D Y축 위치 정정(위:1~5 / 아래:6~10), 인벤토리 1개 소지 제한 검증, 진열 및 회수 ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local displayEvent = ReplicatedStorage:FindFirstChild("DisplayEvent")
if not displayEvent then
	displayEvent = Instance.new("RemoteEvent")
	displayEvent.Name = "DisplayEvent"
	displayEvent.Parent = ReplicatedStorage
end

--------------------------------------------------------------------------------
-- ?? 설정값
--------------------------------------------------------------------------------
local MAX_SLOTS = 10 
local SHELF_COLUMNS = 5

local shelfData = {}  -- { [UserId] = { [1] = "DirtyTopping", [2] = false, ... } }
local shelfParts = {} -- { [UserId] = { [1] = Part, ... } }

--------------------------------------------------------------------------------
-- 3D 위치 동적 계산 함수 (수정: Row 1이 위쪽, Row 2가 아래쪽)
--------------------------------------------------------------------------------
local function getSlotCFrame(shelfPart, slotIndex)
	local size = shelfPart.Size
	local cf = shelfPart.CFrame

	local totalRows = math.ceil(MAX_SLOTS / SHELF_COLUMNS)
	local col = ((slotIndex - 1) % SHELF_COLUMNS) + 1  -- 1 ~ 5
	local row = math.ceil(slotIndex / SHELF_COLUMNS)     -- 1 (윗줄), 2 (아랫줄)

	local cellWidth = size.X / SHELF_COLUMNS
	local cellHeight = size.Y / totalRows

	-- X축: 왼쪽(-X) -> 오른쪽(+X)
	local offsetX = - (size.X / 2) + (cellWidth * (col - 0.5))

	-- Y축: Row 1을 위쪽(+Y), Row 2를 아래쪽(-Y)으로 배치
	local offsetY = (size.Y / 2) - (cellHeight * (row - 0.5))

	-- Z축: 진열장 정면 살짝 앞
	local offsetZ = (size.Z / 2) + 0.4

	return cf * CFrame.new(offsetX, offsetY, offsetZ)
end

--------------------------------------------------------------------------------
-- 3D 파트 업데이트
--------------------------------------------------------------------------------
local function update3DShelf(player)
	local userId = player.UserId
	local pData = shelfData[userId]
	if not pData then return end

	local shelfPart = Workspace:FindFirstChild("DisplayShelf")
	if not shelfPart then return end

	if not shelfParts[userId] then
		shelfParts[userId] = {}
	end

	for slot = 1, MAX_SLOTS do
		local itemName = pData[slot]
		local existingPart = shelfParts[userId][slot]

		if itemName and itemName ~= false then
			if not existingPart then
				local newPart = Instance.new("Part")
				newPart.Name = "Displayed_Slot_" .. slot
				newPart.Size = Vector3.new(0.8, 0.8, 0.8)
				newPart.Material = Enum.Material.SmoothPlastic
				newPart.Color = Color3.fromRGB(180, 140, 100)
				newPart.Anchored = true
				newPart.CanCollide = false
				newPart.CFrame = getSlotCFrame(shelfPart, slot)
				newPart.Parent = Workspace

				local bb = Instance.new("BillboardGui")
				bb.Size = UDim2.new(0, 90, 0, 30)
				bb.StudsOffset = Vector3.new(0, 0.8, 0)
				bb.AlwaysOnTop = true
				bb.Parent = newPart

				local txt = Instance.new("TextLabel")
				txt.Size = UDim2.new(1, 0, 1, 0)
				txt.BackgroundTransparency = 1
				txt.Text = "[" .. slot .. "] " .. itemName
				txt.TextColor3 = Color3.fromRGB(255, 255, 255)
				txt.TextScaled = true
				txt.Font = Enum.Font.FredokaOne
				txt.Parent = bb

				shelfParts[userId][slot] = newPart
			else
				existingPart.CFrame = getSlotCFrame(shelfPart, slot)
			end
		else
			if existingPart then
				existingPart:Destroy()
				shelfParts[userId][slot] = nil
			end
		end
	end
end

--------------------------------------------------------------------------------
-- 플레이어 소지 아이템 개수 확인 (손 + 백팩)
--------------------------------------------------------------------------------
local function getInventoryItemCount(player)
	local count = 0
	if player.Character then
		for _, child in ipairs(player.Character:GetChildren()) do
			if child:IsA("Tool") then
				count = count + 1
			end
		end
	end
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") then
				count = count + 1
			end
		end
	end
	return count
end

--------------------------------------------------------------------------------
-- 유틸리티 및 초기화
--------------------------------------------------------------------------------
local function ensurePlayerData(userId)
	if not shelfData[userId] then
		shelfData[userId] = {}
	end
	for i = 1, MAX_SLOTS do
		if shelfData[userId][i] == nil then
			shelfData[userId][i] = false
		end
	end
	return shelfData[userId]
end

local function setupShelfPrompt()
	task.wait(1)
	local shelfPart = Workspace:WaitForChild("DisplayShelf", 10)
	if not shelfPart then return end

	local prompt = shelfPart:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.ObjectText = "진열장"
		prompt.ActionText = "열기 (E)"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = shelfPart
	end

	prompt.Triggered:Connect(function(player)
		local pData = ensurePlayerData(player.UserId)
		displayEvent:FireClient(player, "OpenUI", pData, MAX_SLOTS)
	end)
end

task.spawn(setupShelfPrompt)

local function getHeldOrBackpackTool(player)
	if player.Character then
		local tool = player.Character:FindFirstChildOfClass("Tool")
		if tool then return tool end
	end
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		local tool = backpack:FindFirstChildOfClass("Tool")
		if tool then return tool end
	end
	return nil
end

local function giveToolToPlayer(player, itemName)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	local tool = Instance.new("Tool")
	tool.Name = itemName
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 1)
	handle.Parent = tool
	tool.Parent = backpack
end

--------------------------------------------------------------------------------
-- 서버 이벤트 처리 (1개 제한 검증 추가)
--------------------------------------------------------------------------------
displayEvent.OnServerEvent:Connect(function(player, action, param1, param2)
	local pData = ensurePlayerData(player.UserId)

	if action == "ClickSlot" then
		local slotIndex = tonumber(param1)
		if not slotIndex or slotIndex < 1 or slotIndex > MAX_SLOTS then return end

		if pData[slotIndex] and pData[slotIndex] ~= false then
			-- [회수 시도] 인벤토리에 이미 아이템이 1개 이상 있는지 체크
			if getInventoryItemCount(player) >= 1 then
				displayEvent:FireClient(player, "ShowNotice", "인벤토리가 가득 차서 아이템을 더 가져올 수 없습니다! (최대 1개)")
				return
			end

			local itemToTake = pData[slotIndex]
			pData[slotIndex] = false
			giveToolToPlayer(player, itemToTake)
		else
			-- [진열 시도] 손/백팩에 있는 아이템 1개를 진열장에 넣음
			local tool = getHeldOrBackpackTool(player)
			if tool then
				pData[slotIndex] = tool.Name
				tool:Destroy()
			end
		end

		update3DShelf(player)
		displayEvent:FireClient(player, "UpdateUI", pData, MAX_SLOTS)

	elseif action == "SwapSlots" then
		local fromSlot = tonumber(param1)
		local toSlot = tonumber(param2)

		if fromSlot and toSlot and fromSlot >= 1 and fromSlot <= MAX_SLOTS and toSlot >= 1 and toSlot <= MAX_SLOTS then
			pData[fromSlot], pData[toSlot] = pData[toSlot], pData[fromSlot]
			update3DShelf(player)
			displayEvent:FireClient(player, "UpdateUI", pData, MAX_SLOTS)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	if shelfParts[userId] then
		for _, part in pairs(shelfParts[userId]) do
			if part then part:Destroy() end
		end
		shelfParts[userId] = nil
	end
	shelfData[userId] = nil
end)