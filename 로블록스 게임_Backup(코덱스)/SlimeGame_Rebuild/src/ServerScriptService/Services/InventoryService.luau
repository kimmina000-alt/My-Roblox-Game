local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local ItemCatalog = require(ReplicatedStorage.Shared.ItemCatalog)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RemoteService = require(script.Parent.RemoteService)

local InventoryService = {}

local function hasOwnedItem(data, itemId)
	if data.Inventory.DirtyBag == itemId or (data.Inventory.CraftBasket[itemId] or 0) > 0 then return true end
	return table.find(data.Inventory.GachaCabinet, itemId) ~= nil
end

local function syncHeldVisual(player)
	local data = PlayerDataService.Get(player)
	if not data then return end
	local desiredItemId = data.HeldItemId
	if desiredItemId and not hasOwnedItem(data, desiredItemId) then
		data.HeldItemId = nil
		desiredItemId = nil
	end
	if not desiredItemId then desiredItemId = data.Inventory.DirtyBag end

	-- Keep one Roblox Tool per item type, with duplicate items represented as a
	-- stack count. Only the selected item is equipped; the rest remain in Backpack.
	local counts = {}
	if data.Inventory.DirtyBag then counts[data.Inventory.DirtyBag] = 1 end
	for itemId, amount in pairs(data.Inventory.CraftBasket) do
		if amount > 0 then counts[itemId] = (counts[itemId] or 0) + amount end
	end
	for _, itemId in ipairs(data.Inventory.GachaCabinet) do
		counts[itemId] = (counts[itemId] or 0) + 1
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	local containers = {}
	if backpack then table.insert(containers, backpack) end
	if character then table.insert(containers, character) end
	local toolsByItem = {}
	for _, container in ipairs(containers) do
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("SlimeGameVisualItem") == true then
				local itemId = child:GetAttribute("ItemId")
				if counts[itemId] and not toolsByItem[itemId] then
					toolsByItem[itemId] = child
				else
					child:Destroy()
				end
			end
		end
	end

	for itemId, count in pairs(counts) do
		local definition = ItemCatalog.Get(itemId)
		if definition then
			local tool = toolsByItem[itemId]
			if not tool then
				tool = Instance.new("Tool")
				tool.RequiresHandle = true
				tool.CanBeDropped = false
				tool:SetAttribute("SlimeGameVisualItem", true)
				tool:SetAttribute("ItemId", itemId)
				local handle = Instance.new("Part")
				handle.Name = "Handle"
				handle.Shape = Enum.PartType.Ball
				handle.Size = Vector3.new(1, 1, 1)
				handle.Material = Enum.Material.SmoothPlastic
				local rarity = ItemCatalog.Rarities[definition.Rarity]
				handle.Color = itemId == "topping_dirty" and Color3.fromRGB(130, 112, 91)
					or (rarity and rarity.Color or definition.DisplayColor or Color3.fromRGB(245, 220, 255))
				handle.CanCollide = false
				handle.CanQuery = false
				handle.Massless = true
				handle.Parent = tool
				tool.Grip = CFrame.new(0, -0.3, -0.8)
				tool.Equipped:Connect(function()
					local currentData = PlayerDataService.Get(player)
					if currentData and hasOwnedItem(currentData, itemId) then
						currentData.HeldItemId = itemId
						RemoteService.Get("InventoryUpdated"):FireClient(player, InventoryService.GetSnapshot(player))
					end
				end)
			end
			tool.Name = definition.DisplayName .. (count > 1 and (" ×" .. count) or "")
			tool:SetAttribute("StackCount", count)
			if itemId == desiredItemId and character then
				if tool.Parent ~= character then
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					if backpack and humanoid then
						tool.Parent = backpack
						task.defer(function() if tool.Parent == backpack then humanoid:EquipTool(tool) end end)
					else
						tool.Parent = character
					end
				end
			elseif backpack and tool.Parent ~= backpack then
				tool.Parent = backpack
			end
		end
	end
end

local function publish(player)
	RemoteService.Get("InventoryUpdated"):FireClient(player, InventoryService.GetSnapshot(player))
end

function InventoryService.GetSnapshot(player)
	local data = PlayerDataService.Get(player)
	if not data then return nil end
	return {
		DirtyBag = data.Inventory.DirtyBag,
		CraftBasket = table.clone(data.Inventory.CraftBasket),
		GachaCabinet = table.clone(data.Inventory.GachaCabinet),
		HeldItemId = data.HeldItemId or data.Inventory.DirtyBag,
		WorkerBagCount = data.Workers and data.Workers.BagCount or 0,
		WorkerPlacementSelected = data.Workers and data.Workers.SelectedForPlacement == true or false,
		CollectionBook = table.clone(data.CollectionBook),
	}
end

function InventoryService.Count(player, itemId, storage)
	local data = PlayerDataService.Get(player)
	if not data then return 0 end
	local count = 0
	if (not storage or storage == "DirtyBag") and data.Inventory.DirtyBag == itemId then count += 1 end
	if not storage or storage == "Craft" then count += data.Inventory.CraftBasket[itemId] or 0 end
	if not storage or storage == "Gacha" then
		for _, ownedId in ipairs(data.Inventory.GachaCabinet) do
			if ownedId == itemId then count += 1 end
		end
	end
	return count
end

function InventoryService.Has(player, itemId, amount)
	return InventoryService.Count(player, itemId) >= (amount or 1)
end

function InventoryService.SyncVisuals(player)
	syncHeldVisual(player)
end

function InventoryService.SetHeldTopping(player, itemId)
	local data = PlayerDataService.Get(player)
	local definition = type(itemId) == "string" and ItemCatalog.Get(itemId)
	local isSelectable = definition and (definition.Storage == "Craft" or definition.Category == "Topping"
		or (definition.Category == "DirtyTopping" and data and data.Inventory.DirtyBag == itemId))
	if not data or not isSelectable or not hasOwnedItem(data, itemId) then
		return false, "바구니에 보유한 재료만 선택할 수 있어요."
	end
	data.HeldItemId = itemId
	syncHeldVisual(player)
	publish(player)
	return true, definition.DisplayName
end

function InventoryService.Add(player, itemId, amount, storageOverride)
	amount = math.floor(tonumber(amount) or 1)
	if amount < 1 or amount > GameConfig.MaxCraftStack then return false, "수량이 올바르지 않습니다." end
	local definition = ItemCatalog.Get(itemId)
	local data = PlayerDataService.Get(player)
	if not definition or not data then return false, "아이템을 찾을 수 없습니다." end
	local storage = storageOverride or definition.Storage

	if storage == "DirtyBag" then
		if amount ~= 1 or data.Inventory.DirtyBag then return false, "더러운 토핑 가방이 이미 가득 찼습니다." end
		data.Inventory.DirtyBag = itemId
		data.HeldItemId = itemId
	elseif storage == "Gacha" then
		if #data.Inventory.GachaCabinet + amount > GameConfig.GachaCabinetCapacity then
			return false, "가챠 보관함이 가득 찼습니다."
		end
		for _ = 1, amount do table.insert(data.Inventory.GachaCabinet, itemId) end
	elseif storage == "Craft" then
		local current = data.Inventory.CraftBasket[itemId] or 0
		if current + amount > GameConfig.MaxCraftStack then return false, "아이템 보유 한도를 넘었습니다." end
		data.Inventory.CraftBasket[itemId] = current + amount
	else
		return false, "아이템 보관 위치가 올바르지 않습니다."
	end

	data.CollectionBook[itemId] = true
	if storage == "Craft" and not data.HeldItemId then data.HeldItemId = itemId end
	syncHeldVisual(player)
	publish(player)
	return true
end

function InventoryService.Remove(player, itemId, amount, storage)
	amount = math.floor(tonumber(amount) or 1)
	if amount < 1 then return false, "수량이 올바르지 않습니다." end
	local data = PlayerDataService.Get(player)
	if not data then return false, "플레이어 데이터를 불러오는 중입니다." end

	local available = InventoryService.Count(player, itemId, storage)
	if available < amount then return false, "아이템이 부족합니다." end
	local remaining = amount
	if (not storage or storage == "DirtyBag") and data.Inventory.DirtyBag == itemId and remaining > 0 then
		data.Inventory.DirtyBag = nil
		remaining -= 1
	end
	if (not storage or storage == "Craft") and remaining > 0 then
		local current = data.Inventory.CraftBasket[itemId] or 0
		local removed = math.min(current, remaining)
		local left = current - removed
		data.Inventory.CraftBasket[itemId] = left > 0 and left or nil
		remaining -= removed
	end
	if (not storage or storage == "Gacha") and remaining > 0 then
		for index = #data.Inventory.GachaCabinet, 1, -1 do
			if data.Inventory.GachaCabinet[index] == itemId then
				table.remove(data.Inventory.GachaCabinet, index)
				remaining -= 1
				if remaining == 0 then break end
			end
		end
	end
	if data.HeldItemId and not hasOwnedItem(data, data.HeldItemId) then data.HeldItemId = nil end
	syncHeldVisual(player)
	publish(player)
	return true
end

function InventoryService.Init()
	local function bindPlayer(player)
		player.CharacterAdded:Connect(function()
			task.spawn(function()
			if PlayerDataService.WaitFor(player, 30) then
					task.wait(0.2)
					syncHeldVisual(player)
				end
			end)
		end)
		if player.Character then
			task.spawn(function()
				if PlayerDataService.WaitFor(player, 30) then syncHeldVisual(player) end
			end)
		end
	end
	Players.PlayerAdded:Connect(bindPlayer)
	for _, player in ipairs(Players:GetPlayers()) do bindPlayer(player) end

	RemoteService.Get("RequestInventory").OnServerInvoke = function(player)
		local data = PlayerDataService.WaitFor(player, 30)
		if not data then return nil, "데이터를 불러오지 못했습니다." end
		return InventoryService.GetSnapshot(player)
	end
	RemoteService.Get("SetHeldTopping").OnServerInvoke = function(player, itemId)
		return InventoryService.SetHeldTopping(player, itemId)
	end
end

return InventoryService
