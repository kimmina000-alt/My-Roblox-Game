local tool = script.Parent
local shootEvent = tool:WaitForChild("ShootEvent")
local handle = tool:WaitForChild("Handle")

-- 물줄기 시각적 파티클 연출 (Handle에 파티클이 없다면 자동 생성)
local particle = handle:FindFirstChildOfClass("ParticleEmitter")
if not particle then
	particle = Instance.new("ParticleEmitter")
	particle.Color = ColorSequence.new(Color3.fromRGB(100, 200, 255))
	particle.Size = NumberSequence.new(0.3)
	particle.Speed = NumberRange.new(15, 25)
	particle.Lifetime = NumberRange.new(0.2, 0.4)
	particle.Enabled = false
	particle.Parent = handle
end

shootEvent.OnServerEvent:Connect(function(player, action, targetPos, targetPart)
	if type(action) == "boolean" then
		particle.Enabled = action
	elseif action == "Shoot" and targetPart then
		-- 물줄기가 세척 대상 파트(더러운 토핑)에 맞았는지 검증
		if targetPart:FindFirstChild("CleanProgress") then
			local progressValue = targetPart.CleanProgress
			local dirtyToppingModel = targetPart.Parent

			-- 때(지저분함) 수치 감소 / 세척도 증가 (+5%)
			progressValue.Value = math.min(100, progressValue.Value + 5)

			-- 세척 시 때 파티클 효과 연출
			local dirtParticle = targetPart:FindFirstChildOfClass("ParticleEmitter")
			if dirtParticle then
				dirtParticle.Transparency = NumberSequence.new(progressValue.Value / 100)
			end
		end
	end
end)