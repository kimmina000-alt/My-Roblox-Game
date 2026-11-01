local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SlimeGameRemotes")
local catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemCatalog"))

local gui = Instance.new("ScreenGui")
gui.Name = "SlimeInteractionGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 30
gui.Parent = player:WaitForChild("PlayerGui")

local selectedItemId
local heldItemId
local panelMode
local workerPlacementSelected = false
remotes:WaitForChild("WorkerSelectionChanged").OnClientEvent:Connect(function(isSelected)
	workerPlacementSelected = isSelected == true
end)
local selectButton = Instance.new("TextButton")
selectButton.Name = "SelectToppingButton"
selectButton.Size = UDim2.fromOffset(210, 62)
selectButton.Position = UDim2.new(0.5, -105, 1, -74)
selectButton.BackgroundColor3 = Color3.fromRGB(218, 196, 238)
selectButton.TextColor3 = Color3.fromRGB(55, 43, 65)
selectButton.Text = "토핑 슬롯\n클릭해서 선택"
selectButton.Font = Enum.Font.GothamBold
selectButton.TextSize = 14
selectButton.TextWrapped = true
selectButton.Parent = gui
Instance.new("UICorner", selectButton).CornerRadius = UDim.new(0, 10)

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(330, 300)
panel.Position = UDim2.new(0.5, -165, 0.5, -150)
panel.BackgroundColor3 = Color3.fromRGB(250, 242, 255)
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)

local heading = Instance.new("TextLabel")
heading.Size = UDim2.new(1, -52, 0, 38)
heading.Position = UDim2.fromOffset(10, 7)
heading.BackgroundTransparency = 1
heading.Font = Enum.Font.GothamBold
heading.TextSize = 18
heading.TextColor3 = Color3.fromRGB(65, 50, 75)
heading.TextXAlignment = Enum.TextXAlignment.Left
heading.Parent = panel

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(34, 30)
close.Position = UDim2.new(1, -42, 0, 8)
close.Text = "닫기"
close.TextSize = 11
close.Parent = panel
close.Activated:Connect(function() panel.Visible = false; panelMode = nil end)

local baseConfirm = Instance.new("Frame")
baseConfirm.Name = "RetrieveBaseConfirmation"
baseConfirm.Size = UDim2.fromOffset(390, 170)
baseConfirm.Position = UDim2.new(0.5, -195, 0.5, -85)
baseConfirm.BackgroundColor3 = Color3.fromRGB(250, 242, 255)
baseConfirm.Visible = false
baseConfirm.ZIndex = 20
baseConfirm.Parent = gui
Instance.new("UICorner", baseConfirm).CornerRadius = UDim.new(0, 14)
local baseConfirmText = Instance.new("TextLabel")
baseConfirmText.Size = UDim2.new(1, -24, 0, 96)
baseConfirmText.Position = UDim2.fromOffset(12, 6)
baseConfirmText.BackgroundTransparency = 1
baseConfirmText.TextWrapped = true
baseConfirmText.Font = Enum.Font.GothamMedium
baseConfirmText.TextSize = 16
baseConfirmText.TextColor3 = Color3.fromRGB(65, 50, 75)
baseConfirmText.ZIndex = 21
baseConfirmText.Parent = baseConfirm
local cancelBaseRetrieve = Instance.new("TextButton")
cancelBaseRetrieve.Size = UDim2.new(0.45, -8, 0, 42)
cancelBaseRetrieve.Position = UDim2.new(0, 12, 1, -54)
cancelBaseRetrieve.Text = "취소"
cancelBaseRetrieve.ZIndex = 21
cancelBaseRetrieve.Parent = baseConfirm
local acceptBaseRetrieve = Instance.new("TextButton")
acceptBaseRetrieve.Size = UDim2.new(0.45, -8, 0, 42)
acceptBaseRetrieve.Position = UDim2.new(0.55, -4, 1, -54)
acceptBaseRetrieve.Text = "회수하기"
acceptBaseRetrieve.ZIndex = 21
acceptBaseRetrieve.Parent = baseConfirm
local pendingBasePlacementId
cancelBaseRetrieve.Activated:Connect(function()
	baseConfirm.Visible = false
	pendingBasePlacementId = nil
end)
acceptBaseRetrieve.Activated:Connect(function()
	if not pendingBasePlacementId then return end
	local ok, message = remotes.PlaceBase:InvokeServer("Retrieve", pendingBasePlacementId, nil, true)
	selectButton.Text = tostring(message or (ok and "베이스와 토핑을 회수했어요." or "회수하지 못했어요."))
	baseConfirm.Visible = false
	pendingBasePlacementId = nil
end)
remotes.RequestBaseRetrieve.OnClientEvent:Connect(function(placementId, toppingCount, workerCount)
	pendingBasePlacementId = placementId
	toppingCount = math.max(0, math.floor(tonumber(toppingCount) or 0))
	workerCount = math.max(0, math.floor(tonumber(workerCount) or 0))
	baseConfirmText.Text = ("베이스 회수 시 패드 위 토핑 %d개와 노동자 %d명이 인벤토리로 돌아옵니다. 회수할까요?")
		:format(toppingCount, workerCount)
	baseConfirm.Visible = true
end)

local body = Instance.new("TextLabel")
body.Size = UDim2.new(1, -20, 0, 42)
body.Position = UDim2.fromOffset(10, 48)
body.BackgroundTransparency = 1
body.TextWrapped = true
body.Font = Enum.Font.Gotham
body.TextSize = 14
body.TextColor3 = Color3.fromRGB(75, 60, 85)
body.Parent = panel

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -20, 1, -100)
list.Position = UDim2.fromOffset(10, 94)
list.BackgroundTransparency = 1
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.ScrollBarThickness = 5
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 5)
layout.Parent = list

local cleaningStage = Instance.new("Frame")
cleaningStage.Name = "CleaningStage"
cleaningStage.Size = UDim2.new(1, -20, 1, -100)
cleaningStage.Position = UDim2.fromOffset(10, 94)
cleaningStage.BackgroundTransparency = 1
cleaningStage.Visible = false
cleaningStage.Parent = panel

local dirtyBall = Instance.new("Frame")
dirtyBall.Name = "DirtyToppingImage"
dirtyBall.Size = UDim2.fromOffset(116, 116)
dirtyBall.Position = UDim2.fromOffset(28, 8)
dirtyBall.BackgroundColor3 = Color3.fromRGB(130, 112, 91)
dirtyBall.BorderSizePixel = 0
dirtyBall.Parent = cleaningStage
Instance.new("UICorner", dirtyBall).CornerRadius = UDim.new(1, 0)
dirtyBall.ClipsDescendants = true
dirtyBall.BackgroundColor3 = Color3.fromRGB(255, 205, 223)
local ballStroke = Instance.new("UIStroke")
ballStroke.Thickness = 3
ballStroke.Color = Color3.fromRGB(255, 240, 247)
ballStroke.Parent = dirtyBall

local dirtyFilm = Instance.new("Frame")
dirtyFilm.Name = "DirtyFilm"
dirtyFilm.Size = UDim2.fromScale(1, 1)
dirtyFilm.BackgroundColor3 = Color3.fromRGB(130, 112, 91)
dirtyFilm.BorderSizePixel = 0
dirtyFilm.ZIndex = 1
dirtyFilm.Parent = dirtyBall
Instance.new("UICorner", dirtyFilm).CornerRadius = UDim.new(1, 0)
dirtyFilm.ClipsDescendants = true

-- Transparent hit surface lets the player start a continuous scrub gesture on the topping.
local holdSurface = Instance.new("TextButton")
holdSurface.Name = "ToppingHoldSurface"
holdSurface.Size = UDim2.fromScale(1, 1)
holdSurface.BackgroundTransparency = 1
holdSurface.Text = ""
holdSurface.AutoButtonColor = false
holdSurface.ZIndex = 4
holdSurface.Parent = dirtyBall

local dirtSpots = {}
for index = 1, 8 do
	local spot = Instance.new("Frame")
	spot.Name = "DirtSpot" .. index
	spot.Size = UDim2.fromOffset(index % 3 + 5, index % 3 + 5)
	spot.Position = UDim2.new((index * 37 % 78) / 100, 0, (index * 23 % 78) / 100, 0)
	spot.BackgroundColor3 = Color3.fromRGB(76, 63, 51)
	spot.BackgroundTransparency = 0.1
	spot.BorderSizePixel = 0
	spot.ZIndex = 2
	spot.Parent = dirtyFilm
	Instance.new("UICorner", spot).CornerRadius = UDim.new(1, 0)
	table.insert(dirtSpots, spot)
end

local cleanCount = Instance.new("TextLabel")
cleanCount.Size = UDim2.new(1, 0, 0, 24)
cleanCount.Position = UDim2.new(0, 0, 1, -25)
cleanCount.BackgroundTransparency = 1
cleanCount.Text = "누른 채 드래그/터치한 곳만 세척돼 · 0%"
cleanCount.TextColor3 = Color3.fromRGB(75, 60, 85)
cleanCount.Font = Enum.Font.GothamMedium
cleanCount.TextSize = 13
cleanCount.Parent = cleaningStage

local tada = Instance.new("TextLabel")
tada.Name = "TadaEffect"
tada.Size = UDim2.new(1, 0, 0, 60)
tada.Position = UDim2.new(0, 0, 0.5, -30)
tada.BackgroundTransparency = 1
tada.Text = "짜란! 깨끗해졌어! ✨"
tada.TextColor3 = Color3.fromRGB(255, 240, 125)
tada.TextStrokeTransparency = 0.15
tada.TextStrokeColor3 = Color3.fromRGB(128, 83, 170)
tada.Font = Enum.Font.GothamBlack
tada.TextSize = 24
tada.Visible = false
tada.ZIndex = 5
tada.Parent = cleaningStage
local tadaScale = Instance.new("UIScale")
tadaScale.Scale = 0.5
tadaScale.Parent = tada

local function clearRows()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
end

local function addRow(text, callback)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -8, 0, 34)
	button.BackgroundColor3 = Color3.fromRGB(226, 211, 240)
	button.TextColor3 = Color3.fromRGB(55, 43, 65)
	button.Text = text
	button.TextSize = 13
	button.Parent = list
	button.Activated:Connect(callback)
end

local function getOwnedToppingCounts(snapshot)
	local counts = {}
	for itemId, amount in pairs(snapshot.CraftBasket or {}) do
		local definition = catalog.Get(itemId)
		if amount > 0 and definition and (definition.Category == "Topping" or definition.Category == "Base") then
			counts[itemId] = (counts[itemId] or 0) + amount
		end
	end
	for _, itemId in ipairs(snapshot.GachaCabinet or {}) do
		local definition = catalog.Get(itemId)
		if definition and (definition.Category == "Topping" or definition.Category == "Base") then
			counts[itemId] = (counts[itemId] or 0) + 1
		end
	end
	return counts
end

local function updateSlot(snapshot)
	if type(snapshot) ~= "table" or snapshot.Message then return end
	local counts = getOwnedToppingCounts(snapshot)
	heldItemId = snapshot.HeldItemId
	selectedItemId = heldItemId
	if not selectedItemId or (counts[selectedItemId] or 0) <= 0 then selectedItemId = nil end
	if heldItemId and snapshot.DirtyBag == heldItemId then
		local definition = catalog.Get(heldItemId)
		selectButton.Text = ("%s ×1\n세척한 뒤 배치할 수 있어요"):format(definition and definition.DisplayName or "더러운 토핑")
		return
	end
	if selectedItemId then
		local definition = catalog.Get(selectedItemId)
		local placeLabel = definition.Category == "Base" and "베이스 패드에 배치" or "토핑 패드에 배치"
		selectButton.Text = ("%s  ×%d\n클릭해 변경 · %s"):format(definition.DisplayName, counts[selectedItemId] or 0, placeLabel)
	else
		selectButton.Text = "토핑 슬롯\n보유 토핑 없음 · 클릭해서 선택"
	end
end

local function updateCleaningPrompt(snapshot)
	if type(snapshot) ~= "table" or snapshot.Message then return end
	local station = Workspace:FindFirstChild("CleaningTable", true)
	local prompt = station and station:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then prompt.Enabled = snapshot.DirtyBag ~= nil end
end

task.spawn(function()
	local snapshot
	local ok = pcall(function() snapshot = remotes.RequestInventory:InvokeServer() end)
	if ok and snapshot then updateSlot(snapshot) end
	local deadline = os.clock() + 30
	while os.clock() < deadline do
		local station = Workspace:FindFirstChild("CleaningTable", true)
		if station then
			local prompt = station:FindFirstChildWhichIsA("ProximityPrompt", true)
			if prompt then prompt.Enabled = false end
			if ok and snapshot then updateCleaningPrompt(snapshot) end
			return
		end
		task.wait(0.25)
	end
end)

local function showItemPicker()
	local snapshot, message = remotes.RequestInventory:InvokeServer()
	panel.Visible = true
	panelMode = "Picker"
	list.Visible = true
	cleaningStage.Visible = false
	heading.Text = "배치할 재료 선택"
	clearRows()
	if not snapshot then body.Text = tostring(message or "가방을 불러오지 못했어요."); return end
	updateSlot(snapshot)
	body.Text = "토핑은 넓은 패드 원하는 곳에, 베이스는 베이스 패드 하나당 하나씩 놓을 수 있어. 놓인 아이템을 다시 클릭하면 회수돼."
	local counts = getOwnedToppingCounts(snapshot)
	local ids = {}
	for itemId in pairs(counts) do table.insert(ids, itemId) end
	table.sort(ids)
	if #ids == 0 then
		body.Text = "배치 가능한 베이스나 깨끗한 토핑이 없어요. 토핑을 씻거나 베이스 펌프에서 퍼 주세요."
		return
	end
	for _, itemId in ipairs(ids) do
		local amount = counts[itemId]
		local definition = catalog.Get(itemId)
		addRow((definition.DisplayName .. " x" .. amount), function()
			local setHeld = remotes:FindFirstChild("SetHeldTopping")
			if setHeld and setHeld:IsA("RemoteFunction") then
				local ok, result = setHeld:InvokeServer(itemId)
				if not ok then body.Text = tostring(result or "토핑을 들 수 없어요."); return end
			end
			selectedItemId = itemId
			heldItemId = itemId
			snapshot.HeldItemId = itemId
			updateSlot(snapshot)
			body.Text = "이제 개인 구역의 패드를 마우스로 클릭해."
			panel.Visible = false
			panelMode = nil
		end)
	end
end

selectButton.Activated:Connect(showItemPicker)

local mouse = player:GetMouse()
mouse.Button1Down:Connect(function()
	if panel.Visible or baseConfirm.Visible or workerPlacementSelected then return end
	local target = mouse.Target
	if not target then return end
	local placementId = target:GetAttribute("PlacementId")
	if placementId then
		if target:GetAttribute("PlacementKind") == "Base" and selectedItemId
			and catalog.Get(selectedItemId) and catalog.Get(selectedItemId).Category == "Topping" then
			local padPath = target:GetAttribute("PadPath")
			local plot = target.Parent and target.Parent.Parent
			local pad = plot
			for segment in string.gmatch(padPath or "", "[^/]+") do
				pad = pad and pad:FindFirstChild(segment)
			end
			if not pad then selectButton.Text = "베이스 패드 정보를 찾을 수 없어요"; return end
			local localHit = pad.CFrame:PointToObjectSpace(mouse.Hit.Position)
			localHit = Vector3.new(localHit.X, pad.Size.Y / 2 + target.Size.Y + 0.45, localHit.Z)
			local position = pad.CFrame:PointToWorldSpace(localHit)
			local ok, result = remotes.PlaceTopping:InvokeServer("Place", selectedItemId, pad, position)
			if not ok then selectButton.Text = "배치 실패\n" .. tostring(result or "다시 시도해") end
		elseif target:GetAttribute("PlacementKind") == "Base" then
			selectButton.Text = "베이스 앞 표지판을 클릭해 회수해"
		else
			local ok, result = remotes.PlaceTopping:InvokeServer("Retrieve", placementId)
			selectButton.Text = ok and "토핑 회수 완료" or tostring(result or "회수 실패")
		end
		return
	end
	if target:GetAttribute("IsToppingPad") or target:GetAttribute("IsBasePad") then
		if not selectedItemId then
			selectButton.Text = heldItemId and "토핑 슬롯\n깨끗한 토핑을 선택해" or "토핑 슬롯\n먼저 토핑을 선택해"
			return
		end
		local definition = catalog.Get(selectedItemId)
		local isBasePad = target:GetAttribute("IsBasePad") == true
		if isBasePad ~= (definition and definition.Category == "Base") then
			selectButton.Text = isBasePad and "베이스 패드에는 베이스를 선택해" or "토핑 패드에는 토핑을 선택해"
			return
		end
		local position = mouse.Hit.Position + target.CFrame.UpVector * 0.4
		local remote = isBasePad and remotes.PlaceBase or remotes.PlaceTopping
		local ok, result = remote:InvokeServer("Place", selectedItemId, target, position)
		if not ok then selectButton.Text = "배치 실패\n" .. tostring(result or "다시 시도해") end
	end
end)

remotes.InventoryUpdated.OnClientEvent:Connect(function(snapshot)
	updateSlot(snapshot)
	updateCleaningPrompt(snapshot)
end)
task.spawn(function()
	while true do
		task.wait(0.4)
		if panelMode == "Cleaning" and panel.Visible then
			local station = Workspace:FindFirstChild("CleaningTable", true)
			local stationPart = station and (station:IsA("BasePart") and station or station:FindFirstChildWhichIsA("BasePart", true))
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if stationPart and root and (root.Position - stationPart.Position).Magnitude > 14 then
				panel.Visible = false
				panelMode = nil
			end
		end
	end
end)

local cleaningRunId = 0
local cleaningSessionConnections = {}
local function showCleaning(canClean, message)
	for _, connection in ipairs(cleaningSessionConnections) do connection:Disconnect() end
	table.clear(cleaningSessionConnections)
	cleaningRunId += 1
	local thisRun = cleaningRunId
	panel.Visible = true
	panelMode = "Cleaning"
	list.Visible = false
	cleaningStage.Visible = true
	cleanCount.Visible = true
	heading.Text = "토핑 세척"
	clearRows()
	body.Text = tostring(message or (canClean and "더러운 토핑을 꾹 누르고 있으면 점점 깨끗해져." or "더러운 토핑을 먼저 가지고 와."))
	dirtyBall.BackgroundColor3 = Color3.fromRGB(255, 205, 223)
	ballStroke.Color = Color3.fromRGB(255, 240, 247)
	dirtyFilm.Visible = true
	for _, child in ipairs(dirtyFilm:GetChildren()) do
		if child.Name == "CleanPatch" then child:Destroy() end
	end
	for _, spot in ipairs(dirtSpots) do spot.Visible = true end
	tada.Visible = false
	tadaScale.Scale = 0.5
	local startedAt = os.clock()
	local isHolding = false
	local cleaningFinished = false
	local activeTouch
	local lastScrubPosition
	local brushRadius = 18
	local cellSize = 12
	local cleanedCells = {}
	local cleanPatchCells = {}
	local coverageCount = 0
	local requiredCells = {}
	local remainingDirt = #dirtSpots
	local ballSize = dirtyBall.AbsoluteSize
	local ballCenter = ballSize / 2
	local ballRadius = math.min(ballSize.X, ballSize.Y) / 2
	for x = 0, math.ceil(ballSize.X / cellSize) - 1 do
		for y = 0, math.ceil(ballSize.Y / cellSize) - 1 do
			local center = Vector2.new((x + 0.5) * cellSize, (y + 0.5) * cellSize)
			if (center - ballCenter).Magnitude <= ballRadius - cellSize * 0.25 then
				table.insert(requiredCells, { Key = x .. ":" .. y, Center = center })
			end
		end
	end
	local coverageTotal = #requiredCells
	cleanCount.Text = "누른 채 움직여 닿은 곳을 닦아 줘 · 얼룩 " .. remainingDirt .. "개"
	local function toBallPosition(screenPosition)
		return screenPosition - dirtyBall.AbsolutePosition
	end
	local function pointerPosition()
		local inset = GuiService:GetGuiInset()
		if activeTouch then
			return Vector2.new(activeTouch.Position.X, activeTouch.Position.Y) - inset
		end
		return UserInputService:GetMouseLocation() - inset
	end
	local function scrubPoint(position)
		if (position - ballCenter).Magnitude > ballRadius then return end
		for _, cell in ipairs(requiredCells) do
			if not cleanedCells[cell.Key] and (position - cell.Center).Magnitude <= brushRadius then
				cleanedCells[cell.Key] = true
				coverageCount += 1
			end
		end
		local patchX = math.floor(position.X / (brushRadius * 0.75))
		local patchY = math.floor(position.Y / (brushRadius * 0.75))
		local patchKey = patchX .. ":" .. patchY
		if not cleanPatchCells[patchKey] then
			cleanPatchCells[patchKey] = true
			local patch = Instance.new("Frame")
			patch.Name = "CleanPatch"
			local softRadius = brushRadius + 7
			patch.Size = UDim2.fromOffset(softRadius * 2, softRadius * 2)
			patch.Position = UDim2.fromOffset(position.X - softRadius, position.Y - softRadius)
			patch.BackgroundTransparency = 1
			patch.BorderSizePixel = 0
			patch.ZIndex = 3
			patch.Parent = dirtyFilm
			-- Concentric translucent layers approximate a soft radial fade without a hard circular edge.
			local layers = {
				{ Diameter = 48, Transparency = 0.90 },
				{ Diameter = 42, Transparency = 0.82 },
				{ Diameter = 36, Transparency = 0.67 },
				{ Diameter = 30, Transparency = 0.48 },
				{ Diameter = 24, Transparency = 0.27 },
				{ Diameter = 18, Transparency = 0.08 },
			}
			for layerIndex, layer in ipairs(layers) do
				local glow = Instance.new("Frame")
				glow.Name = "SoftEdge" .. layerIndex
				glow.AnchorPoint = Vector2.new(0.5, 0.5)
				glow.Position = UDim2.fromOffset(softRadius, softRadius)
				glow.Size = UDim2.fromOffset(layer.Diameter, layer.Diameter)
				glow.BackgroundColor3 = Color3.fromRGB(255, 205, 223)
				glow.BackgroundTransparency = layer.Transparency
				glow.BorderSizePixel = 0
				glow.ZIndex = layerIndex + 3
				glow.Parent = patch
				Instance.new("UICorner", glow).CornerRadius = UDim.new(1, 0)
			end
		end
		for _, spot in ipairs(dirtSpots) do
			if spot.Visible then
				local spotCenter = spot.AbsolutePosition - dirtyFilm.AbsolutePosition + spot.AbsoluteSize / 2
				if (position - spotCenter).Magnitude <= brushRadius + math.max(spot.AbsoluteSize.X, spot.AbsoluteSize.Y) / 2 then
					spot.Visible = false
					remainingDirt -= 1
				end
			end
		end
		local progress = coverageTotal > 0 and coverageCount / coverageTotal or 0
		cleanCount.Text = (isHolding and "세척 중 · " or "진행도 · ")
			.. ("%d%% · 얼룩 %d개 남음"):format(math.floor(progress * 100), remainingDirt)
		return progress
	end
	local function completeCleaning()
		if thisRun ~= cleaningRunId or not panel.Visible or panelMode ~= "Cleaning" then return end
		task.spawn(function()
			task.wait(math.max(0, 1.5 - (os.clock() - startedAt)))
			if thisRun ~= cleaningRunId or not panel.Visible or panelMode ~= "Cleaning" then return end
			local ok, result, rewardItemId = remotes.CleaningAction:InvokeServer("Complete", 5)
			if not ok then
				body.Text = tostring(result or "세척에 실패했어요.")
				return
			end
			dirtyFilm.Visible = false
			for _, spot in ipairs(dirtSpots) do spot.Visible = false end
			local cleanDefinition = rewardItemId and catalog.Get(rewardItemId)
			cleanCount.Text = "깨끗해진 토핑: " .. (cleanDefinition and cleanDefinition.DisplayName or "토핑")
			cleanCount.Visible = true
			tada.Visible = false
			task.wait(0.275) -- Show the clean reward briefly, then close twice as fast.
			if thisRun ~= cleaningRunId or not panel.Visible or panelMode ~= "Cleaning" then return end
			cleanCount.Visible = false
			tada.Visible = true
			TweenService:Create(tadaScale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
			task.wait(0.4)
			if thisRun == cleaningRunId and panelMode == "Cleaning" then
				panel.Visible = false
				panelMode = nil
				cleaningStage.Visible = false
				list.Visible = true
				cleanCount.Visible = true
			end
		end)
	end
	local function beginHold(input)
		if not canClean or cleaningFinished then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isHolding = true
			activeTouch = input.UserInputType == Enum.UserInputType.Touch and input or nil
			lastScrubPosition = toBallPosition(pointerPosition())
			scrubPoint(lastScrubPosition)
		end
	end
	local holdBeginConnection = holdSurface.InputBegan:Connect(beginHold)
	table.insert(cleaningSessionConnections, holdBeginConnection)
	local touchMoveConnection = UserInputService.TouchMoved:Connect(function(input)
		if isHolding and activeTouch then activeTouch = input end
	end)
	table.insert(cleaningSessionConnections, touchMoveConnection)
	local endedConnection = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isHolding = false
			activeTouch = nil
			lastScrubPosition = nil
			if not cleaningFinished then
				local progress = coverageTotal > 0 and coverageCount / coverageTotal or 0
				cleanCount.Text = ("멈춤 · 닦은 영역 %d%% · 얼룩 %d개 남음"):format(math.floor(progress * 100), remainingDirt)
			end
		end
	end)
	table.insert(cleaningSessionConnections, endedConnection)
	local holdProgressConnection = RunService.Heartbeat:Connect(function()
		if thisRun ~= cleaningRunId or not panel.Visible or panelMode ~= "Cleaning" or cleaningFinished then return end
		if isHolding then
			local currentPosition = toBallPosition(pointerPosition())
			local currentInside = (currentPosition - ballCenter).Magnitude <= ballRadius
			if currentInside then
				if lastScrubPosition then
					local distance = (currentPosition - lastScrubPosition).Magnitude
					local steps = math.max(1, math.ceil(distance / 6))
					for step = 1, steps do
						local sample = lastScrubPosition:Lerp(currentPosition, step / steps)
						scrubPoint(sample)
					end
				else
					scrubPoint(currentPosition)
				end
				lastScrubPosition = currentPosition
			else
				lastScrubPosition = nil
			end
			if coverageCount >= coverageTotal and remainingDirt <= 0 then
				cleaningFinished = true
				isHolding = false
				completeCleaning()
			end
		end
	end)
	table.insert(cleaningSessionConnections, holdProgressConnection)
	local visibilityConnection
	visibilityConnection = panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible and thisRun == cleaningRunId then
			isHolding = false
			for _, connection in ipairs(cleaningSessionConnections) do connection:Disconnect() end
			table.clear(cleaningSessionConnections)
		end
	end)
	table.insert(cleaningSessionConnections, visibilityConnection)
end

remotes.OpenCleaning.OnClientEvent:Connect(showCleaning)
