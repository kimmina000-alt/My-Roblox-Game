-- [[ 위치: ReplicatedStorage > ItemDataModule ]]
-- [[ 역할: 중앙 재료 데이터베이스 (토핑, 베이스, 염료, 향료) ]]

local ItemDataModule = {}

-- 등급(Rarity) 정의 및 가중치/색상
ItemDataModule.Rarity = {
	Common = { Name = "Common", Color = Color3.fromRGB(200, 200, 200), Weight = 50 },
	Rare = { Name = "Rare", Color = Color3.fromRGB(80, 170, 255), Weight = 30 },
	Epic = { Name = "Epic", Color = Color3.fromRGB(180, 90, 255), Weight = 15 },
	Legendary = { Name = "Legendary", Color = Color3.fromRGB(255, 200, 50), Weight = 5 }
}

-- 재료 카테고리 정의
ItemDataModule.Category = {
	Topping = "Topping",
	Base = "Base",
	Dye = "Dye",
	Fragrance = "Fragrance"
}

-- 중앙 아이템 데이터베이스
ItemDataModule.Database = {
	----------------------------------------------------------------------------
	-- 1. 토핑 (Topping)
	----------------------------------------------------------------------------
	["구슬 토핑"] = {
		Category = ItemDataModule.Category.Topping,
		Rarity = ItemDataModule.Rarity.Common.Name,
		Icon = "??",
		SoundId = "rbxassetid://9114223160",
		Buff = { GoldBonus = 1.05, SpeedBonus = 0 },
		ParticleEffect = { Texture = "rbxassetid://6031097229", Color = Color3.fromRGB(200, 200, 255), Size = 0.3 }
	},
	["크런치 폼볼"] = {
		Category = ItemDataModule.Category.Topping,
		Rarity = ItemDataModule.Rarity.Rare.Name,
		Icon = "??",
		SoundId = "rbxassetid://9114223160",
		Buff = { GoldBonus = 1.15, SpeedBonus = 1 },
		ParticleEffect = { Texture = "rbxassetid://6031097229", Color = Color3.fromRGB(255, 220, 150), Size = 0.4 }
	},
	["바삭한 칩"] = {
		Category = ItemDataModule.Category.Topping,
		Rarity = ItemDataModule.Rarity.Epic.Name,
		Icon = "??",
		SoundId = "rbxassetid://9114223160",
		Buff = { GoldBonus = 1.3, SpeedBonus = 2 },
		ParticleEffect = { Texture = "rbxassetid://6031097229", Color = Color3.fromRGB(200, 120, 50), Size = 0.5 }
	},
	["갤럭시 펄"] = {
		Category = ItemDataModule.Category.Topping,
		Rarity = ItemDataModule.Rarity.Legendary.Name,
		Icon = "??",
		SoundId = "rbxassetid://9114223160",
		Buff = { GoldBonus = 1.6, SpeedBonus = 4 },
		ParticleEffect = { Texture = "rbxassetid://6031097229", Color = Color3.fromRGB(150, 80, 255), Size = 0.6 }
	},

	----------------------------------------------------------------------------
	-- 2. 베이스 (Base)
	----------------------------------------------------------------------------
	["클리어 베이스"] = {
		Category = ItemDataModule.Category.Base,
		Rarity = ItemDataModule.Rarity.Common.Name,
		Icon = "??",
		Buff = { TextureViscosity = 1.0 },
		ParticleEffect = nil
	},
	["버터 베이스"] = {
		Category = ItemDataModule.Category.Base,
		Rarity = ItemDataModule.Rarity.Rare.Name,
		Icon = "??",
		Buff = { TextureViscosity = 1.2, SizeMultiplier = 1.1 },
		ParticleEffect = { Texture = "rbxassetid://6031097229", Color = Color3.fromRGB(255, 255, 180), Size = 0.3 }
	},

	----------------------------------------------------------------------------
	-- 3. 염료 (Dye)
	----------------------------------------------------------------------------
	["체리 레드 염료"] = {
		Category = ItemDataModule.Category.Dye,
		Rarity = ItemDataModule.Rarity.Common.Name,
		Icon = "??",
		ColorHex = "#FF3366",
		Buff = { VisualCharm = 1.1 },
		ParticleEffect = nil
	},
	["네온 블루 염료"] = {
		Category = ItemDataModule.Category.Dye,
		Rarity = ItemDataModule.Rarity.Rare.Name,
		Icon = "??",
		ColorHex = "#00E5FF",
		Buff = { VisualCharm = 1.25 },
		ParticleEffect = { Texture = "rbxassetid://6031097229", Color = Color3.fromRGB(0, 229, 255), Size = 0.3 }
	},

	----------------------------------------------------------------------------
	-- 4. 향료 (Fragrance)
	----------------------------------------------------------------------------
	["딸기 향료"] = {
		Category = ItemDataModule.Category.Fragrance,
		Rarity = ItemDataModule.Rarity.Common.Name,
		Icon = "??",
		Buff = { CustomerAttractRate = 1.1 },
		ParticleEffect = nil
	},
	["민트 향료"] = {
		Category = ItemDataModule.Category.Fragrance,
		Rarity = ItemDataModule.Rarity.Rare.Name,
		Icon = "??",
		Buff = { CustomerAttractRate = 1.25 },
		ParticleEffect = { Texture = "rbxassetid://6031097229", Color = Color3.fromRGB(120, 255, 180), Size = 0.3 }
	}
}

-- [조회 전용 헬퍼 함수]
function ItemDataModule.GetItem(itemName)
	return ItemDataModule.Database[itemName]
end

function ItemDataModule.GetItemsByCategory(category)
	local result = {}
	for name, data in pairs(ItemDataModule.Database) do
		if data.Category == category then
			result[name] = data
		end
	end
	return result
end

return ItemDataModule