local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlotService = require(script.Parent.PlotService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local InventoryService = require(script.Parent.InventoryService)
local RemoteService = require(script.Parent.RemoteService)
local ItemCatalog = require(ReplicatedStorage.Shared.ItemCatalog)

local DisplayShelfService = {}
local SLOT_COUNT = 10
local openUntil = {}
local boundPrompts = setmetatable({}, { __mode = "k" })
local boundClickDetectors = setmetatable({}, { __mode = "k" })

local function getShelf(plot)
	return plot and plot:FindFirstChild("DisplayShelf", true)
end

local function ensureSlots(data)
	data.DisplayShelf = type(data.DisplayShelf) == "table" and data.DisplayShelf or { Slots = {} }
	data.DisplayShelf.Slots = type(data.DisplayShelf.Slots) == "table" and data.DisplayShelf.Slots or {}
	for index = 1, SLOT_COUNT do
		if data.DisplayShelf.Slots[index] == false then data.DisplayShelf.Slots[index] = nil end
	end
	return data.DisplayShelf.Slots
end

-- Remote tables with nil holes can be serialized inconsistently. Send all ten
-- positions explicitly so slots 2-10 survive client/server round trips.
local function serializeSlots(slots)
	local result = table.create(SLOT_COUNT, false)
	for index = 1, SLOT_COUNT do result[index] = slots[index] or false end
	return result
end

local function render(player)
	local data = PlayerDataService.Get(player)
	local shelf = getShelf(PlotService.GetPlot(player))
	if not data or not shelf then return end
	local basePart = shelf:IsA("BasePart") and shelf or shelf:FindFirstChildWhichIsA("BasePart", true)
	if not basePart then return end
	local folder = shelf:FindFirstChild("DisplayedItems")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "DisplayedItems"
		folder.Parent = shelf
	end
	folder:ClearAllChildren()
	local slots = ensureSlots(data)
	for index = 1, SLOT_COUNT do
		local itemId = slots[index]
		local definition = itemId and ItemCatalog.Get(itemId)
		if definition then
			local part = Instance.new("Part")
			part.Name = "ShelfSlot_" .. index
			part.Shape = Enum.PartType.Ball
			part.Size = Vector3.new(0.9, 0.9, 0.9)
			part.Anchored = true
			part.CanCollide = false
			part.Color = definition.DisplayColor or (ItemCatalog.Rarities[definition.Rarity] and ItemCatalog.Rarities[definition.Rarity].Color) or Color3.fromRGB(245, 220, 255)
			part:SetAttribute("ItemId", itemId)
			part:SetAttribute("ShelfSlot", index)
			local column = (index - 1) % 5
			local row = math.floor((index - 1) / 5)
			local cellWidth = basePart.Size.X / 5
			local cellHeight = basePart.Size.Y / 2
			local x = -basePart.Size.X / 2 + cellWidth * (column + 0.5)
			local y = basePart.Size.Y / 2 - cellHeight * (row + 0.5)
			part.CFrame = basePart.CFrame * CFrame.new(x, y, -basePart.Size.Z / 2 - 0.5)
			part.Parent = folder
			local label = Instance.new("BillboardGui")
			label.Size = UDim2.fromOffset(100, 24)
			label.StudsOffset = Vector3.new(0, 0.7, 0)
			label.AlwaysOnTop = true
			label.Parent = part
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.Text = definition.DisplayName
			text.TextScaled = true
			text.TextColor3 = Color3.new(1, 1, 1)
			text.Parent = label
		end
	end
end

local function sendOpen(player, source)
	local data = PlayerDataService.Get(player)
	if not data then return end
	local slots = ensureSlots(data)
	openUntil[player] = os.clock() + 90
	print(("[DisplayShelf] Opened by %s via %s; sending GUI event"):format(player.Name, source or "unknown"))
	RemoteService.Get("OpenDisplayShelf"):FireClient(player, serializeSlots(slots), SLOT_COUNT)
end

local function bindPlayer(player)
	task.spawn(function()
		local deadline = os.clock() + 30
		local plot
		while player.Parent and os.clock() < deadline and not plot do
			plot = PlotService.GetPlot(player)
			if not plot then task.wait(0.2) end
		end
		if not plot then return end
		local data = PlayerDataService.WaitFor(player, 30)
		if not data then return end
		local shelf = getShelf(plot)
		local part = shelf and (shelf:IsA("BasePart") and shelf or shelf:FindFirstChildWhichIsA("BasePart", true))
		print(("[DisplayShelf] Bind check player=%s plot=%s shelf=%s part=%s"):format(
			player.Name,
			plot:GetFullName(),
			shelf and shelf:GetFullName() or "MISSING",
			part and part:GetFullName() or "MISSING"
		))
		if part then
			local prompt = part:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
			prompt.ActionText = "진열장 열기"
			prompt.ObjectText = "내 진열장"
			prompt.MaxActivationDistance = 8
			prompt.RequiresLineOfSight = false
			prompt.HoldDuration = 0
			prompt.Enabled = true
			prompt.Parent = part
			if not boundPrompts[prompt] then
				boundPrompts[prompt] = true
				prompt.Triggered:Connect(function(triggeringPlayer)
					print(("[DisplayShelf] SERVER: ProximityPrompt.Triggered player=%s prompt=%s plot=%s"):format(triggeringPlayer.Name, prompt:GetFullName(), plot.Name))
				end)
			end
			local clickDetector = part:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector")
			clickDetector.MaxActivationDistance = 8
			clickDetector.Parent = part
			if not boundClickDetectors[clickDetector] then
				boundClickDetectors[clickDetector] = true
				clickDetector.MouseClick:Connect(function(triggeringPlayer)
					if PlotService.GetPlot(triggeringPlayer) == plot and PlotService.IsNearPlotObject(triggeringPlayer, part, 8) then
						sendOpen(triggeringPlayer, "ClickDetector")
					end
				end)
			end
		end
		render(player)
	end)
end

function DisplayShelfService.Init()
	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(function(player) openUntil[player] = nil end)
	for _, player in ipairs(Players:GetPlayers()) do bindPlayer(player) end

	RemoteService.Get("DisplayShelfAction").OnServerInvoke = function(player, action, first, second)
		local data = PlayerDataService.Get(player)
		local plot = PlotService.GetPlot(player)
		local shelf = getShelf(plot)
		if not data or not shelf or not PlotService.IsNearPlotObject(player, shelf, 8) then
			return false, "진열장 가까이에서 다시 열어 주세요."
		end
		if action == "Open" then
			sendOpen(player, "DirectClickRemote")
			return true, "진열장을 열었습니다."
		end
		if (openUntil[player] or 0) < os.clock() then return false, "진열장을 다시 열어 주세요." end
		local slots = ensureSlots(data)
		local a, b = tonumber(first), tonumber(second)
		if action == "Deposit" then
			if not a or a % 1 ~= 0 or a < 1 or a > SLOT_COUNT then return false, "칸 번호가 올바르지 않습니다." end
			local itemId = data.HeldItemId
			local definition = type(itemId) == "string" and ItemCatalog.Get(itemId)
			if not definition or (definition.Storage ~= "Craft" and definition.Storage ~= "Gacha") then return false, "진열할 수 없는 아이템입니다." end
			if data.HeldItemId ~= itemId then return false, "가방에서 손에 든 아이템만 진열할 수 있습니다." end
			if not InventoryService.Has(player, itemId, 1) then return false, "아이템을 가지고 있지 않습니다." end
			if slots[a] then return false, "이미 아이템이 진열된 칸입니다. 먼저 회수해 주세요." end
			local removed = InventoryService.Remove(player, itemId, 1, definition.Storage)
			if not removed then return false, "아이템을 옮기지 못했습니다." end
			slots[a] = itemId
		elseif action == "Take" then
			if not a or a % 1 ~= 0 or a < 1 or a > SLOT_COUNT then return false, "칸 번호가 올바르지 않습니다." end
			local itemId = slots[a]
			if not itemId then return false, "빈 칸입니다." end
			local definition = ItemCatalog.Get(itemId)
			local added, reason = InventoryService.Add(player, itemId, 1, definition and definition.Storage or "Craft")
			if not added then return false, reason end
			InventoryService.SetHeldTopping(player, itemId)
			slots[a] = nil
		elseif action == "Swap" then
			if not a or not b or a % 1 ~= 0 or b % 1 ~= 0 or a < 1 or b < 1 or a > SLOT_COUNT or b > SLOT_COUNT then
				return false, "칸 번호가 올바르지 않습니다."
			end
			slots[a], slots[b] = slots[b], slots[a]
		else
			return false, "알 수 없는 요청입니다."
		end
		render(player)
		return true, "진열장을 업데이트했습니다.", serializeSlots(slots)
	end
end

return DisplayShelfService
