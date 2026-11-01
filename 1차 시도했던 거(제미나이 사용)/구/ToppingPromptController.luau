-- [[ 위치: StarterPlayer > StarterPlayerScripts > ToppingPromptController ]]
-- [[ 역할: 대형 ToppingPad 진열/회수 프롬프트 텍스트 제어 ]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer

local function updatePrompts()
	local character = localPlayer.Character
	if not character then return end

	local holdingTool = character:FindFirstChildOfClass("Tool") ~= nil

	for _, desc in ipairs(Workspace:GetDescendants()) do
		if desc:IsA("BasePart") and desc:GetAttribute("IsToppingPad") then
			local prompt = desc:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Enabled = true
				if holdingTool then
					prompt.ActionText = "토핑 진열 (E)"
				else
					prompt.ActionText = "토핑 회수 (E)"
				end
			end
		end
	end
end

RunService.Heartbeat:Connect(updatePrompts)