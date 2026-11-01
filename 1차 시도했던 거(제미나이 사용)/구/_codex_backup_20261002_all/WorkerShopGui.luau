-- [[ 위치: StarterGui > WorkerShopGui ]]
-- [[ 역할: Worker 고용 상점 UI 및 환생 버튼 구현 ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local workerEvent = ReplicatedStorage:WaitForChild("WorkerShopEvent")

--------------------------------------------------------------------------------
-- UI 기본 구조 생성
--------------------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WorkerShopScreenGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- 상점 열기 버튼 (좌측 화면에 배치)
local openBtn = Instance.new("TextButton")
openBtn.Name = "OpenShopBtn"
openBtn.Size = UDim2.new(0, 130, 0, 45)
openBtn.Position = UDim2.new(0, 15, 0.5, -100)
openBtn.BackgroundColor3 = Color3.fromRGB(45, 180, 90)
openBtn.Text = "?? Worker 상점"
openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
openBtn.Font = Enum.Font.FredokaOne
openBtn.TextSize = 16
openBtn.Parent = screenGui

local openCorner = Instance.new("UICorner")
openCorner.CornerRadius = UDim.new(0, 12)
openCorner.Parent = openBtn

-- 메인 상점 창
local shopFrame = Instance.new("Frame")
shopFrame.Name = "ShopWindow"
shopFrame.Size = UDim2.new(0, 360, 0, 260)
shopFrame.Position = UDim2.new(0.5, -180, 0.5, -130)
shopFrame.BackgroundColor3 = Color3.fromRGB(35, 38, 50)
shopFrame.Visible = false
shopFrame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 16)
frameCorner.Parent = shopFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -40, 0, 40)
titleLabel.Position = UDim2.new(0, 15, 0, 5)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "?? Worker 고용 센터"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 20
titleLabel.Font = Enum.Font.FredokaOne
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = shopFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -38, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.FredokaOne
closeBtn.Parent = shopFrame

-- Worker 고용 버튼
local buyWorkerBtn = Instance.new("TextButton")
buyWorkerBtn.Size = UDim2.new(1, -40, 0, 65)
buyWorkerBtn.Position = UDim2.new(0, 20, 0, 60)
buyWorkerBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 210)
buyWorkerBtn.Text = "?? Worker 고용하기\n<font size='12' color='rgb(200,220,255)'>첫 고용: 50 Gold</font>"
buyWorkerBtn.RichText = true
buyWorkerBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
buyWorkerBtn.Font = Enum.Font.FredokaOne
buyWorkerBtn.TextSize = 16
buyWorkerBtn.Parent = shopFrame

local buyCorner = Instance.new("UICorner")
buyCorner.CornerRadius = UDim.new(0, 10)
buyCorner.Parent = buyWorkerBtn

-- 환생 (Rebirth) 버튼
local rebirthBtn = Instance.new("TextButton")
rebirthBtn.Size = UDim2.new(1, -40, 0, 65)
rebirthBtn.Position = UDim2.new(0, 20, 0, 140)
rebirthBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 200)
rebirthBtn.Text = "?? 환생하기 (Rebirth)\n<font size='12' color='rgb(240,200,255)'>고용 한도 +1 명 증가</font>"
rebirthBtn.RichText = true
rebirthBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
rebirthBtn.Font = Enum.Font.FredokaOne
rebirthBtn.TextSize = 16
rebirthBtn.Parent = shopFrame

local rebirthCorner = Instance.new("UICorner")
rebirthCorner.CornerRadius = UDim.new(0, 10)
rebirthCorner.Parent = rebirthBtn

-- 하단 알림 텍스트
local noticeText = Instance.new("TextLabel")
noticeText.Size = UDim2.new(1, -40, 0, 30)
noticeText.Position = UDim2.new(0, 20, 1, -35)
noticeText.BackgroundTransparency = 1
noticeText.Text = ""
noticeText.TextColor3 = Color3.fromRGB(255, 220, 100)
noticeText.Font = Enum.Font.FredokaOne
noticeText.TextSize = 13
noticeText.Parent = shopFrame

--------------------------------------------------------------------------------
-- 버튼 이벤트 연결
--------------------------------------------------------------------------------
openBtn.MouseButton1Click:Connect(function()
	shopFrame.Visible = not shopFrame.Visible
end)

closeBtn.MouseButton1Click:Connect(function()
	shopFrame.Visible = false
end)

buyWorkerBtn.MouseButton1Click:Connect(function()
	workerEvent:FireServer("BuyWorker")
end)

rebirthBtn.MouseButton1Click:Connect(function()
	workerEvent:FireServer("Rebirth")
end)

workerEvent.OnClientEvent:Connect(function(action, msg)
	if action == "Notice" then
		noticeText.Text = msg
		task.delay(3, function()
			if noticeText.Text == msg then
				noticeText.Text = ""
			end
		end)
	end
end)