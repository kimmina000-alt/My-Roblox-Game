local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemCatalog = require(ReplicatedStorage.Shared.ItemCatalog)
local PlayerDataService = require(script.Parent.PlayerDataService)
local InventoryService = require(script.Parent.InventoryService)
local RemoteService = require(script.Parent.RemoteService)

local CleaningService = {}
local sessions = {}
local SESSION_SECONDS = 30
local MIN_CLEAN_SECONDS = 1.5
local cleaningTable

local function getPart(instance)
	if instance:IsA("BasePart") then return instance end
	return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function near(player, target, distance)
	local part = target and getPart(target)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return part ~= nil and root ~= nil and (root.Position - part.Position).Magnitude <= distance
end

local function chooseCleanTopping()
	local choices = ItemCatalog.GetCleaningRewards()
	local total = 0
	for _, choice in ipairs(choices) do total += choice.Weight end
	if total <= 0 then return nil end
	local roll = math.random() * total
	for _, choice in ipairs(choices) do
		roll -= choice.Weight
		if roll <= 0 then return choice.Id end
	end
	return choices[#choices].Id
end

local function bindPrompt(partName, actionText, callback)
	local object = Workspace:FindFirstChild(partName, true)
	if not object then warn("[CleaningService] Missing Workspace object: " .. partName); return end
	local part = getPart(object)
	if not part then warn("[CleaningService] No BasePart in " .. partName); return end
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = partName .. "Prompt"
		prompt.ActionText = actionText
		prompt.ObjectText = partName
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
	end
	prompt.Triggered:Connect(callback)
	return object
end

local function startSession(player)
	local data = PlayerDataService.WaitFor(player, 30)
	if not data or not cleaningTable or not near(player, cleaningTable, 12) then
		return false, "세척대 가까이에서 이용해 주세요."
	end
	if not data.Inventory.DirtyBag then
		return false, "손에 든 더러운 토핑이 있어야 세척할 수 있어요."
	end
	sessions[player] = { StartedAt = os.clock(), ExpiresAt = os.clock() + SESSION_SECONDS }
	return true, "토핑 위를 누른 채 드래그하거나 터치해 닿은 곳을 씻고 얼룩을 전부 닦아 주세요."
end

function CleaningService.Init()
	local machine = bindPrompt("ToppingMachine", "더러운 토핑 뽑기", function(player)
		if InventoryService.Count(player, "topping_dirty", "DirtyBag") > 0 then
			RemoteService.Get("InventoryUpdated"):FireClient(player, { Message = "더러운 토핑 가방이 이미 차 있어요. 세척대에서 먼저 씻어 주세요." })
			return
		end
		local ok, reason = InventoryService.Add(player, "topping_dirty", 1, "DirtyBag")
		if not ok then
			RemoteService.Get("InventoryUpdated"):FireClient(player, { Message = reason or "토핑을 받지 못했어요." })
		end
	end)
	cleaningTable = bindPrompt("CleaningTable", "토핑 세척", function(player)
		local ok, message = startSession(player)
		if ok then RemoteService.Get("OpenCleaning"):FireClient(player, true, message) end
	end)

	RemoteService.Get("CleaningAction").OnServerInvoke = function(player, action, strokes)
		local data = PlayerDataService.WaitFor(player, 30)
		if not data or not cleaningTable or not near(player, cleaningTable, 12) then
			return false, "세척대 가까이에서 이용해 주세요."
		end
		if action == "Complete" then
			local session = sessions[player]
			if not session or os.clock() > session.ExpiresAt then sessions[player] = nil; return false, "세척 시간이 만료되었습니다." end
			if os.clock() - session.StartedAt < MIN_CLEAN_SECONDS or (tonumber(strokes) or 0) < 5 then
				return false, "세척을 조금 더 진행해 주세요."
			end
			if not data.Inventory.DirtyBag then sessions[player] = nil; return false, "세척할 더러운 토핑이 없습니다." end
			local rewardId = chooseCleanTopping()
			if not rewardId then return false, "세척 보상 목록이 비어 있습니다." end
			local removed = InventoryService.Remove(player, "topping_dirty", 1, "DirtyBag")
			if not removed then return false, "더러운 토핑을 찾을 수 없습니다." end
			local added, reason = InventoryService.Add(player, rewardId, 1, "Craft")
			if not added then
				InventoryService.Add(player, "topping_dirty", 1, "DirtyBag")
				return false, reason
			end
			sessions[player] = nil
			return true, "세척 완료", rewardId
		end
		return false, "알 수 없는 요청입니다."
	end
	Players.PlayerRemoving:Connect(function(player) sessions[player] = nil end)
end

return CleaningService
