local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local ItemCatalog = require(ReplicatedStorage.Shared.ItemCatalog)
local PlayerDataService = require(script.Parent.PlayerDataService)
local InventoryService = require(script.Parent.InventoryService)
local PlotService = require(script.Parent.PlotService)
local SlimePlacementService = require(script.Parent.SlimePlacementService)
local WorkerService = require(script.Parent.WorkerService)
local RemoteService = require(script.Parent.RemoteService)

local BasePlacementService = {}
local boundBaseSigns = setmetatable({}, { __mode = "k" })

local function getFolder(plot)
	local folder = plot:FindFirstChild("PlacedBases")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "PlacedBases"
		folder.Parent = plot
	end
	return folder
end

local function relativePath(root, target)
	local names, node = {}, target
	while node and node ~= root do table.insert(names, 1, node.Name); node = node.Parent end
	return node == root and table.concat(names, "/") or nil
end

local function resolvePath(root, path)
	local node = root
	for segment in string.gmatch(path or "", "[^/]+") do
		node = node:FindFirstChild(segment)
		if not node then return nil end
	end
	return node
end

local function inUnlockedZone(plot, pad, data)
	local padId = pad:GetAttribute("PadId")
	if padId and data.UnlockedPads[padId] ~= true then return false end
	local node = pad
	while node and node ~= plot do
		if node:IsA("Model") and node.Name:match("^Zone_%d+$") then return data.UnlockedZones[node.Name] == true end
		node = node.Parent
	end
	return false
end

-- Sign geometry is replaceable; PadPath and the prompt are its stable interface.
local function ensureBaseSign(plot, pad)
	local sign = pad:FindFirstChild("BaseControlSign")
	if not sign then
		sign = Instance.new("Model")
		sign.Name = "BaseControlSign"
		sign.Parent = pad
	end
	sign:SetAttribute("PadPath", relativePath(plot, pad))
	local board = sign:FindFirstChild("Board")
	if not board then
		local post = Instance.new("Part")
		post.Name = "Post"
		post.Size = Vector3.new(0.25, 1.8, 0.25)
		post.Anchored, post.CanCollide, post.CanTouch, post.CanQuery = true, false, false, false
		post.Color = Color3.fromRGB(143, 111, 91)
		post.Parent = sign
		board = Instance.new("Part")
		board.Name = "Board"
		board.Size = Vector3.new(3.4, 1.2, 0.18)
		board.Anchored, board.CanCollide, board.CanTouch = true, false, false
		board.Color = Color3.fromRGB(247, 224, 188)
		board.Parent = sign
		local gui = Instance.new("SurfaceGui")
		gui.Name = "SignFace"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "베이스 회수"
		label.TextColor3 = Color3.fromRGB(78, 55, 39)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Parent = gui
	end
	local post = sign:FindFirstChild("Post")
	local frontOffset = pad.Size.Z / 2 + 1.2
	if post then post.CFrame = pad.CFrame * CFrame.new(0, 1.0, -frontOffset) end
	board.CFrame = pad.CFrame * CFrame.new(0, 2.0, -frontOffset)
	local oldPrompt = board:FindFirstChildOfClass("ProximityPrompt")
	if oldPrompt then oldPrompt:Destroy() end
	local detector = board:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector")
	detector.Name = "BaseRetrieveClick"
	detector.MaxActivationDistance = 8
	detector.Parent = board
	if not boundBaseSigns[detector] then
		boundBaseSigns[detector] = true
		detector.MouseClick:Connect(function(player)
			local data = PlayerDataService.Get(player)
			if not data or PlotService.GetPlot(player) ~= plot or not PlotService.IsNearPlotObject(player, board, 8) then return end
			local path = sign:GetAttribute("PadPath")
			for _, record in ipairs(data.PlacedBases or {}) do
				if record.PadPath == path then
					local toppingCount = 0
					for _, topping in ipairs(data.PlacedToppings or {}) do
						if topping.PadPath == path then toppingCount += 1 end
					end
					local workerCount = 0
					for _, worker in ipairs(data.Workers and data.Workers.Placed or {}) do
						if worker.PadPath == path then workerCount += 1 end
					end
					RemoteService.Get("RequestBaseRetrieve"):FireClient(player, record.PlacementId, toppingCount, workerCount)
					return
				end
			end
		end)
	end
end

local function ensurePlotSigns(plot)
	local zones = plot and plot:FindFirstChild("SlimeZone")
	if not zones then return end
	for _, pad in ipairs(zones:GetDescendants()) do
		if pad:IsA("BasePart") and pad:GetAttribute("IsBasePad") == true then ensureBaseSign(plot, pad) end
	end
end

local function render(player)
	local data, plot = PlayerDataService.Get(player), PlotService.GetPlot(player)
	if not data or not plot then return end
	ensurePlotSigns(plot)
	local activePads = {}
	for _, record in ipairs(data.PlacedBases or {}) do activePads[record.PadPath] = true end
	local zones = plot:FindFirstChild("SlimeZone")
	if zones then
		for _, pad in ipairs(zones:GetDescendants()) do
			if pad:IsA("BasePart") and pad:GetAttribute("IsBasePad") == true then
				local path = relativePath(plot, pad)
				pad:SetAttribute("HasPlacedBase", activePads[path] == true)
				local sign = pad:FindFirstChild("BaseControlSign")
				local board = sign and sign:FindFirstChild("Board")
				local signText = board and board:FindFirstChild("SignFace") and board.SignFace:FindFirstChild("Label")
				if signText then signText.Text = activePads[path] and "베이스 회수" or "빈 패드" end
			end
		end
	end
	local folder = getFolder(plot)
	folder:ClearAllChildren()
	for _, record in ipairs(data.PlacedBases) do
		local pad, item = resolvePath(plot, record.PadPath), ItemCatalog.Get(record.ItemId)
		if pad and pad:IsA("BasePart") and item then
			-- Placeholder uses the pad footprint. Replace this renderer with the final slime model later.
			local model = Instance.new("Part")
			model.Name = "PlacedBase_" .. record.PlacementId
			model.Size = Vector3.new(math.max(1, pad.Size.X - 0.5), 1.2, math.max(1, pad.Size.Z - 0.5))
			model.Anchored, model.CanCollide, model.Material = true, true, Enum.Material.Glass
			model.Color = item.DisplayColor or Color3.fromRGB(170, 235, 245)
			model.Transparency = 0.48
			model.Position = pad.Position + pad.CFrame.UpVector * (pad.Size.Y / 2 + model.Size.Y / 2)
			model:SetAttribute("PlacementId", record.PlacementId)
			model:SetAttribute("PlacementKind", "Base")
			model:SetAttribute("ItemId", record.ItemId)
			model:SetAttribute("PadPath", record.PadPath)
			model:SetAttribute("ToppingGravityScale", (item.Buff and item.Buff.ToppingGravityScale) or 1)
			model:SetAttribute("StepSoundKey", item.StepSoundKey or "DefaultSquish")
			model.Parent = folder
			local normalSize, normalCFrame = model.Size, model.CFrame
			local squishing = false
			model.Touched:Connect(function(hit)
				local character = hit and hit.Parent
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if not humanoid or squishing or hit.Position.Y > model.Position.Y + model.Size.Y / 2 + 0.6 then return end
				squishing = true
				local pressedSize = Vector3.new(normalSize.X, normalSize.Y * 0.72, normalSize.Z)
				local pressedCFrame = normalCFrame - normalCFrame.UpVector * ((normalSize.Y - pressedSize.Y) / 2)
				TweenService:Create(model, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = pressedSize,
					CFrame = pressedCFrame,
				}):Play()
				task.delay(0.16, function()
					if model.Parent then
						TweenService:Create(model, TweenInfo.new(0.32, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
							Size = normalSize,
							CFrame = normalCFrame,
						}):Play()
					end
					task.delay(0.38, function() squishing = false end)
				end)
			end)
		end
	end
end

local function operate(player, action, itemIdOrPlacementId, pad, confirmed)
	local data, plot = PlayerDataService.Get(player), PlotService.GetPlot(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not data or not plot or not root then return false, "플레이어 데이터를 불러오는 중입니다." end
	if action == "Place" then
		local item = ItemCatalog.Get(itemIdOrPlacementId)
		if not item or item.Category ~= "Base" or not pad or not pad:IsA("BasePart")
			or not pad:IsDescendantOf(plot) or (pad.Name ~= "BasePad" and pad:GetAttribute("IsBasePad") ~= true)
			or not inUnlockedZone(plot, pad, data) or (root.Position - pad.Position).Magnitude > 22 then
			return false, "개인 구역의 열린 베이스 패드를 클릭해 주세요."
		end
		if data.HeldItemId ~= itemIdOrPlacementId then return false, "바구니에서 베이스를 선택해야 놓을 수 있어요." end
		if not InventoryService.Has(player, itemIdOrPlacementId, 1) then return false, "선택한 베이스가 바구니에 없습니다." end
		for _, record in ipairs(data.PlacedBases) do if record.PadPath == relativePath(plot, pad) then return false, "패드 하나에는 베이스 하나만 놓을 수 있어요." end end
		local path = relativePath(plot, pad)
		if not path then return false, "패드 경로를 확인할 수 없습니다." end
		local removed, reason = InventoryService.Remove(player, itemIdOrPlacementId, 1, "Craft")
		if not removed then return false, reason end
		local placementId = HttpService:GenerateGUID(false)
		table.insert(data.PlacedBases, { PlacementId = placementId, ItemId = itemIdOrPlacementId, PadPath = path })
		render(player)
		return true, "베이스를 패드에 놓았습니다."
	elseif action == "Retrieve" then
		for index, record in ipairs(data.PlacedBases) do
			if record.PlacementId == itemIdOrPlacementId then
				local pad = resolvePath(plot, record.PadPath)
				local sign = pad and pad:FindFirstChild("BaseControlSign")
				local board = sign and sign:FindFirstChild("Board")
				if not board or not PlotService.IsNearPlotObject(player, board, 8) then
					return false, "패드 앞 회수 표지판 가까이에서 눌러 주세요."
				end
				local toppings = {}
				for toppingIndex, topping in ipairs(data.PlacedToppings) do
					if topping.PadPath == record.PadPath then table.insert(toppings, { Index = toppingIndex, Record = topping }) end
				end
				local pendingCraft, pendingGacha = {}, 0
				local allReturns = { record.ItemId }
				for _, topping in ipairs(toppings) do table.insert(allReturns, topping.Record.ItemId) end
				for _, returnItemId in ipairs(allReturns) do
					local item = ItemCatalog.Get(returnItemId)
					if not item then return false, "회수할 아이템 정보를 찾을 수 없습니다." end
					if item.Storage == "Gacha" then pendingGacha += 1
					else pendingCraft[returnItemId] = (pendingCraft[returnItemId] or 0) + 1 end
				end
			for returnItemId, amount in pairs(pendingCraft) do
				if (data.Inventory.CraftBasket[returnItemId] or 0) + amount > GameConfig.MaxCraftStack then
					return false, "가방에 빈 공간이 부족해 베이스와 토핑을 회수할 수 없습니다."
				end
			end
			if #data.Inventory.GachaCabinet + pendingGacha > GameConfig.GachaCabinetCapacity then
				return false, "가챠 보관함에 빈 공간이 부족합니다."
			end
			for _, topping in ipairs(toppings) do
				local item = ItemCatalog.Get(topping.Record.ItemId)
				local added, reason = InventoryService.Add(player, topping.Record.ItemId, 1, item.Storage)
				if not added then return false, reason end
			end
			local baseAdded, baseReason = InventoryService.Add(player, record.ItemId, 1, "Craft")
			if not baseAdded then return false, baseReason end
			for toppingIndex = #toppings, 1, -1 do table.remove(data.PlacedToppings, toppings[toppingIndex].Index) end
			local returnedWorkers = 0
			for workerIndex = #(data.Workers and data.Workers.Placed or {}), 1, -1 do
				local workerRecord = data.Workers.Placed[workerIndex]
				if workerRecord.PadPath == record.PadPath then
					table.remove(data.Workers.Placed, workerIndex)
					returnedWorkers += 1
				end
			end
			if data.Workers and returnedWorkers > 0 then
				data.Workers.BagCount = (tonumber(data.Workers.BagCount) or 0) + returnedWorkers
			end
				table.remove(data.PlacedBases, index)
				InventoryService.SetHeldTopping(player, record.ItemId)
				SlimePlacementService.Sync(player)
				render(player)
				if returnedWorkers > 0 then WorkerService.Sync(player) end
				if returnedWorkers > 0 then
					return true, ("베이스와 토핑 %d개를 회수했고, 노동자 %d명도 인벤토리로 돌아왔습니다.")
						:format(#toppings, returnedWorkers)
				end
				return true, ("베이스와 토핑 %d개를 모두 가방으로 회수했습니다."):format(#toppings)
			end
		end
	end
	return false, "알 수 없는 요청입니다."
end

function BasePlacementService.Init()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			if PlayerDataService.WaitFor(player, 30) then
				local deadline = os.clock() + 30
				while player.Parent and not PlotService.GetPlot(player) and os.clock() < deadline do task.wait(0.2) end
				ensurePlotSigns(PlotService.GetPlot(player))
				render(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			if PlayerDataService.WaitFor(player, 30) then
				local deadline = os.clock() + 30
				while player.Parent and not PlotService.GetPlot(player) and os.clock() < deadline do task.wait(0.2) end
				ensurePlotSigns(PlotService.GetPlot(player))
				render(player)
			end
		end)
	end)
	RemoteService.Get("PlaceBase").OnServerInvoke = operate
	local plots = Workspace:FindFirstChild("HousingPlots")
	if plots then for _, plot in ipairs(plots:GetChildren()) do ensurePlotSigns(plot) end end
end

function BasePlacementService.Sync(player)
	render(player)
end

return BasePlacementService
