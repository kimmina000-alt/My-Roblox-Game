-- [[ 위치: ReplicatedStorage > RebirthConfig ]]
-- [[ 역할: 환생 조건(특정 토핑, 골드) 및 보상 설정 분리 모듈 ]]

local RebirthConfig = {}

-- 1. 환생에 필요한 특정 조건 토핑 목록
RebirthConfig.RequiredToppings = {
	[1] = "구슬 토핑", -- 1회차 환생 시 필요한 토핑
	[2] = "크런치 폼볼", -- 2회차 환생 시
	[3] = "바삭한 칩",  -- 3회차 환생 시
}

-- 2. 단계별 환생 요구사항 및 보상 테이블
RebirthConfig.Stages = {
	[1] = {
		RequiredGold = 100,                    -- [테스트용] 요구 골드 500으로 변경
		RequiredTopping = RebirthConfig.RequiredToppings[1], -- "구슬 토핑"

		-- 보상 정의
		WorkerIncomeMultiplier = 1.5,           -- 노동자 수익 50% 증가 (+50%)
		MaxWorkerBonus = 1,                     -- 고용 가능 노동자 +1명
		UnlockedAura = "SparkleAura_Stage1"     -- 해금되는 아우라 이름
	},
	[2] = {
		RequiredGold = 500000,
		RequiredTopping = RebirthConfig.RequiredToppings[2],

		WorkerIncomeMultiplier = 2.0,           -- 수익 +100%
		MaxWorkerBonus = 2,                     -- 노동자 +2명
		UnlockedAura = "FlameAura_Stage2"
	}
}

-- 현재 환생 단계에 따른 요구 데이터 반환
function RebirthConfig.GetStageConfig(currentRebirthCount)
	local nextStage = currentRebirthCount + 1
	return RebirthConfig.Stages[nextStage] or RebirthConfig.Stages[#RebirthConfig.Stages]
end

return RebirthConfig