-- [[ 위치: StarterGui > RebirthGui > RebirthClientController ]]
-- [[ 역할: 환생 안내, 조건 체크 및 환생 진행 클라이언트 UI ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RebirthConfig = require(ReplicatedStorage:WaitForChild("RebirthConfig"))
local RebirthEvents = ReplicatedStorage:WaitForChild("RebirthEvents")
local requestRebirthRF = RebirthEvents:WaitForChild("RequestRebirth")

--------------------------------------------------------------------------------
-- UI 생성
--------------------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RebirthGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- 환생 창 열기 버튼 (메인 HUD용)
local openBtn = Instance.new("TextButton")
openBtn.Name = "OpenRebirthBtn"
openBtn.Size = UDim2.new(0, 140, 0, 48)
openBtn.Position = UDim2.new(0, 15, 0.5, 65)
openBtn.BackgroundColor3 = Color3.fromRGB(245, 160, 0)
openBtn.Text = "?? 환생 (Rebirth)"
openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
openBtn.Font = Enum.Font.FredokaOne
openBtn.TextSize = 15
openBtn.Parent = screenGui

local openCorner = Instance.new("UICorner")
openCorner.CornerRadius = UDim.new(0, 10)
openCorner.Parent = openBtn

-- 환생 정보 모달 프레임
local rebirthFrame = Instance.new("Frame")
rebirthFrame.Name = "RebirthModal"
rebirthFrame.Size = UDim2.new(0, 400, 0, 360)
rebirthFrame.Position = UDim2.new(0.5, -200, 0.5, -180)
rebirthFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
rebirthFrame.Visible = false
rebirthFrame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 16)
frameCorner.Parent = rebirthFrame

-- 타이틀
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 0, 45)
title.Position = UDim2.new(0, 15, 0, 0)
title.BackgroundTransparency = 1
title.Text = "? 환생 (Rebirth) ?"
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.TextSize = 20
title.Font = Enum.Font.FredokaOne
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = rebirthFrame

-- [NEW] 닫기 버튼 (X)
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -40, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.FredokaOne
closeBtn.TextSize = 16
closeBtn.Parent = rebirthFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeBtn

-- 조건 및 보상 설명 텍스트
local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -30, 0, 220)
infoLabel.Position = UDim2.new(0, 15, 0, 50)
infoLabel.BackgroundTransparency = 1
infoLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
infoLabel.TextSize = 14
infoLabel.Font = Enum.Font.SourceSans
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.RichText = true
infoLabel.Parent = rebirthFrame

-- 환생 실행 버튼
local doRebirthBtn = Instance.new("TextButton")
doRebirthBtn.Size = UDim2.new(1, -40, 0, 45)
doRebirthBtn.Position = UDim2.new(0, 20, 1, -55)
doRebirthBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
doRebirthBtn.Text = "환생 진행하기"
doRebirthBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
doRebirthBtn.Font = Enum.Font.FredokaOne
doRebirthBtn.TextSize = 18
doRebirthBtn.Parent = rebirthFrame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 10)
btnCorner.Parent = doRebirthBtn

--------------------------------------------------------------------------------
-- UI 업데이트 및 이벤트 로직
--------------------------------------------------------------------------------
local function updateRebirthUI()
	local leaderstats = player:FindFirstChild("leaderstats")
	local rebirthCount = leaderstats and leaderstats:FindFirstChild("Rebirths") and leaderstats.Rebirths.Value or 0
	local config = RebirthConfig.GetStageConfig(rebirthCount)
	if not config then
		infoLabel.Text = "모든 환생 단계를 완료했습니다."
		doRebirthBtn.Text = "환생 완료"
		doRebirthBtn.Active = false
		doRebirthBtn.AutoButtonColor = false
		return
	end
	doRebirthBtn.Text = "환생하기"
	doRebirthBtn.Active = true
	doRebirthBtn.AutoButtonColor = true

	local text = string.format([[
<b>[환생 필요 조건]</b>
? 필요 골드: <font color='#FFD700'>%d Gold</font>
? 필요 토핑: <font color='#00E5FF'>[%s]</font>

<b>[환생 보상 3가지]</b>
1. ?? 노동자 수익 <b>+%.0f%%</b> 상승
2. ?? 고용 가능한 노동자 <b>+%d명</b> 증가
3. ? 전용 아바타 아우라 해금 (On/Off 가능)

<font color='#FFA0A0'>※ 소비용 골드 및 일반 재료는 초기화되며, 가챠 바구니/해금 구역/도감은 영구 보존됩니다.</font>
]], config.RequiredGold, config.RequiredTopping, (config.WorkerIncomeMultiplier - 1) * 100, config.MaxWorkerBonus)

	infoLabel.Text = text
end

-- 창 열기
openBtn.MouseButton1Click:Connect(function()
	rebirthFrame.Visible = not rebirthFrame.Visible
	if rebirthFrame.Visible then
		updateRebirthUI()
	end
end)

-- [NEW] 창 닫기
closeBtn.MouseButton1Click:Connect(function()
	rebirthFrame.Visible = false
end)

-- 환생 진행
doRebirthBtn.MouseButton1Click:Connect(function()
	local success, message = requestRebirthRF:InvokeServer()
	if success then
		print("환생 성공!")
		rebirthFrame.Visible = false
	else
		warn("환생 실패: " .. tostring(message))
	end
end)