local services = script.Parent:WaitForChild("Services")

local RemoteService = require(services:WaitForChild("RemoteService"))
RemoteService.Init()

local startupOrder = {
	"WorldSetupService",
	"PlayerDataService",
	"PlotService",
	"CurrencyService",
	"InventoryService",
	"CollectionBookService",
	"CleaningService",
	"DisplayShelfService",
	"MaterialShelfService",
	"SlimePlacementService",
	"BasePlacementService",
	"SlimePadIncomeService",
	"WorkerService",
	"PumpService",
	"GachaService",
	"ZoneService",
	"RebirthService",
}

for _, serviceName in ipairs(startupOrder) do
	print("[SlimeGame] Initializing " .. serviceName)
	local ok, result = xpcall(function()
		local service = require(services:WaitForChild(serviceName))
		if service.Init then service.Init() end
	end, debug.traceback)
	if ok then
		print("[SlimeGame] Ready " .. serviceName)
	else
		warn("[SlimeGame] Failed " .. serviceName .. ": " .. tostring(result))
	end
end

print("[SlimeGame] Services initialized")
