local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CurrencyService = require(script.Parent.CurrencyService)
local InventoryService = require(script.Parent.InventoryService)
local PlotService = require(script.Parent.PlotService)
local RemoteService = require(script.Parent.RemoteService)

local PumpService = {}
local boundPrompts = {}

local function getPump(player)
	local plot = PlotService.GetPlot(player)
	return plot and plot:FindFirstChild("BasePump", true)
end

local function renderLiquid(player)
	local data, pump = PlayerDataService.Get(player), getPump(player)
	local liquid = pump and pump:FindFirstChild("PumpLiquid", true)
	if not data or not pump or not pump:IsA("BasePart") or not liquid or not liquid:IsA("BasePart") then return end
	local maxHeight = 4.2
	local ratio = math.clamp(data.Pump.Current / math.max(data.Pump.Capacity, 1), 0, 1)
	pump:SetAttribute("PumpCurrent", data.Pump.Current)
	pump:SetAttribute("PumpCapacity", data.Pump.Capacity)
	pump:SetAttribute("PumpAutoRefillLevel", data.Pump.AutoRefillLevel)
	local height = math.max(0.04, maxHeight * ratio)
	liquid.Size = Vector3.new(3.8, height, 3.8)
	liquid.Position = Vector3.new(pump.Position.X, pump.Position.Y - pump.Size.Y / 2 + 0.4 + height / 2, pump.Position.Z)
	liquid.Transparency = ratio > 0.01 and 0.12 or 1
end

local function isNearPump(player, pump)
	local part = pump and (pump:IsA("BasePart") and pump or pump:FindFirstChildWhichIsA("BasePart", true))
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return part ~= nil and root ~= nil and pump:IsDescendantOf(PlotService.GetPlot(player))
		and (root.Position - part.Position).Magnitude <= 12
end

local function refillFractional(data, deltaTime)
	local refillRate = GameConfig.Pump.BaseRefillPerSecond
		+ data.Pump.AutoRefillLevel * GameConfig.Pump.AutoRefillPerSecond
	if refillRate > 0 then
		data.Pump.Current = math.min(data.Pump.Capacity, data.Pump.Current + refillRate * deltaTime)
	end
end

local function getNextCapacity(currentCapacity)
	for _, capacity in ipairs(GameConfig.Pump.CapacityTiers) do
		if capacity > currentCapacity then return capacity end
	end
	return nil
end

local function handlePumpAction(player, action)
	if action ~= "GetState" then
		print(("[Pump] Action received player=%s action=%s"):format(player.Name, tostring(action)))
	end
	local data = PlayerDataService.Get(player)
	local pump = getPump(player)
	if not data then
		warn(("[Pump] Rejected player=%s action=%s reason=data-not-ready"):format(player.Name, tostring(action)))
		return false, "플레이어 데이터를 불러오는 중입니다. 잠시 후 다시 눌러 주세요."
	end
	if not pump or not isNearPump(player, pump) then
		warn(("[Pump] Rejected player=%s action=%s reason=pump/distance"):format(player.Name, tostring(action)))
		return false, "개인 베이스 펌프 가까이에서 이용해 주세요."
	end

	if action == "Collect" then
		local requiredAmount = math.max(1, data.Pump.Capacity)
		if data.Pump.Current + 0.000001 < requiredAmount then
			return false, "펌프가 가득 차면 베이스 1개를 받을 수 있습니다."
		end
		local ok, reason = InventoryService.Add(player, "base_clear", 1, "Craft")
		if not ok then return false, reason end
		data.Pump.Current = math.max(0, data.Pump.Current - requiredAmount)
		renderLiquid(player)
		return true, "싹— 스쿱! 클리어 베이스 1개를 담았습니다.", data.Pump.Current
	elseif action == "UpgradeCapacity" then
		local nextCapacity = getNextCapacity(data.Pump.Capacity)
		if not nextCapacity then return false, "펌프 용량이 최대입니다." end
		local cost = GameConfig.Pump.CapacityUpgradeCosts[nextCapacity]
		if not cost or not CurrencyService.SpendGold(player, cost) then return false, "골드가 부족합니다." end
		data.Pump.Capacity = nextCapacity
		renderLiquid(player)
		return true, "펌프 용량을 업그레이드했습니다.", data.Pump.Capacity
	elseif action == "UpgradeAutoRefill" then
		local nextLevel = data.Pump.AutoRefillLevel + 1
		local cost = GameConfig.Pump.AutoRefillUpgradeCosts[nextLevel]
		if not cost then return false, "자동 충전기 업그레이드가 최대입니다." end
		if not CurrencyService.SpendGold(player, cost) then return false, "골드가 부족합니다." end
		data.Pump.AutoRefillLevel += 1
		return true, "자동 충전기를 업그레이드했습니다.", data.Pump.AutoRefillLevel
	elseif action == "GetState" then
		return true, table.clone(data.Pump)
	end
	return false, "알 수 없는 요청입니다."
end

local function bindPlayerPump(player)
	if boundPrompts[player] then return end
	task.spawn(function()
		local deadline = os.clock() + 30
		local pump
		while player.Parent and os.clock() < deadline do
			pump = getPump(player)
			if pump then break end
			task.wait(0.2)
		end
		if not player.Parent or not pump then return end
		local part = pump:IsA("BasePart") and pump or pump:FindFirstChildWhichIsA("BasePart", true)
		if not part then return end
		local prompt = part:FindFirstChildOfClass("ProximityPrompt")
		if not prompt then
			prompt = Instance.new("ProximityPrompt")
			prompt.Name = "BasePumpPrompt"
			prompt.ActionText = "베이스 퍼 담기"
			prompt.ObjectText = "베이스 펌프"
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.Parent = part
		end
		prompt.ActionText = "베이스 퍼 담기"
		prompt.ObjectText = "베이스 펌프"
		prompt.Enabled = false
		boundPrompts[player] = prompt
		renderLiquid(player)
	end)
end

function PumpService.Init()
	Players.PlayerAdded:Connect(bindPlayerPump)
	Players.PlayerRemoving:Connect(function(player) boundPrompts[player] = nil end)
	for _, player in ipairs(Players:GetPlayers()) do bindPlayerPump(player) end

	RemoteService.Get("PumpAction").OnServerInvoke = handlePumpAction

	task.spawn(function()
		local lastTick = os.clock()
		while true do
			task.wait(1)
			local now = os.clock()
			local deltaTime = now - lastTick
			lastTick = now
			for _, player in ipairs(Players:GetPlayers()) do
				local data = PlayerDataService.Get(player)
				if data then
					refillFractional(data, deltaTime)
					renderLiquid(player)
				end
			end
		end
	end)
end

return PumpService
