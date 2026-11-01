local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SlimeGameRemotes")
local feedback = remotes:WaitForChild("PadIncomeFeedback")

local function showIncome(adornee, amount, labelName)
	amount = math.max(0, tonumber(amount) or 0)
	if amount <= 0 or not adornee or not adornee.Parent then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = labelName
	billboard.Adornee = adornee
	billboard.Size = UDim2.fromOffset(110, 44)
	billboard.AlwaysOnTop = true
	local rootPart = adornee:IsA("BasePart") and adornee or adornee:FindFirstChild("HumanoidRootPart")
	billboard.StudsOffsetWorldSpace = (rootPart and -rootPart.CFrame.LookVector * 1.6 or Vector3.zero) + Vector3.new(0, 2.5, 0)
	billboard.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = ("+%.2f G"):format(amount)
	label.TextColor3 = Color3.fromRGB(255, 231, 105)
	label.TextStrokeColor3 = Color3.fromRGB(95, 66, 25)
	label.TextStrokeTransparency = 0.15
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 25
	label.Parent = billboard

	TweenService:Create(billboard, TweenInfo.new(1.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = billboard.StudsOffsetWorldSpace + Vector3.new(0, 2, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(1.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1.25, function() if billboard.Parent then billboard:Destroy() end end)
end

feedback.OnClientEvent:Connect(function(amount)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	showIncome(root, amount, "SlimePadGoldPopup")
end)

remotes:WaitForChild("WorkerIncomeFeedback").OnClientEvent:Connect(function(worker, amount)
	local root = worker and worker:FindFirstChild("HumanoidRootPart")
	showIncome(root, amount, "WorkerGoldPopup")
end)
