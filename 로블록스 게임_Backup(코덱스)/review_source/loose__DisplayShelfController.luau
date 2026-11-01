-- [[ 위치: StarterGui > DisplayShelfController ]]
-- [[ 역할: Y축 오프셋 오인식 버그 완전 해결 (UI 클릭 및 드래그앤드롭 정확한 슬롯 매핑) ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local displayEvent = ReplicatedStorage:WaitForChild("DisplayEvent")

local TOPPING_ICONS = {
	["DirtyTopping"] = "??",
	["더러운 토핑"] = "??",
	["구슬 토핑"] = "??",
	["크런치 폼볼"] = "?",
	["바삭한 칩"] = "??",
	["갤럭시 펄"] = "?"
}

--------------------------------------------------------------------------------
-- UI 생성 및 기본 레이아웃
--------------------------------------------------------------------------------
local screenGui = script.Parent:IsA("ScreenGui") and script.Parent or Instance.new("ScreenGui", player.PlayerGui)
screenGui.Name = "DisplayShelfGui"
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame")
mainFrame.Name = "ShelfWindow"
mainFrame.Size = UDim2.new(0, 520, 0, 360)
mainFrame.Position = UDim2.new(0.5, -260, 0.5, -180)
mainFrame.BackgroundColor3 = Color3.fromRGB(35, 38, 50)
mainFrame.Visible = false
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -50, 0, 45)
titleLabel.Position = UDim2.new(0, 15, 0, 5)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "??? 진열장 관리"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 20
titleLabel.Font = Enum.Font.FredokaOne
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = mainFrame

local noticeLabel = Instance.new("TextLabel")
noticeLabel.Size = UDim2.new(1, -30, 0, 25)
noticeLabel.Position = UDim2.new(0, 15, 1, -30)
noticeLabel.BackgroundTransparency = 1
noticeLabel.Text = ""
noticeLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
noticeLabel.TextSize = 14
noticeLabel.Font = Enum.Font.FredokaOne
noticeLabel.Parent = mainFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -42, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.FredokaOne
closeBtn.Parent = mainFrame

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -30, 1, -95)
scrollFrame.Position = UDim2.new(0, 15, 0, 55)
scrollFrame.BackgroundTransparency = 1
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.ScrollBarThickness = 6
scrollFrame.Parent = mainFrame

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 85, 0, 85)
gridLayout.CellPadding = UDim2.new(0, 12, 0, 12)
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = scrollFrame

--------------------------------------------------------------------------------
-- 드래그 반투명 잔상
--------------------------------------------------------------------------------
local dragGhost = Instance.new("TextLabel")
dragGhost.Size = UDim2.new(0, 75, 0, 75)
dragGhost.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
dragGhost.BackgroundTransparency = 0.5
dragGhost.TextSize = 35
dragGhost.Visible = false
dragGhost.ZIndex = 200
dragGhost.Parent = screenGui

local ghostCorner = Instance.new("UICorner")
ghostCorner.CornerRadius = UDim.new(0, 12)
ghostCorner.Parent = dragGhost

--------------------------------------------------------------------------------
-- 변수 관리
--------------------------------------------------------------------------------
local currentData = {}
local slotButtons = {}
local draggingSlot = nil
local isDraggingMoved = false
local dragStartPosition = Vector2.zero
local maxSlotsCount = 10

--------------------------------------------------------------------------------
-- 알림 메시지
--------------------------------------------------------------------------------
local function showNotice(msg)
	noticeLabel.Text = msg
	task.delay(2.5, function()
		if noticeLabel.Text == msg then
			noticeLabel.Text = ""
		end
	end)
end

--------------------------------------------------------------------------------
-- 마우스/터치 좌표 위치의 슬롯 번호 반환 (Inset 포함 정확 좌표 계산)
--------------------------------------------------------------------------------
local function getSlotAtPosition(pos)
	for i = 1, maxSlotsCount do
		local btn = slotButtons[i]
		if btn and btn.Visible then
			local absPos = btn.AbsolutePosition
			local absSize = btn.AbsoluteSize
			-- GUI Inset 보정을 반영한 절대 영역 체크
			if pos.X >= absPos.X and pos.X <= absPos.X + absSize.X and
				pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y then
				return i
			end
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- UI 슬롯 동적 생성 및 갱신
--------------------------------------------------------------------------------
local function rebuildAndRefreshUI(data, maxSlots)
	currentData = data or {}
	maxSlotsCount = maxSlots or 10

	for i = 1, maxSlotsCount do
		if not slotButtons[i] then
			local slotBtn = Instance.new("TextButton")
			slotBtn.Name = "Slot_" .. i
			slotBtn.LayoutOrder = i
			slotBtn.RichText = true
			slotBtn.Font = Enum.Font.FredokaOne
			slotBtn.TextSize = 13
			slotBtn.BackgroundColor3 = Color3.fromRGB(45, 48, 62)
			slotBtn.Parent = scrollFrame

			local btnCorner = Instance.new("UICorner")
			btnCorner.CornerRadius = UDim.new(0, 12)
			btnCorner.Parent = slotBtn

			slotButtons[i] = slotBtn

			-- [핵심] 버튼 내부 고유 마우스 다운 이벤트 (슬롯 오인식 방지)
			slotBtn.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					draggingSlot = i
					isDraggingMoved = false
					dragStartPosition = UserInputService:GetMouseLocation()

					local item = currentData[i]
					if item and item ~= false then
						dragGhost.Text = TOPPING_ICONS[item] or "??"
					end
				end
			end)
		end

		local btn = slotButtons[i]
		btn.Visible = true
		local itemName = currentData[i]

		if itemName and itemName ~= false then
			local icon = TOPPING_ICONS[itemName] or "??"
			btn.Text = "<b>[" .. i .. "]</b>\n" .. icon .. "\n" .. itemName
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			btn.BackgroundColor3 = Color3.fromRGB(65, 80, 110)
		else
			btn.Text = "<b>[" .. i .. "]</b>\n\n<font color='rgb(120,120,120)'>비어있음</font>"
			btn.TextColor3 = Color3.fromRGB(200, 200, 200)
			btn.BackgroundColor3 = Color3.fromRGB(45, 48, 62)
		end
	end

	local rows = math.ceil(maxSlotsCount / 5)
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, rows * 97)
end

--------------------------------------------------------------------------------
-- 드래그 추적 및 드롭/클릭 처리
--------------------------------------------------------------------------------
UserInputService.InputChanged:Connect(function(input)
	if draggingSlot and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local currentPos = UserInputService:GetMouseLocation()
		if (currentPos - dragStartPosition).Magnitude > 12 then
			local item = currentData[draggingSlot]
			if item and item ~= false then
				isDraggingMoved = true
				dragGhost.Visible = true
				-- 상단 픽셀 Inset 보정된 잔상 위치
				dragGhost.Position = UDim2.new(0, currentPos.X - 37, 0, currentPos.Y - 37)
			end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and draggingSlot then
		local mousePos = UserInputService:GetMouseLocation()

		-- Roblox UI 화면 TopInset (상단 바 36px/ GuiInset) 보정을 정확히 적용한 위치 탐색
		local inset = game:GetService("GuiService"):GetGuiInset()
		local correctedPos = Vector2.new(mousePos.X, mousePos.Y - inset.Y)

		if isDraggingMoved then
			-- [드래그 앤 드롭 동작]: 아이템 슬롯 위치 이동/교환
			dragGhost.Visible = false
			local targetSlot = getSlotAtPosition(correctedPos)

			if targetSlot and targetSlot ~= draggingSlot then
				displayEvent:FireServer("SwapSlots", draggingSlot, targetSlot)
			end
		else
			-- [단순 클릭 동작]: 아이템 진열 또는 인벤토리 회수
			displayEvent:FireServer("ClickSlot", draggingSlot)
		end

		draggingSlot = nil
		isDraggingMoved = false
		dragGhost.Visible = false
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
end)

--------------------------------------------------------------------------------
-- 서버 이벤트 수신 및 자동 UI 닫기
--------------------------------------------------------------------------------
displayEvent.OnClientEvent:Connect(function(action, data, maxSlots)
	if action == "OpenUI" then
		rebuildAndRefreshUI(data, maxSlots)
		mainFrame.Visible = true
	elseif action == "UpdateUI" then
		rebuildAndRefreshUI(data, maxSlots)
	elseif action == "ShowNotice" then
		showNotice(data)
	end
end)

task.spawn(function()
	while task.wait(0.5) do
		if mainFrame.Visible then
			local shelfPart = Workspace:FindFirstChild("DisplayShelf")
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")

			if shelfPart and hrp then
				if (hrp.Position - shelfPart.Position).Magnitude > 12 then
					mainFrame.Visible = false
				end
			end
		end
	end
end)