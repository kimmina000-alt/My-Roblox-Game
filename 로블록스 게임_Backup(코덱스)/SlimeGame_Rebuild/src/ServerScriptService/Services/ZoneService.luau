local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local CurrencyService = require(script.Parent.CurrencyService)
local RemoteService = require(script.Parent.RemoteService)

local ZoneService = {}
local COSTS = { Zone_2 = 500, Zone_3 = 5000 }
local PAD_COSTS = GameConfig.PadUnlockCosts

local function applyVisibility(player)
	local plot = PlotService.GetPlot(player)
	local data = PlayerDataService.Get(player)
	local zones = plot and plot:FindFirstChild("SlimeZone")
	if not zones or not data then return end
	for _, zone in ipairs(zones:GetChildren()) do
		local unlocked = data.UnlockedZones[zone.Name] == true
		zone:SetAttribute("Unlocked", unlocked)
		for _, object in ipairs(zone:GetDescendants()) do
			if object:IsA("BasePart") then
				local isGate = object.Name:match("^UnlockPad_") ~= nil
				local padUnlocked = object:GetAttribute("IsBasePad") ~= true
					or data.UnlockedPads[object:GetAttribute("PadId")] == true
				local gateVisible = isGate
				local unlocksPadId = object:GetAttribute("UnlockPadId")
				if unlocksPadId and data.UnlockedPads[unlocksPadId] then gateVisible = false end
				object.Transparency = (unlocked and padUnlocked or gateVisible) and 0 or 0.65
				object.CanCollide = (unlocked and padUnlocked) or gateVisible
				if object:GetAttribute("IsBasePad") == true then
					local workerPrompt = object:FindFirstChild("WorkerPlacePrompt")
					if workerPrompt and workerPrompt:IsA("ProximityPrompt") then
						workerPrompt.Enabled = unlocked and padUnlocked
					end
				end
				local ownUnlockPrompt = object:FindFirstChildOfClass("ProximityPrompt")
				if ownUnlockPrompt and object:GetAttribute("UnlockPadId") then
					ownUnlockPrompt.Enabled = gateVisible
				end
			end
		end
	end
end

local function unlock(player, zoneName)
	if type(zoneName) == "string" and PAD_COSTS[zoneName] then
		local data = PlayerDataService.WaitFor(player, 30)
		local plot = PlotService.GetPlot(player)
		if not data or not plot then return false, "개인 구역을 찾을 수 없습니다." end
		local targetPad
		for _, object in ipairs(plot:GetDescendants()) do
			if object:IsA("BasePart") and object:GetAttribute("IsBasePad") == true and object:GetAttribute("PadId") == zoneName then
				targetPad = object
				break
			end
		end
		if not targetPad then return false, "패드 월드 오브젝트를 찾을 수 없습니다." end
		local gate = plot:FindFirstChild("UnlockPad_" .. zoneName, true)
		if not gate or not PlotService.IsNearPlotObject(player, gate, 12) then return false, "패드 해금 표지판 가까이에서 눌러 주세요." end
		local node, zone = targetPad.Parent, nil
		while node and node ~= plot do
			if node:IsA("Model") and node.Name:match("^Zone_%d+$") then zone = node; break end
			node = node.Parent
		end
		if not zone or data.UnlockedZones[zone.Name] ~= true then return false, "먼저 이 패드가 있는 구역을 해금해 주세요." end
		if data.UnlockedPads[zoneName] then return true, "이미 해금된 패드입니다." end
		if not CurrencyService.SpendGold(player, PAD_COSTS[zoneName]) then return false, "골드가 부족합니다." end
		data.UnlockedPads[zoneName] = true
		applyVisibility(player)
		return true, zoneName .. " 패드를 해금했습니다."
	end
	if type(zoneName) ~= "string" or not COSTS[zoneName] then return false, "잘못된 구역입니다." end
	local data = PlayerDataService.WaitFor(player, 30)
	local plot = PlotService.GetPlot(player)
	if not data or not plot or not plot:FindFirstChild("SlimeZone") then return false, "개인 구역을 찾을 수 없습니다." end
	local gate = plot:FindFirstChild("UnlockPad_" .. zoneName, true)
	if not gate or not PlotService.IsNearPlotObject(player, gate, 12) then return false, "구역 해금 표지판 가까이에서 눌러 주세요." end
	if data.UnlockedZones[zoneName] then return true, "이미 열린 구역입니다." end
	if not CurrencyService.SpendGold(player, COSTS[zoneName]) then return false, "골드가 부족합니다." end
	data.UnlockedZones[zoneName] = true
	applyVisibility(player)
	return true, zoneName .. " 구역을 열었습니다."
end

local function bindPrompt(prompt)
	if not prompt.Parent or not prompt.Parent.Name:match("^UnlockPad_") then return end
	if prompt:GetAttribute("SlimeGameBound") then return end
	prompt:SetAttribute("SlimeGameBound", true)
	prompt.Triggered:Connect(function(player)
		local plot = PlotService.GetPlot(player)
		if not plot or not prompt:IsDescendantOf(plot) then return end
		if not PlotService.IsNearPlotObject(player, prompt.Parent, prompt.MaxActivationDistance + 2) then return end
		local unlockId = prompt.Parent:GetAttribute("UnlockPadId") or prompt.Parent.Name:gsub("^UnlockPad_", "")
		local ok, message = unlock(player, unlockId)
		RemoteService.Get("InventoryUpdated"):FireClient(player, { Message = message, Success = ok })
	end)
end

function ZoneService.Init()
	local function bind(player)
		task.spawn(function()
			if not PlayerDataService.WaitFor(player, 30) then return end
			applyVisibility(player)
		end)
	end
	game:GetService("Players").PlayerAdded:Connect(bind)
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do bind(player) end

	RemoteService.Get("ZoneAction").OnServerInvoke = function(player, zoneName)
		return unlock(player, zoneName)
	end

	Workspace.DescendantAdded:Connect(function(object)
		if object:IsA("ProximityPrompt") then bindPrompt(object) end
	end)
	for _, object in ipairs(Workspace:GetDescendants()) do
		if object:IsA("ProximityPrompt") then bindPrompt(object) end
	end
end

return ZoneService
