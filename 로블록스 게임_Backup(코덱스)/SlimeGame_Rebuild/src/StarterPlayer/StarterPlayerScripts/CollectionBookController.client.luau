local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemCatalog"))
local remotes = ReplicatedStorage:WaitForChild("SlimeGameRemotes")
local gui = player:WaitForChild("PlayerGui"):WaitForChild("SlimeGameHUD")
local opener = gui:WaitForChild("OpenCollectionBook")

local panel = Instance.new("Frame")
panel.Name = "CollectionBook"
panel.Size = UDim2.new(0.78, 0, 0.78, 0)
panel.Position = UDim2.new(0.11, 0, 0.11, 0)
panel.BackgroundColor3 = Color3.fromRGB(247, 240, 250)
panel.Visible = false
panel.ZIndex = 20
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 0, 44)
title.Position = UDim2.fromOffset(16, 8)
title.BackgroundTransparency = 1
title.Text = "아이템 도감"
title.TextColor3 = Color3.fromRGB(65, 50, 75)
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 21
title.Parent = panel

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(42, 34)
close.Position = UDim2.new(1, -52, 0, 10)
close.Text = "닫기"
close.ZIndex = 21
close.Parent = panel
close.Activated:Connect(function() panel.Visible = false end)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -24, 1, -64)
scroll.Position = UDim2.fromOffset(12, 54)
scroll.BackgroundTransparency = 1
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new()
scroll.ScrollBarThickness = 7
scroll.ZIndex = 21
scroll.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = scroll

local function clear()
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("GuiObject") and child ~= layout then child:Destroy() end
	end
end

local function makeLabel(text, height, order, color)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -8, 0, height)
	label.LayoutOrder = order
	label.BackgroundColor3 = color or Color3.fromRGB(239, 229, 245)
	label.TextColor3 = Color3.fromRGB(70, 55, 75)
	label.Text = text
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 22
	label.Parent = scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.Parent = label
	Instance.new("UICorner", label).CornerRadius = UDim.new(0, 9)
	return label
end

local function render(book)
	clear()
	local items = catalog.GetCollectionItems()
	local order = 0
	for _, rarityId in ipairs(catalog.RarityOrder) do
		local rarity = catalog.Rarities[rarityId]
		local tierItems = {}
		for _, entry in ipairs(items) do
			if entry.Definition.Rarity == rarityId then table.insert(tierItems, entry) end
		end
		if #tierItems > 0 then
			order += 1
			makeLabel(rarity.DisplayName, 34, order, rarity.BookColor)
			for _, entry in ipairs(tierItems) do
				order += 1
				local definition = entry.Definition
				local discovered = book[entry.Id] == true
				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, -8, 0, 66)
				row.LayoutOrder = order
				row.BackgroundColor3 = rarity.BookColor
				row.BackgroundTransparency = rarityId == "Common" and 0 or 0.12
				row.ZIndex = 22
				row.Parent = scroll
				Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
				local icon = Instance.new("TextLabel")
				icon.Size = UDim2.fromOffset(50, 50)
				icon.Position = UDim2.fromOffset(8, 8)
				icon.BackgroundTransparency = 1
				local glyphs = { Ball = "●", Cluster = "✣", Chip = "◆", Star = "★", Drop = "♦", Blob = "●", Pearl = "●" }
				icon.Text = glyphs[definition.IconShape] or "●"
				icon.TextColor3 = discovered and (definition.DisplayColor or Color3.fromRGB(255, 255, 255)) or Color3.fromRGB(0, 0, 0)
				icon.TextSize = 28
				icon.ZIndex = 23
				icon.Parent = row
				Instance.new("UICorner", icon).CornerRadius = UDim.new(0, 9)
				local name = Instance.new("TextLabel")
				name.Size = UDim2.new(1, -76, 1, 0)
				name.Position = UDim2.fromOffset(68, 0)
				name.BackgroundTransparency = 1
				name.Text = discovered and definition.DisplayName or "???  ·  아직 발견하지 못함"
				name.TextColor3 = Color3.fromRGB(55, 45, 60)
				name.Font = Enum.Font.GothamMedium
				name.TextSize = 15
				name.TextXAlignment = Enum.TextXAlignment.Left
				name.ZIndex = 23
				name.Parent = row
			end
		end
	end
	local discoveredCount = 0
	for _, entry in ipairs(items) do if book[entry.Id] then discoveredCount += 1 end end
	title.Text = ("아이템 도감 · %d / %d"):format(discoveredCount, #items)
end

local function open()
	local ok, book = pcall(function() return remotes.RequestCollectionBook:InvokeServer() end)
	if not ok or type(book) ~= "table" then return end
	panel.Visible = true
	render(book)
end

opener.Event:Connect(open)
remotes.InventoryUpdated.OnClientEvent:Connect(function(snapshot)
	if panel.Visible and type(snapshot) == "table" and type(snapshot.CollectionBook) == "table" then render(snapshot.CollectionBook) end
end)
