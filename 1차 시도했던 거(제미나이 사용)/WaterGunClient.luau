local tool = script.Parent
local player = game:GetService("Players").LocalPlayer
local mouse = player:GetMouse()
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local isShooting = false
local shootEvent = tool:WaitForChild("ShootEvent") -- RemoteEvent

tool.Equipped:Connect(function()
	-- 툴을 쥐었을 때 마우스 커서 아이콘 변경 가능
end)

tool.Activated:Connect(function()
	isShooting = true
	shootEvent:FireServer(true) -- 물총 발사 시작 알림

	task.spawn(function()
		while isShooting do
			local target = mouse.Target
			local targetPos = mouse.Hit.Position

			if target then
				-- 마우스가 가리키는 곳으로 물줄기 발사 이벤트 전송
				shootEvent:FireServer("Shoot", targetPos, target)
			end
			task.wait(0.1) -- 물줄기 연사 간격
		end
	end)
end)

tool.Deactivated:Connect(function()
	isShooting = false
	shootEvent:FireServer(false) -- 물총 발사 중지 알림
end)

tool.Unequipped:Connect(function()
	isShooting = false
	shootEvent:FireServer(false)
end)