-- Creates a small playable placeholder map if the place has no map yet.
-- Replace this generated map with finished art when ready.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local WorldSetupService = {}

local function part(parent, name, size, position, color, anchored)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Anchored = anchored ~= false
	p.Color = color or Color3.fromRGB(110, 190, 160)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function ensureSharedStations()
	if not Workspace:FindFirstChild("ToppingMachine") then
		local machine = part(Workspace, "ToppingMachine", Vector3.new(6, 4, 5), Vector3.new(0, 2, -28), Color3.fromRGB(255, 170, 190))
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "슬라임 받기"
		prompt.ObjectText = "토핑 기계"
		prompt.Parent = machine
	end
	if not Workspace:FindFirstChild("CleaningTable") then
		local tablePart = part(Workspace, "CleaningTable", Vector3.new(8, 2, 5), Vector3.new(12, 1, -28), Color3.fromRGB(180, 220, 255))
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "토핑 닦기"
		prompt.ObjectText = "세척대"
		prompt.Parent = tablePart
	end
end

local function makePlot(folder)
	local plot = Instance.new("Model")
	plot.Name = "PlayerHousing_1"
	plot.Parent = folder
	part(plot, "PlotFloor", Vector3.new(70, 1, 70), Vector3.new(0, 0, 0), Color3.fromRGB(210, 235, 220))
	local zones = Instance.new("Folder")
	zones.Name = "SlimeZone"
	zones.Parent = plot
	for zoneIndex = 1, 3 do
		local zone = Instance.new("Model")
		zone.Name = "Zone_" .. zoneIndex
		zone.Parent = zones
		local x = (zoneIndex - 2) * 18
		local placementArea = part(zone, "FreePlacementArea", Vector3.new(16, 0.5, 9), Vector3.new(x, 0.8, 1), Color3.fromRGB(190, 230, 205))
		placementArea:SetAttribute("IsBasePad", true)
		placementArea:SetAttribute("PadId", "Pad_" .. ((zoneIndex - 1) * 2 + 1))
		local pads = Instance.new("Folder")
		pads.Name = "SlimePads"
		pads.Parent = zone
		placementArea.Parent = pads
		local secondPad = part(pads, "FreePlacementArea_2", Vector3.new(16, 0.5, 9), Vector3.new(x, 0.8, 11), Color3.fromRGB(190, 230, 205))
		secondPad:SetAttribute("IsBasePad", true)
		secondPad:SetAttribute("PadId", "Pad_" .. ((zoneIndex - 1) * 2 + 2))
		if zoneIndex > 1 then
			local gate = part(zone, "UnlockPad_Zone_" .. zoneIndex, Vector3.new(4, 1, 3), Vector3.new(x, 1.5, -7), Color3.fromRGB(255, 210, 120))
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "구역 열기"
			prompt.ObjectText = (zoneIndex == 2 and "500 골드" or "5,000 골드")
			prompt.Parent = gate
		end
	end
	local shelf = part(plot, "DisplayShelf", Vector3.new(12, 8, 1), Vector3.new(0, 4, 24), Color3.fromRGB(190, 150, 220))
	shelf:SetAttribute("ShelfKey", "DisplayShelf")
	local shelfPrompt = Instance.new("ProximityPrompt")
	shelfPrompt.ActionText = "진열장 열기"
	shelfPrompt.ObjectText = "슬라임 진열장"
	shelfPrompt.Parent = shelf
	local materialShelves = {
		{ "BaseShelf", "베이스 진열장", Color3.fromRGB(150, 215, 235), -20 },
		{ "DyeShelf", "염료 진열장", Color3.fromRGB(245, 155, 165), -7 },
		{ "FragranceShelf", "향료 진열장", Color3.fromRGB(245, 205, 130), 7 },
		{ "SurfaceEffectShelf", "글로시·글리터 진열장", Color3.fromRGB(180, 145, 235), 20 },
	}
	for _, definition in ipairs(materialShelves) do
		local key, displayName, color, x = table.unpack(definition)
		local materialShelf = part(plot, key, Vector3.new(10, 6, 1), Vector3.new(x, 3.5, 33), color)
		materialShelf:SetAttribute("ShelfKey", key)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "재료 진열장 열기"
		prompt.ObjectText = displayName
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = materialShelf
	end
	local pump = part(plot, "BasePump", Vector3.new(5, 5, 5), Vector3.new(-20, 2.5, 24), Color3.fromRGB(195, 235, 255))
	pump.Material = Enum.Material.Glass
	pump.Transparency = 0.68
	pump.CanCollide = false
	local pumpPrompt = Instance.new("ProximityPrompt")
	pumpPrompt.ActionText = "펌프 관리"
	pumpPrompt.ObjectText = "베이스 펌프"
	pumpPrompt.Parent = pump
	local liquid = part(pump, "PumpLiquid", Vector3.new(3.8, 4.2, 3.8), Vector3.new(-20, 2.5, 24), Color3.fromRGB(92, 205, 235))
	liquid.Transparency = 0.12
	liquid.CanCollide = false
	for tier = 1, 2 do
		local gacha = part(plot, "GachaMachine_" .. tier, Vector3.new(4, 4, 4), Vector3.new(-12 + tier * 8, 2, 24), Color3.fromRGB(255, 205, 120))
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "뽑기"
		prompt.ObjectText = "슬라임 캡슐"
		prompt.Parent = gacha
	end
	local kneadTable = part(plot, "SlimeKneadTable", Vector3.new(14, 2, 10), Vector3.new(0, 1.5, -20), Color3.fromRGB(230, 190, 210))
	local kneadPrompt = Instance.new("ProximityPrompt")
	kneadPrompt.ActionText, kneadPrompt.ObjectText = "쪼물 테이블 열기", "내 슬라임 만지기"
	kneadPrompt.MaxActivationDistance, kneadPrompt.RequiresLineOfSight = 10, false
	kneadPrompt.Parent = kneadTable
	return plot
end

-- Upgrade an existing three-zone template to two pads per zone (3 columns x 2 rows).
-- Keep the original pad instance/name so saved PadPath values remain valid.
local function ensureSixPadGrid(plot)
	local zones = plot:FindFirstChild("SlimeZone")
	if not zones then return end
	local zoneList = {}
	for i = 1, 3 do
		local zone = zones:FindFirstChild("Zone_" .. i)
		local pads = zone and zone:FindFirstChild("SlimePads")
		local firstPad = pads and pads:FindFirstChild("FreePlacementArea")
		if not (firstPad and firstPad:IsA("BasePart")) then return end
		table.insert(zoneList, { Zone = zone, Pads = pads, First = firstPad })
	end
	for _, entry in ipairs(zoneList) do
		local first = entry.First
		-- Old maps may have broad/overlapping pad parts still tagged as income pads.
		-- Only the two explicitly named, visible pads are gameplay pads after migration.
		for _, object in ipairs(entry.Pads:GetDescendants()) do
			if object:IsA("BasePart") then object:SetAttribute("IsBasePad", false) end
		end
		first:SetAttribute("IsBasePad", true)
		local zoneIndex = tonumber(entry.Zone.Name:match("_(%d+)$")) or 1
		local firstPadId = "Pad_" .. ((zoneIndex - 1) * 2 + 1)
		first:SetAttribute("PadId", firstPadId)
		first.Size = Vector3.new(math.min(first.Size.X, 16), first.Size.Y, 9)
		first.Position = Vector3.new(first.Position.X, first.Position.Y, 1)
		local second = entry.Pads:FindFirstChild("FreePlacementArea_2")
		if not second then
			second = part(entry.Pads, "FreePlacementArea_2", Vector3.new(16, first.Size.Y, 9),
				Vector3.new(first.Position.X, first.Position.Y, 11), first.Color)
		end
		second.Size = Vector3.new(math.min(first.Size.X, 16), first.Size.Y, 9)
		second.Position = Vector3.new(first.Position.X, first.Position.Y, 11)
		second:SetAttribute("IsBasePad", true)
		local secondPadId = "Pad_" .. ((zoneIndex - 1) * 2 + 2)
		second:SetAttribute("PadId", secondPadId)
		local padGateName = "UnlockPad_" .. secondPadId
		local padGate = entry.Zone:FindFirstChild(padGateName)
		if not padGate then
			padGate = part(entry.Zone, padGateName, Vector3.new(3, 1, 2),
				Vector3.new(first.Position.X, first.Position.Y + 0.5, 17), Color3.fromRGB(255, 185, 115))
		end
		padGate.Position = Vector3.new(first.Position.X, first.Position.Y + 0.5, 17)
		padGate:SetAttribute("UnlockPadId", secondPadId)
		local padPrompt = padGate:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
		local cost = GameConfig.PadUnlockCosts[secondPadId] or 0
		padPrompt.ActionText, padPrompt.ObjectText = "패드 해금", ("추가 슬라임 패드 · %d 골드"):format(cost)
		padPrompt.MaxActivationDistance, padPrompt.RequiresLineOfSight = 10, false
		padPrompt.Parent = padGate
		if entry.Zone.Name ~= "Zone_1" then
			local gateName = "UnlockPad_" .. entry.Zone.Name
			local gate = entry.Zone:FindFirstChild(gateName)
			if not gate then
				gate = part(entry.Zone, gateName, Vector3.new(4, 1, 3), Vector3.new(first.Position.X, 1.5, -7), Color3.fromRGB(255, 210, 120))
			end
			local prompt = gate:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
			prompt.ActionText = "구역 열기"
			prompt.ObjectText = entry.Zone.Name == "Zone_2" and "500 골드" or "5,000 골드"
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.Parent = gate
		end
	end
	local materials = {
		{ "BaseShelf", "베이스 진열장", Color3.fromRGB(150, 215, 235), -20 },
		{ "DyeShelf", "염료 진열장", Color3.fromRGB(245, 155, 165), -7 },
		{ "FragranceShelf", "향료 진열장", Color3.fromRGB(245, 205, 130), 7 },
		{ "SurfaceEffectShelf", "글로시·글리터 진열장", Color3.fromRGB(180, 145, 235), 20 },
	}
	for _, spec in ipairs(materials) do
		local key, label, color, x = table.unpack(spec)
		local shelf = plot:FindFirstChild(key)
		if not shelf then shelf = part(plot, key, Vector3.new(10, 6, 1), Vector3.new(x, 3.5, 33), color) end
		shelf:SetAttribute("ShelfKey", key)
		local prompt = shelf:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
		prompt.ActionText, prompt.ObjectText = "재료 진열장 열기", label
		prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 8, false
		prompt.Parent = shelf
	end
	local kneadTable = plot:FindFirstChild("SlimeKneadTable")
	if not kneadTable then kneadTable = part(plot, "SlimeKneadTable", Vector3.new(14, 2, 10), Vector3.new(0, 1.5, -20), Color3.fromRGB(230, 190, 210)) end
	local kneadPrompt = kneadTable:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
	kneadPrompt.ActionText, kneadPrompt.ObjectText = "쪼물 테이블 열기", "내 슬라임 만지기"
	kneadPrompt.MaxActivationDistance, kneadPrompt.RequiresLineOfSight = 10, false
	kneadPrompt.Parent = kneadTable
end

function WorldSetupService.Init()
	ensureSharedStations()
	local plots = Workspace:FindFirstChild("HousingPlots")
	if not plots then
		plots = Instance.new("Folder")
		plots.Name = "HousingPlots"
		plots.Parent = Workspace
	end
	if #plots:GetChildren() == 0 then
		makePlot(plots)
	end
	for _, plot in ipairs(plots:GetChildren()) do
		if plot:IsA("Model") then ensureSixPadGrid(plot) end
	end
end

return WorldSetupService
