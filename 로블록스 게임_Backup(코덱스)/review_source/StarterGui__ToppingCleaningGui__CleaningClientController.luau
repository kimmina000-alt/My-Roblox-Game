-- [[ 위치: StarterGui > ToppingCleaningGui > CleaningClientController ]]
-- [[ 역할: 단일 아이템 인벤토리 UI, Q(버리기)/E(줍기/진열하기), 알림 및 세척대 통합 ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local cleanToppingEvent = ReplicatedStorage:WaitForChild("CleanToppingEvent")
local toolActionEvent = ReplicatedStorage:WaitForChild("ToolActionEvent")

--------------------------------------------------------------------------------
-- 0. 기본 백팩 UI 비활성화
--------------------------------------------------------------------------------
task.spawn(function()
	local success = false
	while not success do
		success = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		task.wait(0.1)
	end
end)

--------------------------------------------------------------------------------
-- 효과음 및 아이콘 정의
--------------------------------------------------------------------------------
local SPONGE_SOUND_ID = "rbxassetid://90416226721742"
local spongeSound = Instance.new("Sound")
spongeSound.Name = "SpongeWipeSound"
spongeSound.SoundId = SPONGE_SOUND_ID
spongeSound.Volume = 0.7
spongeSound.Parent = script

local screenGui = script.Parent
if screenGui:IsA("ScreenGui") then
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 10
	screenGui.Enabled = true
end

local TOPPING_ICONS = {
	["DirtyTopping"] = "??",
	["구슬 토핑"] = "??",
	["크런치 폼볼"] = "??",
	["바삭한 칩"] = "??",
	["갤럭시 펄"] = "??"
}

--------------------------------------------------------------------------------
-- [알림 UI (Notification)]
--------------------------------------------------------------------------------
local notifyLabel = Instance.new("TextLabel")
notifyLabel.Name = "NoticeLabel"
notifyLabel.Size = UDim2.new(0, 320, 0, 45)
notifyLabel.Position = UDim2.new(0.5, -160, 0.2, 0)
notifyLabel.BackgroundColor3 = Color3.fromRGB(230, 50, 50)
notifyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
notifyLabel.TextSize = 15
notifyLabel.Font = Enum.Font.FredokaOne
notifyLabel.Visible = false
notifyLabel.ZIndex = 100
notifyLabel.Parent = screenGui

local notifyCorner = Instance.new("UICorner")
notifyCorner.CornerRadius = UDim.new(0, 10)
notifyCorner.Parent = notifyLabel

local notifyTween = nil
local function showNotification(msg)
	notifyLabel.Text = msg
	notifyLabel.BackgroundTransparency = 0
	notifyLabel.TextTransparency = 0
	notifyLabel.Visible = true

	if notifyTween then notifyTween:Cancel() end
	notifyTween = TweenService:Create(notifyLabel, TweenInfo.new(1.2), {
		BackgroundTransparency = 1,
		TextTransparency = 1
	})
	task.delay(1, function()
		notifyTween:Play()
		task.wait(1.2)
		if notifyLabel.BackgroundTransparency >= 0.98 then
			notifyLabel.Visible = false
		end
	end)
end

--------------------------------------------------------------------------------
-- Helper: 소지 개수 검사 및 UI 갱신
--------------------------------------------------------------------------------
local function getTotalToolCount()
	local count = 0
	local backpack = player:FindFirstChild("Backpack")
	local char = player.Character

	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			if item:IsA("Tool") then count += 1 end
		end
	end
	if char then
		for _, item in ipairs(char:GetChildren()) do
			if item:IsA("Tool") then count += 1 end
		end
	end
	return count
end

local function getCurrentTool()
	local char = player.Character
	if char then
		local held = char:FindFirstChildOfClass("Tool")
		if held then return held, true end
	end
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		local stored = backpack:FindFirstChildOfClass("Tool")
		if stored then return stored, false end
	end
	return nil, false
end

--------------------------------------------------------------------------------
-- 1. 하단 단일 아이템 인벤토리 UI
--------------------------------------------------------------------------------
local slotFrame = Instance.new("Frame")
slotFrame.Name = "SingleInventorySlot"
slotFrame.Size = UDim2.new(0, 75, 0, 75)
slotFrame.Position = UDim2.new(0.5, -37, 1, -95)
slotFrame.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
slotFrame.BorderSizePixel = 2
slotFrame.BorderColor3 = Color3.fromRGB(100, 110, 140)
slotFrame.Parent = screenGui

local slotCorner = Instance.new("UICorner")
slotCorner.CornerRadius = UDim.new(0, 16)
slotCorner.Parent = slotFrame

local itemIconButton = Instance.new("TextButton")
itemIconButton.Name = "ItemButton"
itemIconButton.Size = UDim2.new(1, 0, 1, 0)
itemIconButton.BackgroundTransparency = 1
itemIconButton.Text = "비어있음"
itemIconButton.TextColor3 = Color3.fromRGB(150, 150, 150)
itemIconButton.TextSize = 14
itemIconButton.Font = Enum.Font.FredokaOne
itemIconButton.Parent = slotFrame

local keyHintLabel = Instance.new("TextLabel")
keyHintLabel.Name = "KeyHint"
keyHintLabel.Size = UDim2.new(1, 0, 0, 18)
keyHintLabel.Position = UDim2.new(0, 0, 1, 2)
keyHintLabel.BackgroundTransparency = 1
keyHintLabel.Text = "[Q] 버리기"
keyHintLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
keyHintLabel.TextSize = 11
keyHintLabel.Font = Enum.Font.SourceSansBold
keyHintLabel.Parent = slotFrame

local function updateInventoryUI()
	local tool, isEquipped = getCurrentTool()
	if tool then
		local icon = TOPPING_ICONS[tool.Name] or "??"
		itemIconButton.Text = icon .. "\n" .. tool.Name
		itemIconButton.TextSize = 16
		itemIconButton.TextColor3 = Color3.fromRGB(255, 255, 255)

		if isEquipped then
			slotFrame.BackgroundColor3 = Color3.fromRGB(50, 120, 70)
			slotFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
		else
			slotFrame.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
			slotFrame.BorderColor3 = Color3.fromRGB(100, 110, 140)
		end
		keyHintLabel.Visible = true
	else
		itemIconButton.Text = "비어있음"
		itemIconButton.TextSize = 13
		itemIconButton.TextColor3 = Color3.fromRGB(130, 130, 130)
		slotFrame.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
		slotFrame.BorderColor3 = Color3.fromRGB(70, 75, 90)
		keyHintLabel.Visible = false
	end
end

--------------------------------------------------------------------------------
-- 2. 클릭으로 손에 들기 / 착용 해제
--------------------------------------------------------------------------------
itemIconButton.MouseButton1Click:Connect(function()
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	local tool, isEquipped = getCurrentTool()
	if not tool then return end

	if isEquipped then
		-- 아이템이 인벤토리(Backpack)에 존재한 상태에서 모션/장착만 해제
		hum:UnequipTools()
	else
		-- 들고 있지 않을 때 클릭하면 다시 손에 들기
		hum:UnequipTools()
		hum:EquipTool(tool)
	end
	updateInventoryUI()
end)
--------------------------------------------------------------------------------
-- 3. [Q 키] 버리기 (서버 통신 반영)
--------------------------------------------------------------------------------
local function dropCurrentTool()
	local tool, isEquipped = getCurrentTool()
	if not tool then return end

	local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildOfClass("BasePart")

	-- 서버에 버리기 요청
	toolActionEvent:FireServer("DropTool", tool)

	if handle then
		task.delay(0.1, function()
			local existingPrompt = handle:FindFirstChildOfClass("ProximityPrompt")
			if existingPrompt then existingPrompt:Destroy() end

			local prompt = Instance.new("ProximityPrompt")
			prompt.ObjectText = tool.Name
			prompt.ActionText = "줍기"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 8
			prompt.RequiresLineOfSight = false
			prompt.Parent = handle
		end)
	end

	task.wait(0.2)
	updateInventoryUI()
end

--------------------------------------------------------------------------------
-- 4. [ProximityPrompt 통합 제어 (ToppingMachine 차단, 진열대, 회수)]
--------------------------------------------------------------------------------
ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
	if triggeringPlayer ~= player then return end

	local actionText = prompt.ActionText
	local promptParent = prompt.Parent

	-- A. [ToppingMachine] 추출 시도 시 소지 여부 체크
	if promptParent.Name == "ToppingMachine" then
		if getTotalToolCount() >= 1 then
			showNotification("?? 이미 아이템을 들고 있어 더 뽑을 수 없습니다!")
		end
		return
	end


	-- C. [선반 회수 / 드롭 아이템 줍기]
	if string.find(actionText, "회수") or actionText == "줍기" then
		if getTotalToolCount() >= 1 then
			showNotification("?? 이미 아이템을 들고 있어 더 주울 수 없습니다!")
			return
		end

		local itemName = prompt.ObjectText
		local backpack = player:FindFirstChild("Backpack")

		if backpack then
			local newTool = Instance.new("Tool")
			newTool.Name = itemName
			newTool.RequiresHandle = true

			local handle = promptParent:Clone()
			handle.Name = "Handle"
			handle.Anchored = false
			handle.CanCollide = false

			local existingPrompt = handle:FindFirstChildOfClass("ProximityPrompt")
			if existingPrompt then existingPrompt:Destroy() end

			handle.Parent = newTool
			newTool.Parent = backpack

			promptParent:Destroy()

			task.wait(0.1)

			-- 획득 후 즉시 손에 착용
			local char = player.Character
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then hum:EquipTool(newTool) end
			end

			updateInventoryUI()
			showNotification("?? 아이템을 회수했습니다!")
		end
	end
end)

--------------------------------------------------------------------------------
-- 5. [Q 키 입력 감지 (버리기 활성화)]
--------------------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Q then
		dropCurrentTool()
	end
end)

--------------------------------------------------------------------------------
-- 6. 인벤토리 및 Backpack 데이터 동기화 감지 (아이템 획득 시 자동 착용)
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- 6. 인벤토리 및 Backpack 데이터 동기화 감지 (수정 완료)
--------------------------------------------------------------------------------
local function bindContainer(container)
	if not container then return end
	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			task.wait(0.05)

			-- ?? 캐릭터 <-> 백팩 이동 중이 아니라 '실제 새로 생성/획득'되었는지 확인하는 플래그
			local isNewlyAcquired = not child:GetAttribute("WasAcquired")

			if isNewlyAcquired then
				child:SetAttribute("WasAcquired", true)

				-- 새로 획득한 경우에만 자동 착용 및 안내창 출력
				local char = player.Character
				if char then
					local hum = char:FindFirstChildOfClass("Humanoid")
					if hum and child.Parent == player:FindFirstChild("Backpack") then
						hum:UnequipTools()
						hum:EquipTool(child)
					end
				end

				if child.Name == "DirtyTopping" then
					showNotification("?? 더러운 토핑을 획득했습니다!")
				end
			end

			updateInventoryUI()
		end
	end)

	container.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			task.wait(0.05)
			updateInventoryUI()
		end
	end)
end

local function listenInventoryChanges()
	local backpack = player:WaitForChild("Backpack", 5)
	if backpack then
		bindContainer(backpack)
	end

	if player.Character then
		bindContainer(player.Character)
	end
end

player.CharacterAdded:Connect(function(char)
	task.wait(0.3)
	listenInventoryChanges()
	bindContainer(char)
	updateInventoryUI()
end)

task.spawn(function()
	listenInventoryChanges()
	updateInventoryUI()
end)

--------------------------------------------------------------------------------
-- 7. [세척대 UI 로직]
--------------------------------------------------------------------------------
local mainFrame = Instance.new("Frame")
mainFrame.Name = "CleanWindow"
mainFrame.Size = UDim2.new(0, 320, 0, 340)
mainFrame.Position = UDim2.new(0.5, -160, 0.5, -170)
mainFrame.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
mainFrame.Visible = false
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = mainFrame

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 32, 0, 32)
closeButton.Position = UDim2.new(1, -40, 0, 10)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Font = Enum.Font.FredokaOne
closeButton.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -50, 0, 40)
titleLabel.Position = UDim2.new(0, 15, 0, 5)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "?? 토핑 세척대"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 18
titleLabel.Font = Enum.Font.FredokaOne
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = mainFrame

local toppingFrame = Instance.new("Frame")
toppingFrame.Size = UDim2.new(0, 180, 0, 180)
toppingFrame.Position = UDim2.new(0.5, -90, 0.18, 0)
toppingFrame.BackgroundColor3 = Color3.fromRGB(70, 75, 95)
toppingFrame.Parent = mainFrame

local toppingCorner = Instance.new("UICorner")
toppingCorner.CornerRadius = UDim.new(0, 20)
toppingCorner.Parent = toppingFrame

local itemLabel = Instance.new("TextLabel")
itemLabel.Size = UDim2.new(1, 0, 1, 0)
itemLabel.BackgroundTransparency = 1
itemLabel.Text = "??"
itemLabel.TextSize = 65
itemLabel.Parent = toppingFrame

local foamLayer = Instance.new("TextButton")
foamLayer.Size = UDim2.new(1, 0, 1, 0)
foamLayer.BackgroundColor3 = Color3.fromRGB(110, 85, 60)
foamLayer.BackgroundTransparency = 0.0
foamLayer.Text = "클릭하여 닦기!\n(0 / 5)"
foamLayer.TextColor3 = Color3.fromRGB(255, 255, 255)
foamLayer.TextSize = 16
foamLayer.Font = Enum.Font.GothamBold
foamLayer.Parent = toppingFrame

local foamCorner = Instance.new("UICorner")
foamCorner.CornerRadius = UDim.new(0, 20)
foamCorner.Parent = foamLayer

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 35)
statusLabel.Position = UDim2.new(0, 10, 0.82, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "토핑을 연신 클릭해 깨끗하게 닦으세요!"
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.TextSize = 13
statusLabel.Font = Enum.Font.SourceSansBold
statusLabel.Parent = mainFrame

local REQUIRED_CLICKS = 5
local currentClicks = 0
local isCleaning = false
local lastClickTime = 0
local CLICK_COOLTIME = 0.05

local function isHoldingDirtyTopping()
	local tool, _ = getCurrentTool()
	return (tool ~= nil and tool.Name == "DirtyTopping")
end

local openCleanWindow = function()
	currentClicks = 0
	isCleaning = false
	itemLabel.Text = "??"
	foamLayer.BackgroundColor3 = Color3.fromRGB(110, 85, 60)
	foamLayer.BackgroundTransparency = 0.0
	foamLayer.Text = "클릭하여 닦기!\n(0 / " .. REQUIRED_CLICKS .. ")"
	foamLayer.Visible = true
	statusLabel.Text = "손에 든 더러운 토핑을 깨끗이 닦으세요!"
	mainFrame.Visible = true
end

closeButton.MouseButton1Click:Connect(function() mainFrame.Visible = false end)

foamLayer.MouseButton1Click:Connect(function()
	if isCleaning and currentClicks >= REQUIRED_CLICKS then return end
	if not isHoldingDirtyTopping() then
		statusLabel.Text = "?? 더러운 토핑을 손에 들고 있어야 합니다!"
		return
	end

	local currentTime = os.clock()
	if currentTime - lastClickTime < CLICK_COOLTIME then return end
	lastClickTime = currentTime

	if currentClicks == 0 then
		local startRes = cleanToppingEvent:InvokeServer("Start")
		if not startRes.Success then
			statusLabel.Text = "?? " .. startRes.Reason
			return
		end
		isCleaning = true
	end

	currentClicks += 1
	pcall(function() spongeSound.TimePosition = 0; spongeSound:Play() end)

	local progress = currentClicks / REQUIRED_CLICKS
	TweenService:Create(foamLayer, TweenInfo.new(0.1), {
		BackgroundTransparency = progress * 0.95
	}):Play()

	foamLayer.Text = "닦는 중... (" .. currentClicks .. " / " .. REQUIRED_CLICKS .. ")"

	if currentClicks >= REQUIRED_CLICKS then
		foamLayer.Text = "세척 완료!"

		local response = cleanToppingEvent:InvokeServer("Complete")
		if response.Success then
			local result = response.Topping
			foamLayer.Visible = false
			itemLabel.Text = (TOPPING_ICONS[result.Name] or "??") .. "\n" .. result.Name
			statusLabel.Text = "?? [" .. result.Rarity .. "] " .. result.Name .. " 획득!"

			task.delay(0.1, updateInventoryUI)
			task.delay(0.3, updateInventoryUI)

			if result.SoundId then
				local rewardSound = Instance.new("Sound")
				rewardSound.SoundId = result.SoundId
				rewardSound.Volume = 1.0
				rewardSound.Parent = script
				pcall(function() rewardSound:Play() end)
				task.delay(2, function() rewardSound:Destroy() end)
			end

			-- ?? [수정] 세척 결과 획득 연출 후 0.8초 뒤 창 자동으로 닫기
			task.delay(0.5, function()
				mainFrame.Visible = false
			end)
		else
			statusLabel.Text = "?? " .. response.Reason
		end
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
	if triggeringPlayer == player and prompt.Parent and prompt.Parent.Name == "CleaningTable" then
		if isHoldingDirtyTopping() then
			openCleanWindow()
		else
			statusLabel.Text = "?? 손에 '더러운 토핑'을 들고 접근해 주세요!"
		end
	end
end)