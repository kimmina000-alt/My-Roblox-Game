local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PlayerDataService = require(script.Parent.PlayerDataService)

local PlotService = {}
local plotsFolder
local plotByPlayer = {}
local MAX_PLOTS = 15

local function offsetPlot(plot, offset)
	for _, object in ipairs(plot:GetDescendants()) do
		if object:IsA("BasePart") then object.CFrame += offset end
	end
end

local function getPlotFootprint(plot)
	local minX, maxX, minZ, maxZ
	for _, object in ipairs(plot:GetDescendants()) do
		if object:IsA("BasePart") then
			local p, half = object.Position, object.Size / 2
			minX = math.min(minX or p.X - half.X, p.X - half.X)
			maxX = math.max(maxX or p.X + half.X, p.X + half.X)
			minZ = math.min(minZ or p.Z - half.Z, p.Z - half.Z)
			maxZ = math.max(maxZ or p.Z + half.Z, p.Z + half.Z)
		end
	end
	return math.max(120, (maxX or 0) - (minX or 0) + 40), math.max(120, (maxZ or 0) - (minZ or 0) + 40)
end

local function ensurePlotSlots()
	plotsFolder = Workspace:FindFirstChild("HousingPlots")
	if not plotsFolder then
		warn("[PlotService] Workspace.HousingPlots is missing; player plots cannot be assigned.")
		return
	end
	local existing = plotsFolder:GetChildren()
	local template = existing[1]
	if not template then
		warn("[PlotService] Add one complete plot under Workspace.HousingPlots as the clone template.")
		return
	end
	local stepX, stepZ = getPlotFootprint(template)
	for index = #existing + 1, MAX_PLOTS do
		local clone = template:Clone()
		clone.Name = "PlayerHousing_" .. index
		clone:SetAttribute("OwnerUserId", nil)
		local column = (index - 1) % 5
		local row = math.floor((index - 1) / 5)
		offsetPlot(clone, Vector3.new(column * stepX, 0, row * stepZ))
		clone.Parent = plotsFolder
	end
end

local function assign(player)
	if not plotsFolder then return nil end
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			plotByPlayer[player] = plot
			return plot
		end
	end
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if plot:GetAttribute("OwnerUserId") == nil then
			plot:SetAttribute("OwnerUserId", player.UserId)
			plotByPlayer[player] = plot
			return plot
		end
	end
	return nil
end

function PlotService.GetPlot(player)
	local plot = plotByPlayer[player]
	if plot and plot.Parent then return plot end
	return assign(player)
end

function PlotService.IsNearPlotObject(player, target, maxDistance)
	local plot = PlotService.GetPlot(player)
	if not plot or not target or not target:IsDescendantOf(plot) then return false end
	local part = target:IsA("BasePart") and target or target:FindFirstChildWhichIsA("BasePart", true)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return part ~= nil and root ~= nil and (root.Position - part.Position).Magnitude <= (maxDistance or 12)
end

function PlotService.Init()
	ensurePlotSlots()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			if PlayerDataService.WaitFor(player, 30) then assign(player) end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local plot = plotByPlayer[player]
		if plot then
			local workerFolder = plot:FindFirstChild("Workers")
			if workerFolder then workerFolder:ClearAllChildren() end
			plot:SetAttribute("OwnerUserId", nil)
		end
		plotByPlayer[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			if PlayerDataService.WaitFor(player, 30) then assign(player) end
		end)
	end
end

return PlotService
