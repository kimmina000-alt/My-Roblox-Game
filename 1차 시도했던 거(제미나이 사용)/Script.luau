local prompt = script.Parent:WaitForChild("ProximityPrompt")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


-- ?? 분리한 아이템 데이터 모듈 불러오기
local toppingData = require(ReplicatedStorage:WaitForChild("ToppingData"))
local toppingFolder = ReplicatedStorage:WaitForChild("Toppings")

-- 가중치 기반 랜덤 선택 함수
local function getRandomItem()
	local totalWeight = 0
	for _, item in ipairs(toppingData.Items) do
		totalWeight = totalWeight + item.weight
	end

	local randomNumber = math.random(1, totalWeight)
	local currentWeight = 0

	for _, item in ipairs(toppingData.Items) do
		currentWeight = currentWeight + item.weight
		if randomNumber <= currentWeight then
			return item.name
		end
	end
end

prompt.Triggered:Connect(function(player)
	local selectedItemName = getRandomItem()
	local itemTemplate = toppingFolder:FindFirstChild(selectedItemName)

	if itemTemplate then
		local newItem = itemTemplate:Clone()
		newItem.Parent = player:WaitForChild("Backpack")
		print(player.Name .. "님이 [" .. selectedItemName .. "] 아이템을 뽑았습니다!")
	end
end)