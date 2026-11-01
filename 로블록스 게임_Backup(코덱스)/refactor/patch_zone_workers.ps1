$ErrorActionPreference = 'Stop'
$encoding = [System.Text.Encoding]::GetEncoding(949)
$path = Join-Path $PSScriptRoot 'SlimeZoneServer.luau'
$text = [System.IO.File]::ReadAllText($path, $encoding)

$spawnPattern = '(?s)local function spawnWorker\(player\).*?\r?\nend'
$spawnReplacement = @'
local function spawnWorker(player)
    local data = getPlayerData(player)
    local runtime = getRuntime(player)
    local playerPlot = findPlayerPlot(player)
    if not data or not runtime or not playerPlot then return nil end

    local workerFolder = playerPlot:FindFirstChild("Worker")
    if not workerFolder then
        workerFolder = Instance.new("Folder")
        workerFolder.Name = "Worker"
        workerFolder.Parent = playerPlot
    end

    local workerIndex = #runtime.SpawnedWorkers + 1
    local workerName = "Worker_" .. workerIndex
    local worker = workerFolder:FindFirstChild(workerName)
    if not worker then
        local template = ReplicatedStorage:FindFirstChild("WorkerTemplate")
        if not template then
            template = Instance.new("Model")
            template.Name = "WorkerTemplate"
            local rootPart = Instance.new("Part")
            rootPart.Name = "HumanoidRootPart"
            rootPart.Size = Vector3.new(2, 2, 2)
            rootPart.Shape = Enum.PartType.Ball
            rootPart.Color = Color3.fromRGB(100, 220, 100)
            rootPart.Parent = template
            Instance.new("Humanoid").Parent = template
            template.PrimaryPart = rootPart
        end

        worker = template:Clone()
        worker.Name = workerName
        worker:SetAttribute("WorkerLevel", worker:GetAttribute("WorkerLevel") or 1)
        worker:SetAttribute("GoldMultiplier", worker:GetAttribute("GoldMultiplier") or 1)
        worker:SetAttribute("WalkSpeed", worker:GetAttribute("WalkSpeed") or 12)
        local zone1 = playerPlot:FindFirstChild("SlimeZone") and playerPlot.SlimeZone:FindFirstChild("Zone_1")
        local spawnCFrame = zone1 and (zone1.CFrame * CFrame.new(0, 3, 0)) or CFrame.new(0, 5, 0)
        worker:PivotTo(spawnCFrame)
        worker.Parent = workerFolder
    end

    table.insert(runtime.SpawnedWorkers, worker)
    data.Workers.Owned = workerIndex
    startWorkerAI(player, worker)
    return worker
end
'@
$matches = [regex]::Matches($text, $spawnPattern)
if ($matches.Count -ne 1) { throw "Expected one spawnWorker function, found $($matches.Count)." }
$text = [regex]::Replace($text, $spawnPattern, $spawnReplacement, 1)

$initializeIndex = $text.IndexOf('local function initializePlayer')
$setupEnd = $text.LastIndexOf("end`r`n", $initializeIndex)
if ($setupEnd -lt 0) { throw 'Could not locate setupPlayerHousing end.' }
$restore = @'
    for _ = 1, (data.Workers.Owned or 0) do
        if not spawnWorker(player) then break end
    end
'@ -replace "`n", "`r`n"
$text = $text.Insert($setupEnd, $restore)
[System.IO.File]::WriteAllText($path, $text, $encoding)
