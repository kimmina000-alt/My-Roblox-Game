local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local ItemCatalog = require(ReplicatedStorage.Shared.ItemCatalog)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CurrencyService = require(script.Parent.CurrencyService)
local PlotService = require(script.Parent.PlotService)
local RemoteService = require(script.Parent.RemoteService)

local SlimePadIncomeService = {}
local movement = {}
local fractionalGold = {}

local function relativePath(root, target)
	local names, node = {}, target
	while node and node ~= root do table.insert(names, 1, node.Name); node = node.Parent end
	return node == root and table.concat(names, "/") or nil
end

local function calculateGoldPerStep(data, padPath)
	local amount, hasBase = 0, false
	for _, record in ipairs(data.PlacedBases or {}) do
		if record.PadPath == padPath then
			hasBase = true
			amount += ItemCatalog.GetGoldPerStep(record.ItemId)
		end
	end
	for _, record in ipairs(data.PlacedToppings or {}) do
		if record.PadPath == padPath then
			amount += ItemCatalog.GetGoldPerStep(record.ItemId)
		end
	end
	if not hasBase then return 0 end
	return math.clamp(amount, 0, GameConfig.SlimePadIncome.MaximumGoldPerStep)
end

function SlimePadIncomeService.CalculateRate(data, padPath)
	-- Kept as CalculateRate for existing callers; the returned value is now gold per step.
	return calculateGoldPerStep(data, padPath)
end

local function getPlayerPad(player, data, plot)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.FloorMaterial == Enum.Material.Air then return nil end
	local zones = plot:FindFirstChild("SlimeZone")
	if not zones then return nil end
	for zoneName, unlocked in pairs(data.UnlockedZones or {}) do
		local zone = unlocked and zones:FindFirstChild(zoneName)
		if zone then
			for _, pad in ipairs(zone:GetDescendants()) do
				if pad:IsA("BasePart") and pad:GetAttribute("IsBasePad") == true
					and data.UnlockedPads[pad:GetAttribute("PadId")] == true then
					local localPos = pad.CFrame:PointToObjectSpace(root.Position)
					local path = relativePath(plot, pad)
					local hasBase = false
					for _, record in ipairs(data.PlacedBases or {}) do
						if record.PadPath == path then hasBase = true; break end
					end
					if hasBase and math.abs(localPos.X) <= pad.Size.X / 2 and math.abs(localPos.Z) <= pad.Size.Z / 2
						and localPos.Y >= pad.Size.Y / 2 and localPos.Y <= pad.Size.Y / 2 + GameConfig.SlimePadIncome.StandingHeight then
						return path, root, humanoid
					end
				end
			end
		end
	end
	return nil
end

local function countSteps(state, path, root, humanoid, elapsed)
	if state.Path ~= path then
		state.Path = path
		state.LastPosition = root.Position
		state.Progress = 0
		return 0
	end
	local delta = root.Position - (state.LastPosition or root.Position)
	state.LastPosition = root.Position
	local distance = Vector3.new(delta.X, 0, delta.Z).Magnitude
	distance = math.min(distance, math.max(0.5, humanoid.WalkSpeed * elapsed * 1.5))
	state.Progress = (state.Progress or 0) + distance
	local stepLength = GameConfig.SlimePadIncome.StudsPerStep
	local steps = math.floor(state.Progress / stepLength)
	state.Progress -= steps * stepLength
	return steps
end

function SlimePadIncomeService.Init()
	Players.PlayerRemoving:Connect(function(player)
		movement[player], fractionalGold[player] = nil, nil
	end)
	task.spawn(function()
		local lastTick = os.clock()
		while true do
			task.wait(GameConfig.SlimePadIncome.TickSeconds)
			local now = os.clock()
			local elapsed = math.min(now - lastTick, GameConfig.SlimePadIncome.TickSeconds * 3)
			lastTick = now
			for _, player in ipairs(Players:GetPlayers()) do
				local data, plot = PlayerDataService.Get(player), PlotService.GetPlot(player)
				if data and plot then
					local path, root, humanoid = getPlayerPad(player, data, plot)
					local state = movement[player] or { Progress = 0 }
					movement[player] = state
					if path and root and humanoid then
						local steps = countSteps(state, path, root, humanoid, elapsed)
						local amount = steps * calculateGoldPerStep(data, path)
						if amount > 0 then
							local balance = (fractionalGold[player] or 0) + amount
							local payout = math.floor(balance)
							fractionalGold[player] = balance - payout
							RemoteService.Get("PadIncomeFeedback"):FireClient(player, amount)
							if payout > 0 then CurrencyService.AddGold(player, payout) end
						end
					else
						state.Path, state.LastPosition, state.Progress = nil, nil, 0
					end
				else
					movement[player], fractionalGold[player] = nil, nil
				end
			end
		end
	end)
end

return SlimePadIncomeService
