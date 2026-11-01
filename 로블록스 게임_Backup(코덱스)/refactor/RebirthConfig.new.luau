-- ReplicatedStorage > RebirthConfig
-- Display names are used by the current Tool inventory. Move these to stable ItemIds
-- when the item data migration is applied.

local RebirthConfig = {}

RebirthConfig.Stages = {
	[1] = {
		RequiredGold = 100, -- test balance; tune before release
		RequiredTopping = "구슬 토핑",
		WorkerIncomeMultiplier = 1.5,
		MaxWorkerBonus = 1,
		UnlockedAura = "SparkleAura_Stage1",
	},
	[2] = {
		RequiredGold = 500000,
		RequiredTopping = "크런치 폼볼",
		WorkerIncomeMultiplier = 2,
		MaxWorkerBonus = 2,
		UnlockedAura = "FlameAura_Stage2",
	},
}

function RebirthConfig.GetStageConfig(currentRebirthCount)
	local nextStage = math.floor(tonumber(currentRebirthCount) or 0) + 1
	return RebirthConfig.Stages[nextStage]
end

return RebirthConfig
