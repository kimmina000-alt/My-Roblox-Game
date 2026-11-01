-- [[ 위치: ReplicatedStorage > BagDataModule ]]
-- [[ 역할: 3종 가방(Dirty Bag, Craft Basket, Gacha Cabinet) 데이터 구조 모듈 ]]

local ItemDataModule = require(script.Parent:WaitForChild("ItemDataModule"))

local BagDataModule = {}
BagDataModule.__index = BagDataModule

--------------------------------------------------------------------------------
-- 1. Dirty Bag (더러운 아이템 전용 1칸 슬롯)
--------------------------------------------------------------------------------
local DirtyBag = {}
DirtyBag.__index = DirtyBag

function DirtyBag.new()
	local self = setmetatable({}, DirtyBag)
	self.Item = nil -- 단일 토핑만 저장
	return self
end

function DirtyBag:SetItem(itemName)
	self.Item = itemName
end

function DirtyBag:Clear()
	self.Item = nil
end

function DirtyBag:IsEmpty()
	return self.Item == nil
end

--------------------------------------------------------------------------------
-- 2. Craft Basket (조합 전용 가방 구조 - 라이브러리 레시피 저장 고려)
--------------------------------------------------------------------------------
local CraftBasket = {}
CraftBasket.__index = CraftBasket

function CraftBasket.new()
	local self = setmetatable({}, CraftBasket)
	self.Slots = {
		Base = nil,                  -- Base 1개
		Toppings = { nil, nil, nil },-- Topping 최대 3개
		Dye = nil,                   -- Dye 1개
		Fragrance = nil              -- Fragrance 1개
	}
	return self
end

function CraftBasket:SetIngredient(category, itemName, subIndex)
	local itemInfo = ItemDataModule.GetItem(itemName)
	if not itemInfo or itemInfo.Category ~= category then return false, "유효하지 않은 재료 카테고리입니다." end

	if category == ItemDataModule.Category.Base then
		self.Slots.Base = itemName
	elseif category == ItemDataModule.Category.Dye then
		self.Slots.Dye = itemName
	elseif category == ItemDataModule.Category.Fragrance then
		self.Slots.Fragrance = itemName
	elseif category == ItemDataModule.Category.Topping then
		local idx = subIndex or 1
		if idx >= 1 and idx <= 3 then
			self.Slots.Toppings[idx] = itemName
		end
	end
	return true
end

-- 조합 레시피 데이터 추출 (추후 슬라임 레시피 저장/불러오기 기능에 직접 활용)
function CraftBasket:ExportRecipe()
	return {
		Base = self.Slots.Base,
		Toppings = table.clone(self.Slots.Toppings),
		Dye = self.Slots.Dye,
		Fragrance = self.Slots.Fragrance
	}
end

function CraftBasket:LoadRecipe(recipeData)
	if not recipeData then return end
	self.Slots.Base = recipeData.Base
	self.Slots.Toppings = recipeData.Toppings or { nil, nil, nil }
	self.Slots.Dye = recipeData.Dye
	self.Slots.Fragrance = recipeData.Fragrance
end

--------------------------------------------------------------------------------
-- 3. Gacha Cabinet (가차/진열장 보관용 가방 - N칸 가변 인벤토리)
--------------------------------------------------------------------------------
local GachaCabinet = {}
GachaCabinet.__index = GachaCabinet

function GachaCabinet.new(maxSlots)
	local self = setmetatable({}, GachaCabinet)
	self.MaxSlots = maxSlots or 10
	self.Slots = {}
	for i = 1, self.MaxSlots do
		self.Slots[i] = false
	end
	return self
end

function GachaCabinet:AddItem(itemName)
	for i = 1, self.MaxSlots do
		if self.Slots[i] == false then
			self.Slots[i] = itemName
			return i -- 저장된 슬롯 인덱스 반환
		end
	end
	return nil, "가방이 가득 차 있습니다."
end

function GachaCabinet:RemoveItem(slotIndex)
	if self.Slots[slotIndex] then
		local removed = self.Slots[slotIndex]
		self.Slots[slotIndex] = false
		return removed
	end
	return nil
end

function GachaCabinet:SwapSlots(slotA, slotB)
	if self.Slots[slotA] ~= nil and self.Slots[slotB] ~= nil then
		self.Slots[slotA], self.Slots[slotB] = self.Slots[slotB], self.Slots[slotA]
		return true
	end
	return false
end

--------------------------------------------------------------------------------
-- BagDataModule 팩토리 내보내기
--------------------------------------------------------------------------------
BagDataModule.CreateDirtyBag = DirtyBag.new
BagDataModule.CreateCraftBasket = CraftBasket.new
BagDataModule.CreateGachaCabinet = GachaCabinet.new

return BagDataModule