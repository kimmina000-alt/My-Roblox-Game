local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SlimeGameRemotes")
local catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemCatalog"))
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder, gui.Enabled = "MaterialShelfGui", false, 21, false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size, frame.Position = UDim2.fromOffset(520, 260), UDim2.new(0.5, -260, 0.5, -130)
frame.BackgroundColor3, frame.Parent = Color3.fromRGB(247, 241, 252), gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)
local title = Instance.new("TextLabel")
title.Size, title.Position = UDim2.new(1, -100, 0, 38), UDim2.fromOffset(14, 6)
title.BackgroundTransparency, title.Font, title.TextSize = 1, Enum.Font.GothamBold, 18
title.TextColor3, title.TextXAlignment, title.Parent = Color3.fromRGB(65, 50, 75), Enum.TextXAlignment.Left, frame
local close = Instance.new("TextButton")
close.Size, close.Position, close.Text, close.Parent = UDim2.fromOffset(62, 30), UDim2.new(1, -74, 0, 8), "닫기", frame
close.Activated:Connect(function() gui.Enabled = false end)
local heldLabel = Instance.new("TextLabel")
heldLabel.Size, heldLabel.Position = UDim2.new(1, -24, 0, 28), UDim2.fromOffset(12, 42)
heldLabel.BackgroundTransparency, heldLabel.Font, heldLabel.TextSize = 1, Enum.Font.Gotham, 13
heldLabel.TextXAlignment, heldLabel.Parent = Enum.TextXAlignment.Left, frame
local gridFrame = Instance.new("ScrollingFrame")
gridFrame.Size, gridFrame.Position = UDim2.new(1, -28, 1, -82), UDim2.fromOffset(14, 74)
gridFrame.BackgroundColor3, gridFrame.BorderSizePixel, gridFrame.ScrollBarThickness = Color3.fromRGB(235, 226, 243), 0, 7
gridFrame.CanvasSize, gridFrame.Parent = UDim2.fromOffset(500, 190), frame
local layout = Instance.new("UIGridLayout")
layout.CellSize, layout.CellPadding, layout.FillDirectionMaxCells = UDim2.fromOffset(94, 78), UDim2.fromOffset(6, 6), 5
layout.Parent = gridFrame

local activeKey, slotCount, latestSlots = nil, 10, {}
local function refresh(slots)
	if type(slots) == "table" then latestSlots = slots end
	local ok, inventory = pcall(function() return remotes.RequestInventory:InvokeServer() end)
	local heldId = ok and type(inventory) == "table" and inventory.HeldItemId
	local heldItem = heldId and catalog.Get(heldId)
	heldLabel.Text = heldItem and ("손에 든 재료: " .. heldItem.DisplayName) or "손에 든 재료 없음 · 가방에서 먼저 선택하세요"
	for _, child in ipairs(gridFrame:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
	for index = 1, slotCount do
		local item = latestSlots[index] and catalog.Get(latestSlots[index])
		local button = Instance.new("TextButton")
		button.Name, button.LayoutOrder = "Slot_" .. index, index
		button.BackgroundColor3 = item and (item.DisplayColor or Color3.fromRGB(215, 195, 230)) or Color3.new(1, 1, 1)
		button.TextColor3, button.TextWrapped, button.Font, button.TextSize = Color3.fromRGB(60, 48, 68), true, Enum.Font.GothamBold, 13
		button.Text = item and (index .. "번\n" .. item.DisplayName .. "\n눌러 회수") or (index .. "번\n빈 칸\n손 재료 진열")
		button.Parent = gridFrame
		Instance.new("UICorner", button).CornerRadius = UDim.new(0, 9)
		button.Activated:Connect(function()
			local action = latestSlots[index] and "Take" or "Deposit"
			local callOk, success, message, updated = pcall(function() return remotes.MaterialShelfAction:InvokeServer(action, index) end)
			if callOk and success then latestSlots = updated or latestSlots; refresh(latestSlots) else warn("[MaterialShelf] " .. tostring(callOk and message or success)) end
		end)
	end
end

remotes.OpenMaterialShelf.OnClientEvent:Connect(function(slots, count, key, category, label)
	latestSlots, slotCount, activeKey = slots or {}, tonumber(count) or 10, key
	title.Text = (label or category or "재료") .. " 진열장 · 손에 든 같은 종류 재료를 놓고, 칸을 눌러 회수"
	gui.Enabled = true
	refresh(latestSlots)
end)

RunService.Heartbeat:Connect(function()
	if not gui.Enabled or not activeKey then return end
	local plots = Workspace:FindFirstChild("HousingPlots")
	local ownPlot
	if plots then for _, plot in ipairs(plots:GetChildren()) do if plot:GetAttribute("OwnerUserId") == player.UserId then ownPlot = plot; break end end end
	local shelf = ownPlot and ownPlot:FindFirstChild(activeKey, true)
	local part = shelf and (shelf:IsA("BasePart") and shelf or shelf:FindFirstChildWhichIsA("BasePart", true))
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not part or not root or (root.Position - part.Position).Magnitude > 8 then gui.Enabled = false end
end)

remotes.InventoryUpdated.OnClientEvent:Connect(function(snapshot)
	if gui.Enabled and type(snapshot) == "table" then refresh(latestSlots) end
end)
