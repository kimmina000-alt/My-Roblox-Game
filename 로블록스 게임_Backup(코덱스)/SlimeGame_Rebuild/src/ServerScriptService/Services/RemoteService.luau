local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteService = {}
local folder

local REMOTE_CLASSES = {
	RequestInventory = "RemoteFunction",
	RequestCollectionBook = "RemoteFunction",
	InventoryUpdated = "RemoteEvent",
	RequestRebirth = "RemoteFunction",
	ToggleAura = "RemoteFunction",
	WorkerAction = "RemoteFunction",
	CleaningAction = "RemoteFunction",
	DisplayShelfAction = "RemoteFunction",
	OpenDisplayShelf = "RemoteEvent",
	MaterialShelfAction = "RemoteFunction",
	OpenMaterialShelf = "RemoteEvent",
	GachaAction = "RemoteFunction",
	PumpAction = "RemoteFunction",
	PlaceTopping = "RemoteFunction",
	PlaceBase = "RemoteFunction",
	ZoneAction = "RemoteFunction",
	OpenCleaning = "RemoteEvent",
	OpenPump = "RemoteEvent",
	PadIncomeFeedback = "RemoteEvent",
	WorkerIncomeFeedback = "RemoteEvent",
	WorkerSelectionChanged = "RemoteEvent",
	RequestBaseRetrieve = "RemoteEvent",
	SetHeldTopping = "RemoteFunction",
}

function RemoteService.Init()
	folder = ReplicatedStorage:FindFirstChild("SlimeGameRemotes")
	if folder and not folder:IsA("Folder") then
		error("ReplicatedStorage.SlimeGameRemotes must be a Folder")
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "SlimeGameRemotes"
		folder.Parent = ReplicatedStorage
	end

	for name, className in pairs(REMOTE_CLASSES) do
		local remote = folder:FindFirstChild(name)
		if remote and not remote:IsA(className) then
			error(("Remote %s must be a %s"):format(name, className))
		end
		if not remote then
			remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
	end
	return folder
end

function RemoteService.Get(name)
	assert(folder, "RemoteService.Init() must run first")
	local remote = folder:FindFirstChild(name)
	assert(remote, "Unknown remote: " .. tostring(name))
	return remote
end

return RemoteService
