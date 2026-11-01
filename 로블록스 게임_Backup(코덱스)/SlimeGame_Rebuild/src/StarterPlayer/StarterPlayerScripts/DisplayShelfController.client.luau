local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SlimeGameRemotes")
local catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemCatalog"))

local function isShelfPrompt(prompt)
	return prompt and (prompt.ActionText == "진열장 열기" or prompt.ObjectText == "내 진열장")
end

ProximityPromptService.PromptShown:Connect(function(prompt)
	if isShelfPrompt(prompt) then
		print(("[DisplayShelfClient] E prompt shown: %s | action=%s | object=%s"):format(prompt:GetFullName(), prompt.ActionText, prompt.ObjectText))
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
	if isShelfPrompt(prompt) then
		print(("[DisplayShelfClient] E key input detected: %s | localPlayer=%s"):format(prompt:GetFullName(), player.Name))
		local invokeOk, requestOk, message = pcall(function()
			return remotes.DisplayShelfAction:InvokeServer("Open")
		end)
		if not invokeOk then
			warn("[DisplayShelfClient] Open request failed: " .. tostring(requestOk))
		elseif not requestOk then
			warn("[DisplayShelfClient] Server rejected open request: " .. tostring(message))
		else
			print("[DisplayShelfClient] Server accepted E open request")
		end
	end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "DisplayShelfGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(520, 260)
frame.Position = UDim2.new(0.5, -260, 0.5, -130)
frame.BackgroundColor3 = Color3.fromRGB(250, 242, 255)
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 0, 36)
title.Position = UDim2.fromOffset(14, 7)
title.BackgroundTransparency = 1
title.Text = "진열장 · 빈 칸 누르기: 진열 / 아이템 누르기: 회수 / 드래그: 칸 교환"
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(65, 50, 75)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(38, 30)
close.Position = UDim2.new(1, -46, 0, 8)
close.Text = "닫기"
close.TextSize = 12
close.Parent = frame
close.Activated:Connect(function() gui.Enabled = false end)

local heldLabel = Instance.new("TextLabel")
heldLabel.Size = UDim2.new(1, -24, 0, 28)
heldLabel.Position = UDim2.fromOffset(12, 42)
heldLabel.BackgroundTransparency = 1
heldLabel.Text = "손에 든 아이템: 없음 · 가방에서 아이템을 선택하세요"
heldLabel.TextColor3 = Color3.fromRGB(75, 60, 85)
heldLabel.Font = Enum.Font.GothamMedium
heldLabel.TextSize = 13
heldLabel.TextXAlignment = Enum.TextXAlignment.Left
heldLabel.Parent = frame

local gridScroll = Instance.new("ScrollingFrame")
gridScroll.Name = "ShelfGridScroll"
gridScroll.Size = UDim2.new(1, -28, 1, -88)
gridScroll.Position = UDim2.fromOffset(14, 76)
gridScroll.BackgroundColor3 = Color3.fromRGB(239, 229, 245)
gridScroll.BorderSizePixel = 0
gridScroll.ScrollBarThickness = 8
gridScroll.ScrollBarImageColor3 = Color3.fromRGB(155, 120, 175)
gridScroll.ScrollingDirection = Enum.ScrollingDirection.XY
gridScroll.CanvasSize = UDim2.fromOffset(520, 205)
gridScroll.Parent = frame
Instance.new("UICorner", gridScroll).CornerRadius = UDim.new(0, 10)

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(96, 88)
grid.CellPadding = UDim2.fromOffset(6, 6)
grid.FillDirection = Enum.FillDirection.Horizontal
grid.FillDirectionMaxCells = 5
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = gridScroll

local dragGhost = Instance.new("TextLabel")
dragGhost.Name = "ShelfDragGhost"
dragGhost.Size = UDim2.fromOffset(96, 88)
dragGhost.AnchorPoint = Vector2.new(0.5, 0.5)
dragGhost.BackgroundColor3 = Color3.fromRGB(214, 195, 230)
dragGhost.BackgroundTransparency = 0.3
dragGhost.TextColor3 = Color3.fromRGB(50, 40, 60)
dragGhost.TextTransparency = 0.2
dragGhost.TextWrapped = true
dragGhost.Font = Enum.Font.GothamBold
dragGhost.TextSize = 13
dragGhost.ZIndex = 100
dragGhost.Visible = false
dragGhost.Parent = gui
Instance.new("UICorner", dragGhost).CornerRadius = UDim.new(0, 10)

local latestSlots = {}
local heldItemId
local busy = false

local function refresh(slots)
	if type(slots) == "table" then latestSlots = slots end
	local inventoryOk, inventory = pcall(function() return remotes.RequestInventory:InvokeServer() end)
	if inventoryOk and type(inventory) == "table" then
		heldItemId = inventory.HeldItemId
		local heldDefinition = heldItemId and catalog.Get(heldItemId)
		heldLabel.Text = heldDefinition and ("손에 든 아이템: " .. heldDefinition.DisplayName .. " · 빈 칸을 누르면 해당 칸에 진열")
			or "손에 든 아이템: 없음 · 가방에서 아이템을 선택하세요"
	end
	for _, child in ipairs(gridScroll:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	for slot = 1, 10 do
		local itemId = latestSlots[slot]
		local definition = itemId and catalog.Get(itemId)
		local button = Instance.new("TextButton")
		button.Name = "ShelfSlot_" .. slot
		button.LayoutOrder = slot
		button.BackgroundColor3 = definition and (definition.DisplayColor or Color3.fromRGB(214, 195, 230)) or Color3.fromRGB(255, 255, 255)
		button.TextColor3 = Color3.fromRGB(60, 48, 68)
		button.TextWrapped = true
		button.Font = Enum.Font.GothamBold
		button.TextSize = 13
		button.Text = definition and (slot .. "번\n" .. definition.DisplayName .. "\n눌러서 회수") or (slot .. "번\n빈 칸\n손 아이템 진열")
		button.Parent = gridScroll
		Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)
	end
end

local function getSlotAtPosition(position)
	for _, object in ipairs(player:WaitForChild("PlayerGui"):GetGuiObjectsAtPosition(position.X, position.Y)) do
		local current = object
		while current and current ~= gridScroll do
			if current:IsA("TextButton") and current.Parent == gridScroll then
				return tonumber(current.Name:match("^ShelfSlot_(%d+)$")), current
			end
			current = current.Parent
		end
	end
	return nil
end

local function performSlotAction(action, first, second)
	if busy then return end
	busy = true
	local callOk, ok, message, updated = pcall(function()
		return remotes.DisplayShelfAction:InvokeServer(action, first, second)
	end)
	if callOk and ok then
		latestSlots = updated or latestSlots
		refresh(latestSlots)
	else
		warn("[DisplayShelfClient] Slot action failed: " .. tostring(callOk and message or ok))
		if gui.Enabled then refresh(latestSlots) end
	end
	busy = false
end

local pressState
local function pointerPosition(input)
	return Vector2.new(input.Position.X, input.Position.Y)
end

UserInputService.InputBegan:Connect(function(input)
	if not gui.Enabled or pressState then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local position = pointerPosition(input)
	local slot, slotButton = getSlotAtPosition(position)
	if slot then
		pressState = {
			inputType = input.UserInputType,
			slot = slot,
			button = slotButton,
			originalColor = slotButton.BackgroundColor3,
			originalText = slotButton.Text,
			originalBackgroundTransparency = slotButton.BackgroundTransparency,
			originalTextTransparency = slotButton.TextTransparency,
			start = position,
			dragging = false,
		}
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not pressState then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
	if not latestSlots[pressState.slot] then return end
	if (pointerPosition(input) - pressState.start).Magnitude >= 10 and not pressState.dragging then
		pressState.dragging = true
		pressState.originalScrollingEnabled = gridScroll.ScrollingEnabled
		gridScroll.ScrollingEnabled = false
		pressState.button.BackgroundTransparency = 0.6
		pressState.button.TextTransparency = 0.55
		local definition = catalog.Get(latestSlots[pressState.slot])
		dragGhost.Text = definition and definition.DisplayName or "아이템"
		dragGhost.BackgroundColor3 = definition and definition.DisplayColor or pressState.originalColor
		dragGhost.Visible = true
	end
	if pressState.dragging then
		local position = pointerPosition(input)
		dragGhost.Position = UDim2.fromOffset(position.X, position.Y)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if not pressState or input.UserInputType ~= pressState.inputType then return end
	local state = pressState
	pressState = nil
	if state.button and state.button.Parent then
		state.button.BackgroundColor3 = state.originalColor
		state.button.Text = state.originalText
		state.button.BackgroundTransparency = state.originalBackgroundTransparency
		state.button.TextTransparency = state.originalTextTransparency
	end
	dragGhost.Visible = false
	if state.dragging then gridScroll.ScrollingEnabled = state.originalScrollingEnabled end
	if not gui.Enabled then return end
	local targetSlot = getSlotAtPosition(pointerPosition(input))
	if state.dragging and latestSlots[state.slot] and targetSlot and targetSlot ~= state.slot then
		performSlotAction("Swap", state.slot, targetSlot)
	elseif not state.dragging and targetSlot == state.slot then
		performSlotAction(latestSlots[state.slot] and "Take" or "Deposit", state.slot)
	end
end)

gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not gui.Enabled and pressState then
		local state = pressState
		pressState = nil
		if state.button and state.button.Parent then
			state.button.BackgroundColor3 = state.originalColor
			state.button.Text = state.originalText
			state.button.BackgroundTransparency = state.originalBackgroundTransparency
			state.button.TextTransparency = state.originalTextTransparency
		end
		if state.dragging then gridScroll.ScrollingEnabled = state.originalScrollingEnabled end
		dragGhost.Visible = false
	end
end)

local distanceCheckAt = 0
RunService.Heartbeat:Connect(function()
	if not gui.Enabled or os.clock() - distanceCheckAt < 0.2 then return end
	distanceCheckAt = os.clock()
	local plots = Workspace:FindFirstChild("HousingPlots")
	local ownPlot
	if plots then
		for _, plot in ipairs(plots:GetChildren()) do
			if plot:GetAttribute("OwnerUserId") == player.UserId then ownPlot = plot; break end
		end
	end
	local shelf = ownPlot and ownPlot:FindFirstChild("DisplayShelf", true)
	local part = shelf and (shelf:IsA("BasePart") and shelf or shelf:FindFirstChildWhichIsA("BasePart", true))
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not part or not root or (root.Position - part.Position).Magnitude > 8 then
		gui.Enabled = false
	end
end)

remotes.OpenDisplayShelf.OnClientEvent:Connect(function(slots)
	print("[DisplayShelfClient] OpenDisplayShelf event received")
	latestSlots = slots or {}
	gui.Enabled = true
	refresh(latestSlots)
end)

-- ProximityPrompt/ClickDetector are the normal entry points; direct click is a fallback
-- for Studio places that contain an older shelf part without the server prompt binding.
local mouse = player:GetMouse()
mouse.Button1Down:Connect(function()
	if gui.Enabled then return end
	local target = mouse.Target
	while target and target ~= Workspace do
		if target.Name == "DisplayShelf" and target:IsA("BasePart") then
			print(("[DisplayShelfClient] Direct shelf click fallback: %s"):format(target:GetFullName()))
			remotes.DisplayShelfAction:InvokeServer("Open")
			return
		end
		target = target.Parent
	end
end)

remotes.InventoryUpdated.OnClientEvent:Connect(function(snapshot)
	if gui.Enabled and type(snapshot) == "table" then
		heldItemId = snapshot.HeldItemId
		local definition = heldItemId and catalog.Get(heldItemId)
		heldLabel.Text = definition and ("손에 든 아이템: " .. definition.DisplayName .. " · 빈 칸을 누르면 해당 칸에 진열")
			or "손에 든 아이템: 없음 · 가방에서 아이템을 선택하세요"
	end
end)
