local station = script.Parent
local prompt = station:WaitForChild("ProximityPrompt")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local toppingsFolder = ReplicatedStorage:WaitForChild("Toppings")

local currentDirtyItem = nil

prompt.Triggered:Connect(function(player)
	if currentDirtyItem then 
		print("이미 세척대 위에 토핑이 있습니다!")
		return 
	end

	local character = player.Character
	local equippedTool = character and character:FindFirstChildOfClass("Tool")

	-- 1. 플레이어가 툴을 들고 있는지 확인 (물총인 WaterGun은 제외)
	if equippedTool and equippedTool.Name ~= "WaterGun" then
		local rawName = equippedTool.Name
		-- 이름 정리 (예: "깨끗한 topping1" 등의 접두사 제거 대응)
		local cleanName = string.gsub(rawName, "Dirty_", "")
		cleanName = string.gsub(cleanName, "깨끗한 ", "")

		local toppingTemplate = toppingsFolder:FindFirstChild(cleanName) or toppingsFolder:FindFirstChild(rawName)

		if toppingTemplate then
			-- 2. 손에 들고 있던 Tool 삭제
			equippedTool:Destroy()

			-- 3. 세척대 위에 3D 모델/파트 배치
			local dirtyItem = toppingTemplate:Clone()
			dirtyItem.Name = "Dirty_" .. cleanName

			local mainPart = dirtyItem:IsA("Model") and (dirtyItem.PrimaryPart or dirtyItem:FindFirstChildWhichIsA("BasePart")) or dirtyItem

			if mainPart then
				mainPart.Anchored = true
				mainPart.CanCollide = false
				-- 세척대 위쪽 중앙으로 이동
				mainPart.CFrame = station.CFrame * CFrame.new(0, station.Size.Y/2 + (mainPart.Size.Y/2), 0)

				-- 세척 진행도 (0~100)
				local cleanProgress = Instance.new("IntValue")
				cleanProgress.Name = "CleanProgress"
				cleanProgress.Value = 0
				cleanProgress.Parent = mainPart

				-- 슬라임 때 파티클 효과
				local dirtEffect = Instance.new("ParticleEmitter")
				dirtEffect.Name = "DirtEffect"
				dirtEffect.Color = ColorSequence.new(Color3.fromRGB(80, 120, 50))
				dirtEffect.Size = NumberSequence.new(0.6)
				dirtEffect.Rate = 12
				dirtEffect.Parent = mainPart

				-- ?? 100% 세척 완료 시
				cleanProgress.Changed:Connect(function(newValue)
					if newValue >= 100 then
						dirtEffect:Destroy()
						print("? " .. cleanName .. " 세척 완료!")

						task.wait(0.3)
						local cleanTool = toppingTemplate:Clone()
						cleanTool.Name = "깨끗한 " .. cleanName
						cleanTool.Parent = player:WaitForChild("Backpack")

						dirtyItem:Destroy()
						currentDirtyItem = nil
					end
				end)
			end

			dirtyItem.Parent = workspace
			currentDirtyItem = dirtyItem
		else
			print("Toppings 폴더에서 " .. rawName .. " 에셋을 찾을 수 없습니다.")
		end
	end
end)