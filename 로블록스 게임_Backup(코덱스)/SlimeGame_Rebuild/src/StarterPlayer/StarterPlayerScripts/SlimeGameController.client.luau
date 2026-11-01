local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SlimeGameRemotes")
local itemCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemCatalog"))

local gui = Instance.new("ScreenGui")
gui.Name = "SlimeGameHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local openCollectionBook = Instance.new("BindableEvent")
openCollectionBook.Name = "OpenCollectionBook"
openCollectionBook.Parent = gui

local currency = Instance.new("TextLabel")
currency.Name = "CurrencyDisplay"
currency.Size = UDim2.fromOffset(220, 38)
currency.Position = UDim2.new(0.5, -110, 0, 12)
currency.BackgroundColor3 = Color3.fromRGB(245, 235, 248)
currency.TextColor3 = Color3.fromRGB(70, 55, 75)
currency.Font = Enum.Font.GothamBold
currency.TextSize = 16
currency.Parent = gui
Instance.new("UICorner", currency).CornerRadius = UDim.new(0, 12)

local function updateCurrency()
	currency.Text = ("골드 %d · 환생 %d"):format(player:GetAttribute("CurrentGold") or 0, player:GetAttribute("RebirthCount") or 0)
end
player:GetAttributeChangedSignal("CurrentGold"):Connect(updateCurrency)
player:GetAttributeChangedSignal("RebirthCount"):Connect(updateCurrency)
updateCurrency()

local panel = Instance.new("Frame")
panel.Name = "Menu"
panel.Size = UDim2.fromOffset(220, 410)
panel.Position = UDim2.new(0, 16, 0.5, -205)
panel.BackgroundColor3 = Color3.fromRGB(245, 235, 248)
panel.BackgroundTransparency = 0.08
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 6)
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = panel
local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.Parent = panel

local bagPanel = Instance.new("Frame")
bagPanel.Name = "ToppingBag"
bagPanel.Size = UDim2.fromOffset(360, 370)
bagPanel.Position = UDim2.new(0.5, -180, 0.5, -185)
bagPanel.BackgroundColor3 = Color3.fromRGB(250, 242, 255)
bagPanel.Visible = false
bagPanel.ZIndex = 10
bagPanel.Parent = gui
Instance.new("UICorner", bagPanel).CornerRadius = UDim.new(0, 14)

local bagTitle = Instance.new("TextLabel")
bagTitle.Size = UDim2.new(1, -60, 0, 38)
bagTitle.Position = UDim2.fromOffset(14, 8)
bagTitle.BackgroundTransparency = 1
bagTitle.Text = "내 토핑 가방"
bagTitle.TextColor3 = Color3.fromRGB(65, 50, 75)
bagTitle.Font = Enum.Font.GothamBold
bagTitle.TextSize = 18
bagTitle.TextXAlignment = Enum.TextXAlignment.Left
bagTitle.ZIndex = 11
bagTitle.Parent = bagPanel

local bagClose = Instance.new("TextButton")
bagClose.Size = UDim2.fromOffset(34, 30)
bagClose.Position = UDim2.new(1, -44, 0, 8)
bagClose.Text = "닫기"
bagClose.TextSize = 11
bagClose.ZIndex = 11
bagClose.Parent = bagPanel
bagClose.Activated:Connect(function() bagPanel.Visible = false end)

local bagSummary = Instance.new("TextLabel")
bagSummary.Size = UDim2.new(1, -28, 0, 30)
bagSummary.Position = UDim2.fromOffset(14, 48)
bagSummary.BackgroundTransparency = 1
bagSummary.TextColor3 = Color3.fromRGB(75, 60, 85)
bagSummary.Font = Enum.Font.GothamMedium
bagSummary.TextSize = 13
bagSummary.TextXAlignment = Enum.TextXAlignment.Left
bagSummary.ZIndex = 11
bagSummary.Parent = bagPanel

local bagList = Instance.new("ScrollingFrame")
bagList.Size = UDim2.new(1, -24, 1, -92)
bagList.Position = UDim2.fromOffset(12, 82)
bagList.BackgroundTransparency = 1
bagList.AutomaticCanvasSize = Enum.AutomaticSize.Y
bagList.CanvasSize = UDim2.new()
bagList.ScrollBarThickness = 5
bagList.ZIndex = 11
bagList.Parent = bagPanel
local bagLayout = Instance.new("UIListLayout")
bagLayout.Padding = UDim.new(0, 5)
bagLayout.Parent = bagList

local function label(text)
	local item = Instance.new("TextLabel")
	item.Size = UDim2.new(1, -16, 0, 34)
	item.BackgroundTransparency = 1
	item.Text = text
	item.TextColor3 = Color3.fromRGB(70, 55, 75)
	item.Font = Enum.Font.GothamBold
	item.TextSize = 18
	item.Parent = panel
	return item
end

local status = label("말랑 슬라임")
status.LayoutOrder = 0
local function button(text, order, callback)
	local item = Instance.new("TextButton")
	item.Size = UDim2.new(1, -16, 0, 38)
	item.BackgroundColor3 = Color3.fromRGB(218, 196, 238)
	item.TextColor3 = Color3.fromRGB(55, 43, 65)
	item.Text = text
	item.Font = Enum.Font.GothamMedium
	item.TextSize = 14
	item.LayoutOrder = order
	Instance.new("UICorner", item).CornerRadius = UDim.new(0, 9)
	item.Parent = panel
	item.Activated:Connect(function()
		local ok, message = pcall(callback)
		if not ok then status.Text = "요청 오류"; warn(message) end
	end)
end

local function request(remoteName, ...)
	local ok, message, extra = remotes:WaitForChild(remoteName):InvokeServer(...)
	status.Text = tostring(message or (ok and "완료" or "요청 실패"))
	return ok, message, extra
end

local function renderBag(snapshot)
	if type(snapshot) ~= "table" or snapshot.Message then return end
	for _, child in ipairs(bagList:GetChildren()) do
		if child:IsA("TextLabel") or child:IsA("TextButton") then child:Destroy() end
	end
	local counts = {}
	local cleanTotal = 0
	for itemId, amount in pairs(snapshot.CraftBasket or {}) do
		local definition = itemCatalog.Get(itemId)
		if definition and amount > 0 then
			counts[itemId] = (counts[itemId] or 0) + amount
			cleanTotal += amount
		end
	end
	for _, itemId in ipairs(snapshot.GachaCabinet or {}) do
		local definition = itemCatalog.Get(itemId)
		if definition then
			counts[itemId] = (counts[itemId] or 0) + 1
			cleanTotal += 1
		end
	end
	local dirtyCount = snapshot.DirtyBag and 1 or 0
	local workerCount = math.max(0, math.floor(tonumber(snapshot.WorkerBagCount) or 0))
	bagSummary.Text = ("재료 %d개 · 노동자 %d명 · 세척 전 토핑 %d개"):format(cleanTotal, workerCount, dirtyCount)
	local function addBagRow(text, color, itemId, onActivate)
		local row = Instance.new((itemId or onActivate) and "TextButton" or "TextLabel")
		row.Size = UDim2.new(1, -8, 0, 34)
		row.BackgroundColor3 = Color3.fromRGB(239, 228, 247)
		row.TextColor3 = Color3.fromRGB(65, 50, 75)
		row.Text = text
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Font = Enum.Font.GothamMedium
		row.TextSize = 14
		row.ZIndex = 12
		row.Parent = bagList
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
		local rarityStroke = Instance.new("UIStroke")
		rarityStroke.Thickness = 1.5
		rarityStroke.Color = color or Color3.fromRGB(210, 195, 220)
		rarityStroke.Parent = row
		local rowPadding = Instance.new("UIPadding")
		rowPadding.PaddingLeft = UDim.new(0, 10)
		rowPadding.Parent = row
		if onActivate then
			row.AutoButtonColor = true
			row.Activated:Connect(onActivate)
		elseif itemId then
			row.AutoButtonColor = true
			row.Activated:Connect(function()
				local ok, displayName = remotes.SetHeldTopping:InvokeServer(itemId)
				if ok then
					snapshot.HeldItemId = itemId
					local selectedDefinition = itemCatalog.Get(itemId)
					status.Text = selectedDefinition and selectedDefinition.Category == "DirtyTopping"
						and "더러운 토핑을 다시 선택했어요. 세척대에서 씻어 주세요."
						or ((displayName or "토핑") .. " 선택됨 · 이 토핑만 배치할 수 있어요.")
					renderBag(snapshot)
				else
					status.Text = tostring(displayName or "토핑을 선택하지 못했어요.")
				end
			end)
		end
	end
	if snapshot.DirtyBag then
		local dirtyDefinition = itemCatalog.Get(snapshot.DirtyBag)
		local heldText = snapshot.HeldItemId == snapshot.DirtyBag and " · 손에 듦" or ""
		addBagRow((dirtyDefinition and dirtyDefinition.DisplayName or "더러운 토핑") .. " ×1 · 세척 전" .. heldText, Color3.fromRGB(120, 82, 54), snapshot.DirtyBag)
	end
	local ids = {}
	for itemId in pairs(counts) do table.insert(ids, itemId) end
	table.sort(ids, function(a, b)
		local da, db = itemCatalog.Get(a), itemCatalog.Get(b)
		return (da and da.DisplayName or a) < (db and db.DisplayName or b)
	end)
	for _, itemId in ipairs(ids) do
		local definition = itemCatalog.Get(itemId)
		local rarity = definition and itemCatalog.Rarities[definition.Rarity]
		local selectedMark = snapshot.HeldItemId == itemId and " · 손에 듦" or ""
		addBagRow((definition and definition.DisplayName or itemId) .. " ×" .. counts[itemId] .. selectedMark, rarity and rarity.Color, itemId)
	end
	if workerCount > 0 then
		local selectedText = snapshot.WorkerPlacementSelected and " · 선택됨, 패드에서 E" or " · 눌러서 배치 선택"
		addBagRow("노동자 ×" .. workerCount .. selectedText, Color3.fromRGB(194, 143, 77), nil, function()
			local action = snapshot.WorkerPlacementSelected and "CancelPlacement" or "SelectForPlacement"
			local ok, message = remotes.WorkerAction:InvokeServer(action)
			status.Text = tostring(message or (ok and "노동자를 선택했어요." or "노동자를 선택하지 못했어요."))
			if ok then
				snapshot.WorkerPlacementSelected = action == "SelectForPlacement"
				renderBag(snapshot)
			end
		end)
	end
	if cleanTotal == 0 and dirtyCount == 0 and workerCount == 0 then addBagRow("가방이 비어 있어요.") end
end

button("가방 보기", 1, function()
	local snapshot, message = remotes.RequestInventory:InvokeServer()
	if snapshot then
		renderBag(snapshot)
		bagPanel.Visible = true
	else status.Text = tostring(message or "데이터 로딩 중") end
end)
button("수집 도감", 2, function()
	openCollectionBook:Fire()
	status.Text = "아이템 도감을 열었어요."
end)
button("노동자 고용", 3, function() request("WorkerAction", "Buy") end)
button("노동자 속도/수익 강화", 4, function() request("WorkerAction", "UpgradeIncome") end)
button("무료 캡슐 열기", 5, function() request("GachaAction", "Roll", 1) end)
button("환생", 6, function() request("RequestRebirth") end)
button("화면/ASMR 설정", 7, function()
	status.Text = "ASMR 사운드 자산 ID를 정하면 설정 UI를 연결할게요."
end)

remotes.InventoryUpdated.OnClientEvent:Connect(function(snapshot)
	if type(snapshot) ~= "table" then
		status.Text = "인벤토리가 업데이트됐어요."
	elseif snapshot.Message then
		status.Text = tostring(snapshot.Message)
	else
		renderBag(snapshot)
		local cleanTotal = 0
		for itemId, amount in pairs(snapshot.CraftBasket or {}) do
			if itemCatalog.Get(itemId) then cleanTotal += amount end
		end
		for _, itemId in ipairs(snapshot.GachaCabinet or {}) do
			if itemCatalog.Get(itemId) then cleanTotal += 1 end
		end
		status.Text = snapshot.DirtyBag and "더러운 토핑을 가방에 넣었어요. 세척대로 가세요."
			or ("가방 업데이트 · 깨끗한 토핑 %d개"):format(cleanTotal)
	end
end)
