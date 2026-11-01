-- Stable item IDs are saved. Display names can change without breaking player data.

local ItemCatalog = {}

ItemCatalog.RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

-- Default additive gold bonus per topping, paid for each 6-stud step on its pad.
-- Special items can override this with GoldPerStepOverride.
ItemCatalog.ToppingGoldPerStepByRarity = {
	Common = 0.5,
	Rare = 1,
	Epic = 1.5,
	Legendary = 2,
	Mythic = 2.5,
}

ItemCatalog.Rarities = {
	Common = { DisplayName = "일반", Color = Color3.fromRGB(255, 255, 255), BookColor = Color3.fromRGB(255, 255, 255) },
	Rare = { DisplayName = "레어", Color = Color3.fromRGB(245, 155, 55), BookColor = Color3.fromRGB(245, 155, 55) },
	Epic = { DisplayName = "에픽", Color = Color3.fromRGB(150, 90, 220), BookColor = Color3.fromRGB(150, 90, 220) },
	Legendary = { DisplayName = "레전더리", Color = Color3.fromRGB(255, 195, 55), BookColor = Color3.fromRGB(255, 195, 55) },
	Mythic = { DisplayName = "신화적인", Color = Color3.fromRGB(255, 90, 150), BookColor = Color3.fromRGB(255, 90, 150) },
}

ItemCatalog.Items = {
	topping_bead = {
		DisplayName = "구슬 토핑", Category = "Topping", Rarity = "Common",
		Storage = "Craft", RebirthEligible = true, Weight = 50, CleaningWeight = 60,
		IconShape = "Ball", DisplayColor = Color3.fromRGB(250, 250, 255), StepSoundKey = "BeadSquish",
		Buff = { WorkerIncomeMultiplier = 1.05 },
	},
	topping_crunchy_foam = {
		DisplayName = "크런치 폼볼", Category = "Topping", Rarity = "Rare",
		Storage = "Craft", Weight = 30, CleaningWeight = 30, IconShape = "Cluster", DisplayColor = Color3.fromRGB(255, 174, 73),
		StepSoundKey = "FoamCrackle", Buff = { WorkerIncomeMultiplier = 1.15 },
	},
	topping_crispy_chip = {
		DisplayName = "바삭한 칩", Category = "Topping", Rarity = "Epic",
		Storage = "Craft", Weight = 15, CleaningWeight = 10, IconShape = "Chip", DisplayColor = Color3.fromRGB(170, 105, 245),
		StepSoundKey = "ChipCrunch", Buff = { WorkerIncomeMultiplier = 1.3 },
	},
	topping_galaxy_pearl = {
		DisplayName = "갤럭시 펄", Category = "Topping", Rarity = "Legendary",
		Storage = "Craft", Weight = 5, IconShape = "Pearl", DisplayColor = Color3.fromRGB(115, 195, 255),
		StepSoundKey = "GalaxyChime", Buff = { WorkerIncomeMultiplier = 1.6 },
	},
	topping_dirty = {
		DisplayName = "더러운 토핑", Category = "DirtyTopping", Rarity = "Common",
		Storage = "DirtyBag", Weight = 1, IconShape = "Ball", BookVisible = false,
	},
	base_clear = {
		DisplayName = "클리어 베이스", Category = "Base", Rarity = "Common",
		Storage = "Craft", Weight = 1, IconShape = "Blob", DisplayColor = Color3.fromRGB(170, 235, 245), StepSoundKey = "ClearSquish", Buff = { Firmness = 0.45, Elasticity = 0.92, Viscosity = 0.6, ToppingCapacity = 3, ToppingGravityScale = 0.75, GoldPerStep = 0.4 },
	},
	base_clay = {
		DisplayName = "클레이 베이스", Category = "Base", Rarity = "Rare",
		Storage = "Craft", Weight = 1, IconShape = "Blob", DisplayColor = Color3.fromRGB(210, 155, 120), StepSoundKey = "ClayPress", Buff = { Firmness = 0.9, Elasticity = 0.4, Viscosity = 1.2, ToppingCapacity = 3, ToppingGravityScale = 1, GoldPerStep = 0.4 },
	},
	base_whipped = {
		DisplayName = "왁뿌 베이스", Category = "Base", Rarity = "Common",
		Storage = "Craft", Weight = 1, IconShape = "Blob", DisplayColor = Color3.fromRGB(255, 225, 238), StepSoundKey = "WhippedSoft", Buff = { Firmness = 0.35, Elasticity = 0.7, Viscosity = 0.75, ToppingCapacity = 3, ToppingGravityScale = 0.55, GoldPerStep = 0.4 },
	},
	base_glue_all = {
		DisplayName = "글루올 베이스", Category = "Base", Rarity = "Epic",
		Storage = "Craft", Weight = 1, IconShape = "Blob", DisplayColor = Color3.fromRGB(230, 225, 120), StepSoundKey = "GlueStretch", Buff = { Firmness = 0.7, Elasticity = 0.95, Viscosity = 1.35, ToppingCapacity = 3, ToppingGravityScale = 1.2, GoldPerStep = 0.4 },
	},
	base_butter = {
		DisplayName = "버터 베이스", Category = "Base", Rarity = "Rare",
		Storage = "Craft", Weight = 1, IconShape = "Blob", DisplayColor = Color3.fromRGB(255, 224, 120), StepSoundKey = "ButterSquish", Buff = { Firmness = 0.65, Elasticity = 0.55, Viscosity = 1.15, ToppingCapacity = 3, ToppingGravityScale = 0.8, GoldPerStep = 0.4 },
	},
	activator_borax = {
		DisplayName = "붕사 액티베이터", Category = "Activator", Rarity = "Common",
		Storage = "Craft", Weight = 1, IconShape = "Drop", DisplayColor = Color3.fromRGB(160, 220, 255),
		Buff = { Firmness = 1.0 },
	},
	activator_contact_solution = {
		DisplayName = "렌즈 세정액 액티베이터", Category = "Activator", Rarity = "Rare",
		Storage = "Craft", Weight = 1, IconShape = "Drop", DisplayColor = Color3.fromRGB(135, 190, 255),
		Buff = { Firmness = 1.2 },
	},
	activator_baking_soda = {
		DisplayName = "베이킹소다 액티베이터", Category = "Activator", Rarity = "Epic",
		Storage = "Craft", Weight = 1, IconShape = "Drop", DisplayColor = Color3.fromRGB(245, 245, 255),
		Buff = { Firmness = 1.4 },
	},
	dye_red = {
		DisplayName = "빨간 염료", Category = "Dye", Rarity = "Common",
		Storage = "Craft", Weight = 1, IconShape = "Drop", DisplayColor = Color3.fromRGB(235, 75, 95),
	},
	dye_blue = {
		DisplayName = "파란 염료", Category = "Dye", Rarity = "Common",
		Storage = "Craft", Weight = 1, IconShape = "Drop", DisplayColor = Color3.fromRGB(80, 145, 245),
	},
	fragrance_peach = {
		DisplayName = "복숭아 향료", Category = "Fragrance", Rarity = "Rare",
		Storage = "Craft", Weight = 1, IconShape = "Drop", DisplayColor = Color3.fromRGB(255, 174, 156), Buff = { WorkerIncomeMultiplier = 1.1 },
	},
	surface_glossy_oil = {
		DisplayName = "글로시 오일", Category = "SurfaceEffect", Rarity = "Common",
		Storage = "Craft", Weight = 1, IconShape = "Drop", DisplayColor = Color3.fromRGB(165, 235, 245),
		EffectKey = "Glossy", SoundKey = "SoftWetPress",
	},
	surface_fine_glitter = {
		DisplayName = "미세 글리터", Category = "SurfaceEffect", Rarity = "Rare",
		Storage = "Craft", Weight = 1, IconShape = "Sparkle", DisplayColor = Color3.fromRGB(220, 190, 255),
		EffectKey = "FineGlitter", VisualOnly = true,
	},
	gacha_topping_star = {
		DisplayName = "별빛 한정 토핑", Category = "Topping", Rarity = "Legendary",
		Storage = "Gacha", Protected = true, Weight = 1, IconShape = "Star", DisplayColor = Color3.fromRGB(160, 125, 255),
		StepSoundKey = "StarChime", Buff = { WorkerIncomeMultiplier = 1.2 },
	},
}

ItemCatalog.LegacyNames = {
	["구슬 토핑"] = "topping_bead",
	["크런치 폼볼"] = "topping_crunchy_foam",
	["바삭한 칩"] = "topping_crispy_chip",
	["갤럭시 펄"] = "topping_galaxy_pearl",
	["DirtyTopping"] = "topping_dirty",
	["dirtyTopping"] = "topping_dirty",
	["클리어 베이스"] = "base_clear",
	["클레이 베이스"] = "base_clay",
	["빨간 염료"] = "dye_red",
	["파란 염료"] = "dye_blue",
	["복숭아 향료"] = "fragrance_peach",
}

function ItemCatalog.Get(itemId)
	return ItemCatalog.Items[itemId]
end

function ItemCatalog.GetGoldPerStep(itemId)
	local item = ItemCatalog.Get(itemId)
	if not item then return 0 end
	if item.Category == "Topping" then
		return tonumber(item.GoldPerStepOverride)
			or tonumber(ItemCatalog.ToppingGoldPerStepByRarity[item.Rarity])
			or 0
	end
	return tonumber(item.Buff and item.Buff.GoldPerStep) or 0
end

function ItemCatalog.GetIdFromLegacyName(name)
	if ItemCatalog.Items[name] then return name end
	return ItemCatalog.LegacyNames[name]
end

function ItemCatalog.GetByCategory(category)
	local result = {}
	for itemId, definition in pairs(ItemCatalog.Items) do
		if definition.Category == category then
			result[itemId] = definition
		end
	end
	return result
end

function ItemCatalog.GetCollectionItems()
	local items = {}
	for itemId, definition in pairs(ItemCatalog.Items) do
		if definition.BookVisible ~= false then
			table.insert(items, { Id = itemId, Definition = definition })
		end
	end
	table.sort(items, function(a, b)
		local rarityA, rarityB = table.find(ItemCatalog.RarityOrder, a.Definition.Rarity) or math.huge,
			table.find(ItemCatalog.RarityOrder, b.Definition.Rarity) or math.huge
		if rarityA ~= rarityB then return rarityA < rarityB end
		return a.Id < b.Id
	end)
	return items
end

-- Add CleaningWeight to a clean Craft topping to include it in cleaning rewards.
function ItemCatalog.GetCleaningRewards()
	local rewards = {}
	for itemId, definition in pairs(ItemCatalog.Items) do
		local weight = tonumber(definition.CleaningWeight)
		if definition.Category == "Topping" and definition.Storage == "Craft" and weight and weight > 0 then
			table.insert(rewards, { Id = itemId, Weight = weight })
		end
	end
	table.sort(rewards, function(a, b) return a.Id < b.Id end)
	return rewards
end

return ItemCatalog
