local GameConfig = {}

GameConfig.DataStoreName = "SlimeGame_PlayerData_v1"
GameConfig.SchemaVersion = 2
GameConfig.StartingGold = 300
GameConfig.AutosaveSeconds = 60
GameConfig.MaxPlayers = 15
GameConfig.DirtyBagCapacity = 1
GameConfig.GachaCabinetCapacity = 100
GameConfig.MaxCraftStack = 9999
GameConfig.PadUnlockCosts = { Pad_2 = 500, Pad_3 = 1500, Pad_4 = 2500, Pad_5 = 5000, Pad_6 = 10000 }

GameConfig.RebirthStages = {
	[1] = {
		RequiredGold = 100,
		RequiredItemId = "topping_bead",
		WorkerIncomeMultiplier = 1.5,
		AdditionalWorkerSlots = 1,
		AuraId = "aura_sparkle_1",
	},
	[2] = {
		RequiredGold = 500000,
		RequiredItemId = "topping_crunchy_foam",
		WorkerIncomeMultiplier = 2,
		AdditionalWorkerSlots = 1,
		AuraId = "aura_flame_2",
	},
}

GameConfig.Pump = {
	InitialCapacity = 10,
	CapacityTiers = { 10, 30, 50 },
	CapacityUpgradeCosts = { [30] = 250, [50] = 750 },
	AutoRefillUpgradeCosts = { 500, 1000, 2000 },
	AutoRefillMaxLevel = 3,
	BaseRefillPerSecond = 1,
	AutoRefillPerSecond = 0.1,
}

GameConfig.Workers = {
	BaseWalkSpeed = 16,
	WalkSpeedPerUpgrade = 2,
	MaximumWalkSpeed = 28,
	IncomeBonusPerUpgrade = 0.25,
	UpgradeBaseCost = 100,
	UpgradeCostGrowth = 1.5,
	MaximumUpgradeLevel = 10,
	TargetReachDistance = 3,
	MovementMargin = 2.5,
}

GameConfig.SlimePadIncome = {
	TickSeconds = 0.1,
	StudsPerStep = 6,
	MaximumGoldPerStep = 8,
	StandingHeight = 5,
}

GameConfig.Gacha = {
	FreeCoinIntervalSeconds = 20 * 60,
	CabinetCapacity = 100,
	Pools = {
		[1] = {
			MinimumRebirth = 0,
			Items = {
				{ ItemId = "topping_crunchy_foam", Weight = 55 },
				{ ItemId = "topping_crispy_chip", Weight = 30 },
				{ ItemId = "topping_galaxy_pearl", Weight = 12 },
				{ ItemId = "gacha_topping_star", Weight = 3 },
			},
		},
		[2] = {
			MinimumRebirth = 1,
			Items = {
				{ ItemId = "topping_crispy_chip", Weight = 50 },
				{ ItemId = "topping_galaxy_pearl", Weight = 35 },
				{ ItemId = "gacha_topping_star", Weight = 15 },
			},
		},
	},
}

return GameConfig
