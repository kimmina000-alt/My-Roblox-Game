local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemCatalog"))
local GRID = 9
local plot, selectedBase, activeDrag, gridCells
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder, gui.Enabled = "SlimeKneadTableGui", false, 22, false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size, frame.Position = UDim2.fromOffset(600, 470), UDim2.new(0.5, -300, 0.5, -235)
frame.BackgroundColor3, frame.Parent = Color3.fromRGB(250, 239, 245), gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)
local title = Instance.new("TextLabel")
title.Size, title.Position = UDim2.new(1, -90, 0, 40), UDim2.fromOffset(16, 8)
title.BackgroundTransparency, title.Text = 1, "쪼물 테이블 · 내 슬라임을 골라 눌러 보세요"
title.Font, title.TextSize, title.TextColor3 = Enum.Font.GothamBold, 18, Color3.fromRGB(78, 54, 67)
title.TextXAlignment, title.Parent = Enum.TextXAlignment.Left, frame
local close = Instance.new("TextButton")
close.Size, close.Position, close.Text, close.Parent = UDim2.fromOffset(58, 30), UDim2.new(1, -70, 0, 10), "닫기", frame
close.Activated:Connect(function() activeDrag = nil; gui.Enabled = false end)
local choices = Instance.new("ScrollingFrame")
choices.Size, choices.Position = UDim2.new(1, -28, 0, 46), UDim2.fromOffset(14, 54)
choices.BackgroundTransparency, choices.ScrollBarThickness, choices.ScrollingDirection = 1, 5, Enum.ScrollingDirection.X
choices.CanvasSize, choices.Parent = UDim2.fromOffset(800, 40), frame
local choiceLayout = Instance.new("UIListLayout")
choiceLayout.FillDirection, choiceLayout.Padding, choiceLayout.Parent = Enum.FillDirection.Horizontal, UDim.new(0, 6), choices
local viewport = Instance.new("ViewportFrame")
viewport.Name, viewport.Size, viewport.Position = "SlimeTouchSurface", UDim2.new(1, -32, 1, -118), UDim2.fromOffset(16, 104)
viewport.BackgroundColor3, viewport.BorderSizePixel, viewport.Parent = Color3.fromRGB(240, 222, 232), 0, frame
Instance.new("UICorner", viewport).CornerRadius = UDim.new(0, 14)
local camera = Instance.new("Camera")
camera.CFrame, camera.FieldOfView, camera.Parent = CFrame.lookAt(Vector3.new(0, 9, 8), Vector3.new(0, 0, 0)), 38, viewport
viewport.CurrentCamera = camera

local soundObjects = {}
local function findPlot()
	local plots = Workspace:FindFirstChild("HousingPlots")
	if plots then for _, candidate in ipairs(plots:GetChildren()) do if candidate:GetAttribute("OwnerUserId") == player.UserId then return candidate end end end
end

local function clearSurface()
	for _, object in ipairs(viewport:GetChildren()) do if object:IsA("Model") then object:Destroy() end end
	for _, object in pairs(soundObjects) do object:Destroy() end
	table.clear(soundObjects)
	local oldHint = viewport:FindFirstChild("AudioHint")
	if oldHint then oldHint:Destroy() end
	gridCells, selectedBase = {}, nil
end

local function makeSurface(base)
	clearSurface()
	selectedBase = base
	local definition = catalog.Get(base:GetAttribute("ItemId"))
	local color = definition and definition.DisplayColor or Color3.fromRGB(170, 225, 235)
	local model = Instance.new("Model")
	model.Name, model.Parent = "ClientOnlySquishPreview", viewport
	local step, size = 0.72, 0.76
	for row = 1, GRID do
		for col = 1, GRID do
			local cell = Instance.new("Part")
			cell.Name, cell.Shape = ("Slime_%d_%d"):format(row, col), Enum.PartType.Ball
			cell.Size, cell.Anchored, cell.CanCollide = Vector3.new(size, 0.32, size), true, false
			cell.Material, cell.Color = Enum.Material.SmoothPlastic, color
			local x, z = (col - (GRID + 1) / 2) * step, (row - (GRID + 1) / 2) * step
			cell.Position, cell.Parent = Vector3.new(x, 0, z), model
			gridCells[#gridCells + 1] = { Part = cell, Home = cell.Position, Row = row, Col = col, Offset = Vector3.zero }
		end
	end
	local center = Instance.new("Part")
	center.Name, center.Transparency, center.Size, center.Anchored, center.CanCollide = "CameraFocus", 1, Vector3.one, true, false
	center.Position, center.Parent = Vector3.zero, model
	model.PrimaryPart = center
	local baseSoundKey = definition and definition.StepSoundKey or "DefaultSquish"
	for _, property in ipairs({ "PressSoundId", "StretchSoundId", "ReleaseSoundId" }) do
		local soundId = definition and definition[property]
		if type(soundId) == "string" and soundId ~= "" then
			local sound = Instance.new("Sound")
			sound.Name, sound.SoundId, sound.Volume = property, soundId, 0.55
			sound.Parent = viewport
			soundObjects[property] = sound
		end
	end
	local audioLabel = Instance.new("TextLabel")
	audioLabel.Name, audioLabel.Size, audioLabel.Position = "AudioHint", UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 1, -28)
	audioLabel.BackgroundTransparency, audioLabel.Text = 1, "질감 사운드 키: " .. tostring(baseSoundKey) .. " · 오디오 에셋 연결 대기"
	audioLabel.Font, audioLabel.TextSize, audioLabel.TextColor3 = Enum.Font.Gotham, 12, Color3.fromRGB(93, 69, 81)
	audioLabel.Parent = viewport
end

local function rebuildChoices()
	plot = findPlot()
	for _, child in ipairs(choices:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
	local folder = plot and plot:FindFirstChild("PlacedBases")
	local bases = {}
	if folder then for _, object in ipairs(folder:GetChildren()) do if object:IsA("BasePart") and object:GetAttribute("PlacementKind") == "Base" then table.insert(bases, object) end end end
	table.sort(bases, function(a, b) return a.Name < b.Name end)
	for index, base in ipairs(bases) do
		local item = catalog.Get(base:GetAttribute("ItemId"))
		local button = Instance.new("TextButton")
		button.Size, button.LayoutOrder = UDim2.fromOffset(150, 38), index
		button.Text = item and item.DisplayName or base.Name
		button.BackgroundColor3 = item and item.DisplayColor or Color3.fromRGB(185, 225, 235)
		button.TextColor3, button.Font, button.TextSize = Color3.fromRGB(55, 55, 65), Enum.Font.GothamBold, 14
		button.Parent = choices
		button.Activated:Connect(function() makeSurface(base) end)
	end
	if #bases == 0 then clearSurface(); title.Text = "패드에 베이스 슬라임을 먼저 놓아 주세요" end
	if #bases > 0 then title.Text = "쪼물 테이블 · 선택한 슬라임은 저장·수익에 영향을 주지 않습니다" end
end

local function pointerToSlime(position)
	local bounds = viewport.AbsolutePosition
	local size = viewport.AbsoluteSize
	local x = math.clamp((position.X - bounds.X) / size.X, 0, 1)
	local z = math.clamp((position.Y - bounds.Y) / size.Y, 0, 1)
	return Vector2.new((x - 0.5) * GRID, (z - 0.5) * GRID)
end

local function updateDeformation(point, drag)
	if not gridCells then return end
	for _, cell in ipairs(gridCells) do
		local cellPoint = Vector2.new(cell.Col - (GRID + 1) / 2, cell.Row - (GRID + 1) / 2)
		local distance = (cellPoint - point).Magnitude
		local falloff = math.exp(-(distance * distance) / 2.8)
		cell.Offset = Vector3.new(drag.X * falloff * 0.7, -0.45 * falloff, drag.Y * falloff * 0.7)
	end
end

local function playSound(key)
	local sound = soundObjects[key]
	if sound and not sound.IsPlaying then sound:Play() end
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.ActionText == "쪼물 테이블 열기" and prompt:IsDescendantOf(Workspace) then
		plot = findPlot()
		local tablePart = plot and plot:FindFirstChild("SlimeKneadTable")
		if tablePart and prompt:IsDescendantOf(tablePart) then rebuildChoices(); gui.Enabled = true end
	end
end)

UserInputService.InputBegan:Connect(function(input)
	if not gui.Enabled or (input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch) then return end
	local point = Vector2.new(input.Position.X, input.Position.Y)
	local origin, size = viewport.AbsolutePosition, viewport.AbsoluteSize
	if point.X >= origin.X and point.X <= origin.X + size.X and point.Y >= origin.Y and point.Y <= origin.Y + size.Y then
		activeDrag = { Type = input.UserInputType, Last = pointerToSlime(point), Current = pointerToSlime(point) }
		updateDeformation(activeDrag.Current, Vector2.zero)
		playSound("PressSoundId")
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not activeDrag then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local current = pointerToSlime(Vector2.new(input.Position.X, input.Position.Y))
	local delta = current - activeDrag.Last
	activeDrag.Last, activeDrag.Current = current, current
	updateDeformation(current, delta)
	if delta.Magnitude > 0.05 then playSound("StretchSoundId") end
end)
UserInputService.InputEnded:Connect(function(input)
	if activeDrag and input.UserInputType == activeDrag.Type then
		activeDrag = nil
		local stretch = soundObjects.StretchSoundId
		if stretch then stretch:Stop() end
		playSound("ReleaseSoundId")
	end
end)
RunService.RenderStepped:Connect(function(dt)
	for _, cell in ipairs(gridCells or {}) do
		if not activeDrag then cell.Offset = cell.Offset:Lerp(Vector3.zero, math.clamp(dt * 7, 0, 1)) end
		cell.Part.Position = cell.Home + cell.Offset
	end
	if gui.Enabled then
		local tablePart = plot and plot:FindFirstChild("SlimeKneadTable")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or not tablePart or (root.Position - tablePart.Position).Magnitude > 12 then gui.Enabled = false end
	end
end)
