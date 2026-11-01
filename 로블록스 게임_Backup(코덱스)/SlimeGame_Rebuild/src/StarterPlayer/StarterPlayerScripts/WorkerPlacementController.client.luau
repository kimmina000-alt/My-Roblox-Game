local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SlimeGameRemotes")
local selected = false
local watched = setmetatable({}, { __mode = "k" })
local watchedZones = setmetatable({}, { __mode = "k" })

local gui = Instance.new("ScreenGui")
gui.Name = "WorkerPlacementHint"
gui.ResetOnSpawn = false
gui.DisplayOrder = 35
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")
local hint = Instance.new("TextLabel")
hint.Size = UDim2.fromOffset(420, 48)
hint.Position = UDim2.new(0.5, -210, 0, 18)
hint.BackgroundColor3 = Color3.fromRGB(48, 36, 57)
hint.BackgroundTransparency = 0.12
hint.TextColor3 = Color3.new(1, 1, 1)
hint.Text = "배치할 베이스 슬라임을 클릭하거나 E를 누르세요 · 가방에서 노동자를 다시 누르면 취소"
hint.TextScaled = true
hint.Font = Enum.Font.GothamBold
hint.Parent = gui
Instance.new("UICorner", hint).CornerRadius = UDim.new(0, 10)

local function findZone(prompt)
	local node = prompt.Parent
	while node and node ~= Workspace do
		if node:IsA("Model") and node.Name:match("^Zone_%d+$") then return node end
		node = node.Parent
	end
	return nil
end

local function refreshPrompt(prompt)
	if not prompt:IsA("ProximityPrompt") then return end
	if not watched[prompt] then
		watched[prompt] = true
		prompt:GetAttributeChangedSignal("WorkerPlacePrompt"):Connect(function() refreshPrompt(prompt) end)
		prompt:GetAttributeChangedSignal("OwnerUserId"):Connect(function() refreshPrompt(prompt) end)
		prompt:GetAttributeChangedSignal("PadOccupied"):Connect(function() refreshPrompt(prompt) end)
		prompt:GetAttributeChangedSignal("HasPlacedBase"):Connect(function() refreshPrompt(prompt) end)
		if prompt.Parent and prompt.Parent:IsA("BasePart") then
			prompt.Parent:GetAttributeChangedSignal("HasPlacedBase"):Connect(function() refreshPrompt(prompt) end)
		end
	end
	if prompt:GetAttribute("WorkerPlacePrompt") ~= true then return end
	local isOwned = prompt:GetAttribute("OwnerUserId") == player.UserId
	local zone = findZone(prompt)
	if zone and not watchedZones[zone] then
		watchedZones[zone] = true
		zone:GetAttributeChangedSignal("Unlocked"):Connect(function()
			for _, object in ipairs(Workspace:GetDescendants()) do refreshPrompt(object) end
		end)
	end
	local hasBase = prompt.Parent and prompt.Parent:GetAttribute("HasPlacedBase") == true
	local isOpen = prompt:GetAttribute("PadOccupied") ~= true and hasBase
		and zone and zone:GetAttribute("Unlocked") == true
	prompt.ActionText = "노동자 배치"
	prompt.ObjectText = isOpen and "빈 패드" or "사용 중인 패드"
	prompt.Enabled = isOwned and isOpen and selected
end

for _, object in ipairs(Workspace:GetDescendants()) do refreshPrompt(object) end
Workspace.DescendantAdded:Connect(function(object)
	if object:IsA("ProximityPrompt") then task.defer(refreshPrompt, object) end
end)

remotes:WaitForChild("WorkerSelectionChanged").OnClientEvent:Connect(function(isSelected)
	selected = isSelected == true
	gui.Enabled = selected
	for _, object in ipairs(Workspace:GetDescendants()) do refreshPrompt(object) end
end)

local mouse = player:GetMouse()
mouse.Button1Down:Connect(function()
	if not selected then return end
	local target = mouse.Target
	if not target then return end
	local pad
	if target:GetAttribute("IsBasePad") == true then
		pad = target
	elseif target:GetAttribute("PlacementKind") == "Base" then
		local path = target:GetAttribute("PadPath")
		local plot = target:FindFirstAncestorWhichIsA("Model")
		while plot and plot:GetAttribute("OwnerUserId") ~= player.UserId do
			plot = plot.Parent and plot.Parent:FindFirstAncestorWhichIsA("Model")
		end
		pad = plot
		for segment in string.gmatch(path or "", "[^/]+") do pad = pad and pad:FindFirstChild(segment) end
	end
	if not pad then return end
	local ok, message = remotes.WorkerAction:InvokeServer("PlaceAtPad", pad)
	if not ok then
		hint.Text = tostring(message or "빈 베이스 패드 위를 클릭하세요.")
		task.delay(2, function()
			if selected and gui.Parent then hint.Text = "배치할 베이스 슬라임을 클릭하거나 E를 누르세요 · 가방에서 노동자를 다시 누르면 취소" end
		end)
	end
end)
