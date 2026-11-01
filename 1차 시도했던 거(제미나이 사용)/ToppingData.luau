local ToppingData = {}

-- ?? 가챠 아이템 목록 및 확률 설정 (weight 합이 꼭 100일 필요 없음)
ToppingData.Items = {
		{ name = "Bat",     weight = 50 }, -- 50% 확률
		{ name = "Torch",      weight = 35 }, -- 35% 확률
		{ name = "Flashlight", weight = 15 }, -- 15% 확률 (희귀)
	-- { name = "Item4",   weight = 10 }, 앞으로 여기에 편하게 추가!
}

return ToppingData