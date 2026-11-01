-- [[ 위치: StarterPlayer > StarterPlayerScripts > ToppingClickHandler ]]
-- [[ 역할: 마우스 클릭 감지 및 서버 좌표 전송 ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local placeToppingEvent = ReplicatedStorage:WaitForChild("PlaceToppingEvent", 10)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	-- 마우스 왼쪽 클릭 감지
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local targetPart = mouse.Target
		local hitPos = mouse.Hit and mouse.Hit.Position

		if targetPart and hitPos then
			if placeToppingEvent then
				-- 서버에 클릭 파트와 좌표 전송
				local resultType, message = placeToppingEvent:InvokeServer(targetPart, hitPos)
				if message then
					print("?? [시스템]:", message)
				end
			end
		end
	end
end)