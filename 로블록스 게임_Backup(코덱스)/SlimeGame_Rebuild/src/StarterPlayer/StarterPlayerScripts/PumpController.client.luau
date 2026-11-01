local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SlimeGameRemotes")
local config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local gui = Instance.new("ScreenGui")
gui.Name = "BasePumpGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 12
gui.Parent = player:WaitForChild("PlayerGui")

local container = Instance.new("Frame")
container.Name = "NearbyPumpBar"
container.Size = UDim2.fromOffset(520, 58)
container.Position = UDim2.new(0.5, -260, 1, -82)
container.BackgroundTransparency = 1
container.Visible = false
container.Parent = gui

local actionButton = Instance.new("Frame")
actionButton.Name = "PumpAmountBar"
actionButton.Size = UDim2.new(1, -62, 1, 0)
actionButton.Position = UDim2.fromOffset(0, 0)
actionButton.BackgroundColor3 = Color3.fromRGB(43, 66, 80)
actionButton.BackgroundTransparency = 0.05
actionButton.ZIndex = 2
actionButton.ClipsDescendants = true
actionButton.Parent = container
Instance.new("UICorner", actionButton).CornerRadius = UDim.new(0, 14)

local fill = Instance.new("Frame")
fill.Name = "AmountFill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.fromRGB(105, 205, 225)
fill.BackgroundTransparency = 0.15
fill.BorderSizePixel = 0
fill.ZIndex = 2
fill.Parent = actionButton
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 14)
fillCorner.Parent = fill

local textOverlay = Instance.new("TextLabel")
textOverlay.Size = UDim2.fromScale(1, 1)
textOverlay.BackgroundTransparency = 1
textOverlay.TextColor3 = Color3.new(1, 1, 1)
textOverlay.TextStrokeTransparency = 0.55
textOverlay.Font = Enum.Font.GothamBold
textOverlay.TextSize = 15
textOverlay.ZIndex = 3
textOverlay.Parent = actionButton

local upgradeButton = Instance.new("TextButton")
upgradeButton.Name = "UpgradeToggle"
upgradeButton.Size = UDim2.fromOffset(54, 58)
upgradeButton.Position = UDim2.new(1, -54, 0, 0)
upgradeButton.BackgroundColor3 = Color3.fromRGB(202, 177, 226)
upgradeButton.Text = "강화"
upgradeButton.TextColor3 = Color3.fromRGB(54, 40, 65)
upgradeButton.Font = Enum.Font.GothamBold
upgradeButton.TextSize = 13
upgradeButton.Parent = container
Instance.new("UICorner", upgradeButton).CornerRadius = UDim.new(0, 12)

local upgrades = Instance.new("Frame")
upgrades.Name = "UpgradeOptions"
upgrades.Size = UDim2.fromOffset(260, 100)
upgrades.Position = UDim2.new(1, -260, 0, -108)
upgrades.BackgroundColor3 = Color3.fromRGB(250, 242, 255)
upgrades.Visible = false
upgrades.Parent = container
Instance.new("UICorner", upgrades).CornerRadius = UDim.new(0, 12)

local function upgradeOption(name, y)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(1, -12, 0, 38)
	button.Position = UDim2.fromOffset(6, y)
	button.BackgroundColor3 = Color3.fromRGB(218, 196, 238)
	button.TextColor3 = Color3.fromRGB(55, 43, 65)
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 13
	button.Parent = upgrades
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
	return button
end

local capacityButton = upgradeOption("CapacityUpgrade", 6)
local autoButton = upgradeOption("AutoRefillUpgrade", 52)
local pumpPart
local pumpState
local lastRefresh = 0
local lastStatePoll = 0
local busy = false
local pendingPumpClicks = 0
local pumpAttributeConnections = {}

local function updateDisplay(state)
	if type(state) ~= "table" then return end
	pumpState = state
	local current = math.max(0, tonumber(state.Current) or 0)
	local capacity = math.max(1, tonumber(state.Capacity) or 10)
	fill.Size = UDim2.fromScale(math.clamp(current / capacity, 0, 1), 1)
	if current + 0.000001 >= capacity then
		textOverlay.Text = ("베이스 펌프  가득 참   ·   클릭/터치하면 베이스 1개 수령")
	else
		local level = tonumber(state.AutoRefillLevel) or 0
		local refillRate = config.Pump.BaseRefillPerSecond + level * config.Pump.AutoRefillPerSecond
		local waitSeconds = math.ceil((capacity - current) / math.max(refillRate, 0.001))
		textOverlay.Text = ("베이스 펌프  %.1f / %d   ·   가득 차면 베이스 1개 · 약 %d초"):format(current, capacity, waitSeconds)
	end
	local nextCapacity
	for _, tier in ipairs(config.Pump.CapacityTiers) do if tier > capacity then nextCapacity = tier; break end end
	capacityButton.Active = nextCapacity ~= nil
	capacityButton.Text = nextCapacity and ("용량 " .. capacity .. " → " .. nextCapacity .. "L 강화 · " .. (config.Pump.CapacityUpgradeCosts[nextCapacity] or 0) .. "G") or "용량 최대"
	local nextLevel = (tonumber(state.AutoRefillLevel) or 0) + 1
	local autoCost = config.Pump.AutoRefillUpgradeCosts[nextLevel]
	autoButton.Active = autoCost ~= nil
	autoButton.Text = autoCost and ("자동 충전 Lv." .. nextLevel .. " · " .. autoCost .. "G") or "자동 충전 최대"
end

local function updateFromPumpAttributes()
	if not pumpPart then return end
	local current = pumpPart:GetAttribute("PumpCurrent")
	local capacity = pumpPart:GetAttribute("PumpCapacity")
	if type(current) ~= "number" or type(capacity) ~= "number" then return end
	local state = table.clone(pumpState or {})
	state.Current = current
	state.Capacity = capacity
	state.AutoRefillLevel = pumpPart:GetAttribute("PumpAutoRefillLevel") or state.AutoRefillLevel or 0
	updateDisplay(state)
end

local function bindPumpAttributes(newPump)
	for _, connection in ipairs(pumpAttributeConnections) do connection:Disconnect() end
	table.clear(pumpAttributeConnections)
	pumpPart = newPump
	if not pumpPart then return end
	for _, attributeName in ipairs({ "PumpCurrent", "PumpCapacity", "PumpAutoRefillLevel" }) do
		table.insert(pumpAttributeConnections, pumpPart:GetAttributeChangedSignal(attributeName):Connect(updateFromPumpAttributes))
	end
	updateFromPumpAttributes()
end

local function refresh()
	local ok, result = remotes.PumpAction:InvokeServer("GetState")
	if ok then updateDisplay(result) else textOverlay.Text = tostring(result or "개인 펌프 가까이 가세요") end
end

local function performAction(action)
	local callOk, ok, message, current = pcall(function()
		return remotes.PumpAction:InvokeServer(action)
	end)
	if not callOk then
		textOverlay.Text = tostring(ok)
		return false
	elseif not ok then
		textOverlay.Text = tostring(message or "요청에 실패했습니다.")
		return false
	elseif action == "Collect" and type(current) == "number" then
		local state = table.clone(pumpState or {})
		state.Current = current
		state.Capacity = pumpPart and pumpPart:GetAttribute("PumpCapacity") or state.Capacity
		updateDisplay(state)
	else
		refresh()
	end
	return true
end

local processPumpClickQueue
processPumpClickQueue = function()
	if busy or pendingPumpClicks <= 0 then return end
	pendingPumpClicks -= 1
	busy = true
	task.spawn(function()
		local succeeded = performAction("Collect")
		if not succeeded then pendingPumpClicks = 0 end
		busy = false
		processPumpClickQueue()
	end)
end

local function invoke(action)
	if busy then return end
	busy = true
	task.spawn(function()
		performAction(action)
		busy = false
		processPumpClickQueue()
	end)
end

local function findPumpClickTarget(screenPosition)
	local camera = Workspace.CurrentCamera
	if not camera or not pumpPart then return nil end
	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	params.IgnoreWater = true
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	if not result then return nil end
	local target = result.Instance
	if target == pumpPart or target:IsDescendantOf(pumpPart) then return target end
	return nil
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	local position
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		position = UserInputService:GetMouseLocation()
	elseif input.UserInputType == Enum.UserInputType.Touch then
		position = Vector2.new(input.Position.X, input.Position.Y)
	else
		return
	end
	local target = findPumpClickTarget(position)
	if not target then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local pumpBase = pumpPart:IsA("BasePart") and pumpPart or pumpPart:FindFirstChildWhichIsA("BasePart", true)
	if not root or not pumpBase or (root.Position - pumpBase.Position).Magnitude > 12 then return end
	pendingPumpClicks += 1
	processPumpClickQueue()
end)

capacityButton.Activated:Connect(function() invoke("UpgradeCapacity") end)
autoButton.Activated:Connect(function() invoke("UpgradeAutoRefill") end)
upgradeButton.Activated:Connect(function() upgrades.Visible = not upgrades.Visible end)

local function findOwnPump()
	local plots = Workspace:FindFirstChild("HousingPlots")
	if not plots then return nil end
	for _, plot in ipairs(plots:GetChildren()) do
		if plot:GetAttribute("OwnerUserId") == player.UserId then return plot:FindFirstChild("BasePump", true) end
	end
	return nil
end

RunService.Heartbeat:Connect(function()
	if os.clock() - lastRefresh < 0.2 then return end
	lastRefresh = os.clock()
	local candidate = findOwnPump()
	if candidate ~= pumpPart then
		bindPumpAttributes(candidate)
		lastStatePoll = 0
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local part = pumpPart and (pumpPart:IsA("BasePart") and pumpPart or pumpPart:FindFirstChildWhichIsA("BasePart", true))
	local nearby = part and root and (root.Position - part.Position).Magnitude <= 12
	container.Visible = nearby == true
	if not nearby then upgrades.Visible = false; return end
	if os.clock() - lastStatePoll >= 0.5 then
		lastStatePoll = os.clock()
		refresh()
	end
end)
