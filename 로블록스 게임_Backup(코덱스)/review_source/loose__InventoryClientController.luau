-- [[ 위치: StarterGui > InventoryGui > InventoryClientController ]]
-- [[ 역할: Craft Basket 및 Gacha Cabinet 통합 UI 버튼 및 모달 창 제어 ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 모듈 로드
local ItemDataModule = require(ReplicatedStorage:WaitForChild("ItemDataModule"))
local BagDataModule = require(ReplicatedStorage:WaitForChild("BagDataModule"))

--------------------------------------------------------------------------------
-- 1. ScreenGui 및 메인 HUD 버튼 생성
--------------------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "InventoryGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 5
screenGui.Parent = playerGui

-- 화면 좌측 버튼 모음 프레임
local sideMenuFrame = Instance.new("Frame")
sideMenuFrame.Name = "SideMenuFrame"
sideMenuFrame.Size = UDim2.new(0, 140, 0, 110)
sideMenuFrame.Position = UDim2.new(0, 15, 0.5, -55)
sideMenuFrame.BackgroundTransparency = 1
sideMenuFrame.Parent = screenGui

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 10)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Parent = sideMenuFrame

-- [2번] Craft Basket 열기 버튼
local craftBtn = Instance.new("TextButton")
craftBtn.Name = "CraftBasketBtn"
craftBtn.Size = UDim2.new(1, 0, 0, 48)
craftBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 210)
craftBtn.Text = "?? 조합 바구니"
craftBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
craftBtn.TextSize = 15
craftBtn.Font = Enum.Font.FredokaOne
craftBtn.LayoutOrder = 1
craftBtn.Parent = sideMenuFrame

local craftCorner = Instance.new("UICorner")
craftCorner.CornerRadius = UDim.new(0, 10)
craftCorner.Parent = craftBtn

-- [3번] Gacha Cabinet 열기 버튼
local gachaBtn = Instance.new("TextButton")
gachaBtn.Name = "GachaCabinetBtn"
gachaBtn.Size = UDim2.new(1, 0, 0, 48)
gachaBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 220)
gachaBtn.Text = "?? 가챠 보관함"
gachaBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
gachaBtn.TextSize = 15
gachaBtn.Font = Enum.Font.FredokaOne
gachaBtn.LayoutOrder = 2
gachaBtn.Parent = sideMenuFrame

local gachaCorner = Instance.new("UICorner")
gachaCorner.CornerRadius = UDim.new(0, 10)
gachaCorner.Parent = gachaBtn

--------------------------------------------------------------------------------
-- 2. Craft Basket UI 창 (2번: 조합 전용)
--------------------------------------------------------------------------------
local craftFrame = Instance.new("Frame")
craftFrame.Name = "CraftBasketWindow"
craftFrame.Size = UDim2.new(0, 420, 0, 320)
craftFrame.Position = UDim2.new(0.5, -210, 0.5, -160)
craftFrame.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
craftFrame.Visible = false
craftFrame.Parent = screenGui

local craftWindowCorner = Instance.new("UICorner")
craftWindowCorner.CornerRadius = UDim.new(0, 16)
craftWindowCorner.Parent = craftFrame

local craftTitle = Instance.new("TextLabel")
craftTitle.Size = UDim2.new(1, -40, 0, 40)
craftTitle.Position = UDim2.new(0, 15, 0, 5)
craftTitle.BackgroundTransparency = 1
craftTitle.Text = "?? 조합 바구니 (Craft Basket)"
craftTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
craftTitle.TextSize = 18
craftTitle.Font = Enum.Font.FredokaOne
craftTitle.TextXAlignment = Enum.TextXAlignment.Left
craftTitle.Parent = craftFrame

local craftClose = Instance.new("TextButton")
craftClose.Size = UDim2.new(0, 30, 0, 30)
craftClose.Position = UDim2.new(1, -38, 0, 10)
craftClose.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
craftClose.Text = "X"
craftClose.TextColor3 = Color3.fromRGB(255, 255, 255)
craftClose.Font = Enum.Font.FredokaOne
craftClose.Parent = craftFrame

local craftCloseCorner = Instance.new("UICorner")
craftCloseCorner.CornerRadius = UDim.new(0, 8)
craftCloseCorner.Parent = craftClose

-- 슬롯 그리드 (Base 1, Toppings 3, Dye 1, Fragrance 1)
local craftContent = Instance.new("Frame")
craftContent.Size = UDim2.new(1, -30, 1, -60)
craftContent.Position = UDim2.new(0, 15, 0, 50)
craftContent.BackgroundTransparency = 1
craftContent.Parent = craftFrame

local function createSlotUI(parent, name, pos, size, labelText)
	local slot = Instance.new("Frame")
	slot.Name = name
	slot.Position = pos
	slot.Size = size
	slot.BackgroundColor3 = Color3.fromRGB(50, 55, 75)
	slot.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = slot

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = labelText
	lbl.TextColor3 = Color3.fromRGB(160, 160, 180)
	lbl.TextSize = 13
	lbl.Font = Enum.Font.SourceSansBold
	lbl.Parent = slot

	return slot
end

-- 베이스 (1칸)
createSlotUI(craftContent, "Slot_Base", UDim2.new(0, 10, 0, 10), UDim2.new(0, 110, 0, 80), "?? 베이스\n(비어있음)")
-- 염료 & 향료 (각 1칸)
createSlotUI(craftContent, "Slot_Dye", UDim2.new(0, 135, 0, 10), UDim2.new(0, 110, 0, 80), "?? 염료\n(비어있음)")
createSlotUI(craftContent, "Slot_Fragrance", UDim2.new(0, 260, 0, 10), UDim2.new(0, 110, 0, 80), "?? 향료\n(비어있음)")
-- 토핑 (3칸)
createSlotUI(craftContent, "Slot_Topping1", UDim2.new(0, 10, 0, 110), UDim2.new(0, 110, 0, 80), "?? 토핑 1\n(비어있음)")
createSlotUI(craftContent, "Slot_Topping2", UDim2.new(0, 135, 0, 110), UDim2.new(0, 110, 0, 80), "?? 토핑 2\n(비어있음)")
createSlotUI(craftContent, "Slot_Topping3", UDim2.new(0, 260, 0, 110), UDim2.new(0, 110, 0, 80), "?? 토핑 3\n(비어있음)")

--------------------------------------------------------------------------------
-- 3. Gacha Cabinet UI 창 (3번: 가챠 전용 보관함)
--------------------------------------------------------------------------------
local gachaFrame = Instance.new("Frame")
gachaFrame.Name = "GachaCabinetWindow"
gachaFrame.Size = UDim2.new(0, 480, 0, 350)
gachaFrame.Position = UDim2.new(0.5, -240, 0.5, -175)
gachaFrame.BackgroundColor3 = Color3.fromRGB(40, 35, 55)
gachaFrame.Visible = false
gachaFrame.Parent = screenGui

local gachaWindowCorner = Instance.new("UICorner")
gachaWindowCorner.CornerRadius = UDim.new(0, 16)
gachaWindowCorner.Parent = gachaFrame

local gachaTitle = Instance.new("TextLabel")
gachaTitle.Size = UDim2.new(1, -40, 0, 40)
gachaTitle.Position = UDim2.new(0, 15, 0, 5)
gachaTitle.BackgroundTransparency = 1
gachaTitle.Text = "?? 가챠 보관함 (Gacha Cabinet)"
gachaTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
gachaTitle.TextSize = 18
gachaTitle.Font = Enum.Font.FredokaOne
gachaTitle.TextXAlignment = Enum.TextXAlignment.Left
gachaTitle.Parent = gachaFrame

local gachaClose = Instance.new("TextButton")
gachaClose.Size = UDim2.new(0, 30, 0, 30)
gachaClose.Position = UDim2.new(1, -38, 0, 10)
gachaClose.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
gachaClose.Text = "X"
gachaClose.TextColor3 = Color3.fromRGB(255, 255, 255)
gachaClose.Font = Enum.Font.FredokaOne
gachaClose.Parent = gachaFrame

local gachaCloseCorner = Instance.new("UICorner")
gachaCloseCorner.CornerRadius = UDim.new(0, 8)
gachaCloseCorner.Parent = gachaClose

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -30, 1, -65)
scrollFrame.Position = UDim2.new(0, 15, 0, 50)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 6
scrollFrame.Parent = gachaFrame

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0, 78, 0, 78)
grid.CellPadding = UDim2.new(0, 10, 0, 10)
grid.Parent = scrollFrame

-- 가챠 캐비닛 예시 슬롯 15개 동적 생성
for i = 1, 15 do
	local slotBtn = Instance.new("TextButton")
	slotBtn.Name = "CabinetSlot_" .. i
	slotBtn.BackgroundColor3 = Color3.fromRGB(55, 50, 75)
	slotBtn.Text = "<b>[" .. i .. "]</b>\n<font color='rgb(120,120,120)'>비어있음</font>"
	slotBtn.RichText = true
	slotBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
	slotBtn.Font = Enum.Font.FredokaOne
	slotBtn.TextSize = 11
	slotBtn.Parent = scrollFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = slotBtn
end

--------------------------------------------------------------------------------
-- 4. 버튼 이벤트 바인딩 (UI 토글)
--------------------------------------------------------------------------------
craftBtn.MouseButton1Click:Connect(function()
	craftFrame.Visible = not craftFrame.Visible
	if craftFrame.Visible then gachaFrame.Visible = false end
end)

gachaBtn.MouseButton1Click:Connect(function()
	gachaFrame.Visible = not gachaFrame.Visible
	if gachaFrame.Visible then craftFrame.Visible = false end
end)

craftClose.MouseButton1Click:Connect(function() craftFrame.Visible = false end)
gachaClose.MouseButton1Click:Connect(function() gachaFrame.Visible = false end)