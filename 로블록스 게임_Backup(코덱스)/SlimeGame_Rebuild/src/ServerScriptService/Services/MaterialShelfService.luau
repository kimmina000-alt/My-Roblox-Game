local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemCatalog = require(ReplicatedStorage.Shared.ItemCatalog)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local InventoryService = require(script.Parent.InventoryService)
local RemoteService = require(script.Parent.RemoteService)

local MaterialShelfService = {}
local SHELVES = {
	BaseShelf = { Category = "Base", Label = "베이스" },
	DyeShelf = { Category = "Dye", Label = "염료" },
	FragranceShelf = { Category = "Fragrance", Label = "향료" },
	SurfaceEffectShelf = { Category = "SurfaceEffect", Label = "표면 효과" },
}
local SLOT_COUNT = 10
local activeShelf = {}
local activeUntil = {}
local bound = setmetatable({}, { __mode = "k" })

local function slotsFor(data, shelfKey)
	data.MaterialShelves = type(data.MaterialShelves) == "table" and data.MaterialShelves or {}
	local state = data.MaterialShelves[shelfKey]
	if type(state) ~= "table" then state = { Slots = {} }; data.MaterialShelves[shelfKey] = state end
	state.Slots = type(state.Slots) == "table" and state.Slots or {}
	return state.Slots
end

local function shelfPart(plot, key)
	local shelf = plot and plot:FindFirstChild(key, true)
	return shelf and (shelf:IsA("BasePart") and shelf or shelf:FindFirstChildWhichIsA("BasePart", true))
end

local function render(player, shelfKey)
	local plot, data = PlotService.GetPlot(player), PlayerDataService.Get(player)
	local part = shelfPart(plot, shelfKey)
	if not part or not data then return end
	local folder = part:FindFirstChild("DisplayedItems")
	if not folder then folder = Instance.new("Folder"); folder.Name = "DisplayedItems"; folder.Parent = part end
	folder:ClearAllChildren()
	local slots = slotsFor(data, shelfKey)
	for index = 1, SLOT_COUNT do
		local itemId = slots[index]
		local item = itemId and ItemCatalog.Get(itemId)
		if item then
			local display = Instance.new("Part")
			display.Name = "ShelfSlot_" .. index
			display.Shape = Enum.PartType.Ball
			display.Size = Vector3.new(0.8, 0.8, 0.8)
			display.Anchored, display.CanCollide = true, false
			display.Color = item.DisplayColor or Color3.fromRGB(230, 220, 245)
			display:SetAttribute("ItemId", itemId)
			local col, row = (index - 1) % 5, math.floor((index - 1) / 5)
			display.CFrame = part.CFrame * CFrame.new(-part.Size.X / 2 + (col + 0.5) * part.Size.X / 5,
				part.Size.Y / 2 - (row + 0.5) * part.Size.Y / 2, -part.Size.Z / 2 - 0.5)
			display.Parent = folder
		end
	end
end

local function open(player, key)
	local definition = SHELVES[key]
	local plot, data = PlotService.GetPlot(player), PlayerDataService.Get(player)
	local part = shelfPart(plot, key)
	if not definition or not part or not data or not PlotService.IsNearPlotObject(player, part, 8) then
		return false, "내 재료 진열장 가까이에서 열어 주세요."
	end
	activeShelf[player], activeUntil[player] = key, os.clock() + 90
	local payload = table.create(SLOT_COUNT, false)
	local slots = slotsFor(data, key)
	for i = 1, SLOT_COUNT do payload[i] = slots[i] or false end
	RemoteService.Get("OpenMaterialShelf"):FireClient(player, payload, SLOT_COUNT, key, definition.Category, definition.Label)
	return true
end

local function bindPlot(player, plot)
	for key, definition in pairs(SHELVES) do
		local part = shelfPart(plot, key)
		if part then
			local prompt = part:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
			prompt.ActionText, prompt.ObjectText = "재료 진열장 열기", definition.Label .. " 진열장"
			prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.HoldDuration = 8, false, 0
			prompt.Parent = part
			if not bound[prompt] then
				bound[prompt] = true
				prompt.Triggered:Connect(function(triggeringPlayer)
					if triggeringPlayer == player then open(player, key) end
				end)
			end
			render(player, key)
		end
	end
end

function MaterialShelfService.Init()
	local function setup(player)
		task.spawn(function()
			if not PlayerDataService.WaitFor(player, 30) then return end
			local deadline, plot = os.clock() + 30, nil
			while player.Parent and os.clock() < deadline and not plot do
				plot = PlotService.GetPlot(player)
				if not plot then task.wait(0.2) end
			end
			if plot then bindPlot(player, plot) end
		end)
	end
	Players.PlayerAdded:Connect(setup)
	Players.PlayerRemoving:Connect(function(player) activeShelf[player], activeUntil[player] = nil, nil end)
	for _, player in ipairs(Players:GetPlayers()) do setup(player) end

	RemoteService.Get("MaterialShelfAction").OnServerInvoke = function(player, action, first, second)
		if action == "Open" then return open(player, first) end
		local key = activeShelf[player]
		local definition = key and SHELVES[key]
		local plot, data = PlotService.GetPlot(player), PlayerDataService.Get(player)
		local part = shelfPart(plot, key)
		if not definition or not data or not part or (activeUntil[player] or 0) < os.clock()
			or not PlotService.IsNearPlotObject(player, part, 8) then return false, "재료 진열장 가까이에서 다시 열어 주세요." end
		local slots, index = slotsFor(data, key), tonumber(first)
		if not index or index % 1 ~= 0 or index < 1 or index > SLOT_COUNT then return false, "칸 번호가 잘못되었습니다." end
		if action == "Deposit" then
			local itemId = data.HeldItemId
			local item = itemId and ItemCatalog.Get(itemId)
			if not item or item.Category ~= definition.Category then return false, definition.Label .. "만 이 진열장에 놓을 수 있습니다." end
			if slots[index] then return false, "이미 사용 중인 칸입니다." end
			if not InventoryService.Has(player, itemId, 1) then return false, "선택한 재료를 가지고 있지 않습니다." end
			local ok, reason = InventoryService.Remove(player, itemId, 1, item.Storage)
			if not ok then return false, reason end
			slots[index] = itemId
		elseif action == "Take" then
			local itemId = slots[index]
			if not itemId then return false, "빈 칸입니다." end
			local item = ItemCatalog.Get(itemId)
			local ok, reason = InventoryService.Add(player, itemId, 1, item and item.Storage or "Craft")
			if not ok then return false, reason end
			InventoryService.SetHeldTopping(player, itemId)
			slots[index] = nil
		elseif action == "Swap" then
			local other = tonumber(second)
			if not other or other % 1 ~= 0 or other < 1 or other > SLOT_COUNT then return false, "칸 번호가 잘못되었습니다." end
			slots[index], slots[other] = slots[other], slots[index]
		else
			return false, "알 수 없는 진열장 요청입니다."
		end
		render(player, key)
		local payload = table.create(SLOT_COUNT, false)
		for i = 1, SLOT_COUNT do payload[i] = slots[i] or false end
		return true, "진열장을 업데이트했습니다.", payload
	end
end

return MaterialShelfService
