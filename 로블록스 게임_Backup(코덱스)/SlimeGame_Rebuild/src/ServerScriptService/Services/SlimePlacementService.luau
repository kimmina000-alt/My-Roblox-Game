local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemCatalog = require(ReplicatedStorage.Shared.ItemCatalog)
local PlayerDataService = require(script.Parent.PlayerDataService)
local InventoryService = require(script.Parent.InventoryService)
local PlotService = require(script.Parent.PlotService)
local RemoteService = require(script.Parent.RemoteService)

local SlimePlacementService = {}
local MAX_TOPPINGS_PER_PAD = 3

local function getPlacedFolder(plot)
	local folder = plot:FindFirstChild("PlacedToppings")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "PlacedToppings"
		folder.Parent = plot
	end
	return folder
end

local function getRelativePath(root, target)
	local names = {}
	local node = target
	while node and node ~= root do
		table.insert(names, 1, node.Name)
		node = node.Parent
	end
	if node ~= root then return nil end
	return table.concat(names, "/")
end

local function resolvePath(root, path)
	local node = root
	for segment in string.gmatch(path or "", "[^/]+") do
		node = node:FindFirstChild(segment)
		if not node then return nil end
	end
	return node
end

local function getPlayerRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function isPad(plot, object)
	return object and object:IsA("BasePart") and object:IsDescendantOf(plot)
		and object:GetAttribute("IsBasePad") == true
end

local function hasBaseOnPad(plot, data, pad)
	local padPath = getRelativePath(plot, pad)
	for _, record in ipairs(data.PlacedBases or {}) do
		if record.PadPath == padPath then return true end
	end
	return false
end

local function isZoneUnlocked(plot, pad, data)
	local padId = pad:GetAttribute("PadId")
	if padId and data.UnlockedPads[padId] ~= true then return false end
	local node = pad
	while node and node ~= plot do
		if node:IsA("Model") and node.Name:match("^Zone_%d+$") then
			return data.UnlockedZones[node.Name] == true
		end
		node = node.Parent
	end
	return false
end

local function render(player)
	local data = PlayerDataService.Get(player)
	local plot = PlotService.GetPlot(player)
	if not data or not plot then return end
	local folder = getPlacedFolder(plot)
	folder:ClearAllChildren()
	for _, saved in ipairs(data.PlacedToppings) do
		local pad = resolvePath(plot, saved.PadPath)
		local item = ItemCatalog.Get(saved.ItemId)
		if pad and pad:IsA("BasePart") and item then
			local offset = saved.Offset
			local part = Instance.new("Part")
			part.Name = "Placed_" .. saved.PlacementId
			part.Size = Vector3.new(0.8, 0.8, 0.8)
			part.Shape = Enum.PartType.Ball
			part.Anchored = true
			part.CanCollide = false
			local rarity = ItemCatalog.Rarities[item.Rarity]
			part.Color = item.DisplayColor or (rarity and rarity.Color) or Color3.fromRGB(245, 220, 255)
			part.Material = Enum.Material.SmoothPlastic
			-- Keep toppings above the translucent base so the pointer ray can hit them
			-- and players can click them to retrieve them.
			local visibleBaseTop = pad.Size.Y / 2 + 1.2 + part.Size.Y / 2 + 0.05
			part.Position = pad.CFrame:PointToWorldSpace(Vector3.new(offset.X, math.max(offset.Y, visibleBaseTop), offset.Z))
			part:SetAttribute("PlacementId", saved.PlacementId)
			part:SetAttribute("ItemId", saved.ItemId)
			part:SetAttribute("StepSoundKey", item.StepSoundKey or "DefaultToppingStep")
			part:SetAttribute("ToppingGravityScale", tonumber(saved.GravityScale) or 1)
			part.Parent = folder
		end
	end
end

local function place(player, itemId, pad, position)
	local plot = PlotService.GetPlot(player)
	local root = getPlayerRoot(player)
	local item = ItemCatalog.Get(itemId)
	local data = PlayerDataService.Get(player)
	if not plot or not root or not data or not item or item.Category ~= "Topping" or not isPad(plot, pad)
		or not isZoneUnlocked(plot, pad, data) or typeof(position) ~= "Vector3" then
		return false, "배치 위치 또는 아이템이 올바르지 않습니다."
	end
	if pad:GetAttribute("IsBasePad") == true and not hasBaseOnPad(plot, data, pad) then
		return false, "먼저 이 구역에 베이스를 놓아 주세요."
	end
	if (root.Position - position).Magnitude > 20 then return false, "너무 먼 위치입니다." end
	if data.HeldItemId ~= itemId then return false, "가방에서 선택해 손에 든 토핑만 배치할 수 있습니다." end
	local localPosition = pad.CFrame:PointToObjectSpace(position)
	local half = pad.Size / 2
	if math.abs(localPosition.X) > half.X + 0.5 or math.abs(localPosition.Z) > half.Z + 0.5
		or localPosition.Y < half.Y - 0.1 or localPosition.Y > half.Y + 3 then
		return false, "이 패드 안에 배치해 주세요."
	end
	local padPath = getRelativePath(plot, pad)
	if not padPath then return false, "패드 경로를 확인할 수 없습니다." end
	local toppingsOnPad = 0
	for _, placed in ipairs(data.PlacedToppings or {}) do
		if placed.PadPath == padPath then toppingsOnPad += 1 end
	end
	if toppingsOnPad >= MAX_TOPPINGS_PER_PAD then
		return false, "패드 하나에는 토핑을 최대 3개까지 놓을 수 있습니다."
	end
	if not InventoryService.Has(player, itemId, 1) then return false, "토핑을 가지고 있지 않습니다." end
	local gravityScale = 1
	for _, baseRecord in ipairs(data.PlacedBases or {}) do
		if baseRecord.PadPath == padPath then
			local baseDefinition = ItemCatalog.Get(baseRecord.ItemId)
			gravityScale = baseDefinition and baseDefinition.Buff and tonumber(baseDefinition.Buff.ToppingGravityScale) or 1
			break
		end
	end
	local removed = InventoryService.Remove(player, itemId, 1)
	if not removed then return false, "토핑을 옮기지 못했습니다." end
	table.insert(data.PlacedToppings, {
		PlacementId = HttpService:GenerateGUID(false),
		ItemId = itemId,
		PadPath = padPath,
		Offset = { X = localPosition.X, Y = localPosition.Y, Z = localPosition.Z },
		GravityScale = gravityScale,
		Protected = item.Storage == "Gacha" or item.Protected == true,
	})
	render(player)
	return true, "토핑을 배치했습니다."
end

local function retrieve(player, placementId)
	local plot = PlotService.GetPlot(player)
	local root = getPlayerRoot(player)
	local data = PlayerDataService.Get(player)
	if not plot or not root or type(placementId) ~= "string" or not data then return false, "요청이 올바르지 않습니다." end
	local folder = getPlacedFolder(plot)
	local part = folder:FindFirstChild("Placed_" .. placementId)
	if not part or (root.Position - part.Position).Magnitude > 12 then return false, "배치된 토핑 가까이에서 회수해 주세요." end
	local index, record
	for i, saved in ipairs(data.PlacedToppings) do
		if saved.PlacementId == placementId then index, record = i, saved; break end
	end
	if not index then return false, "토핑 기록을 찾을 수 없습니다." end
	local item = ItemCatalog.Get(record.ItemId)
	local storage = record.Protected and "Gacha" or (item and item.Storage == "DirtyBag" and "DirtyBag" or "Craft")
	local added, reason = InventoryService.Add(player, record.ItemId, 1, storage)
	if not added then return false, reason end
	table.remove(data.PlacedToppings, index)
	render(player)
	return true, "토핑을 회수했습니다."
end

function SlimePlacementService.Init()
	for _, object in ipairs(Workspace:GetDescendants()) do
		if object:IsA("ProximityPrompt") and object.Parent and object.Parent:IsA("BasePart")
			and (object.Parent:GetAttribute("IsToppingPad") == true or object.Parent:GetAttribute("PlacementId") ~= nil) then
			object:Destroy()
		end
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			if PlayerDataService.WaitFor(player, 30) then
				local deadline = os.clock() + 30
				while player.Parent and not PlotService.GetPlot(player) and os.clock() < deadline do task.wait(0.2) end
				render(player)
			end
		end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			if PlayerDataService.WaitFor(player, 30) then render(player) end
		end)
	end
	RemoteService.Get("PlaceTopping").OnServerInvoke = function(player, action, itemOrPlacementId, pad, position)
		if action == "Place" then return place(player, itemOrPlacementId, pad, position) end
		if action == "Retrieve" then return retrieve(player, itemOrPlacementId) end
		return false, "알 수 없는 요청입니다."
	end
end

function SlimePlacementService.Sync(player)
	render(player)
end

return SlimePlacementService
