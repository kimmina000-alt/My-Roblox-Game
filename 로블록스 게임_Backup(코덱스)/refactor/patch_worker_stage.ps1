$ErrorActionPreference = 'Stop'
$path = Join-Path $PSScriptRoot 'WorkerSlimeService.luau'
$encoding = [System.Text.Encoding]::GetEncoding(949)
$text = [System.IO.File]::ReadAllText($path, $encoding)

$needle = 'local ReplicatedStorage = game:GetService("ReplicatedStorage")'
$text = $text.Replace($needle, $needle + "`r`n" + 'local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))')

$text = [regex]::Replace($text, '(?s)local ownerUserId = housingFolder:GetAttribute\("OwnerUserId"\).*?\n\s*end\n\s*-- 3\.', @'
                local ownerUserId = housingFolder:GetAttribute("OwnerUserId")
                local owner = ownerUserId and Players:GetPlayerByUserId(ownerUserId)
                if owner then
                    local data = PlayerDataService.GetData(owner)
                    local incomeMultiplier = data and data.WorkerIncomeMultiplier or 1
                    local finalGold = math.floor(earnedGold * incomeMultiplier)
                    PlayerDataService.AddGold(owner, finalGold)
                    showFloatingGoldText(rootPart, finalGold)
                end
                -- 3.
'@, 1)

$text = [regex]::Replace($text, '(?s)upgradeWorkerEvent\.OnServerEvent:Connect\(function\(player, upgradeType\).*?\nend\)', @'
upgradeWorkerEvent.OnServerEvent:Connect(function(player, upgradeType)
    local data = PlayerDataService.GetData(player)
    if not data then return end

    local housingPlots = workspace:FindFirstChild("HousingPlots")
    if not housingPlots then return end
    local playerHousing
    for _, plot in ipairs(housingPlots:GetChildren()) do
        if plot:GetAttribute("OwnerUserId") == player.UserId then
            playerHousing = plot
            break
        end
    end
    if not playerHousing then
        local plots = housingPlots:GetChildren()
        if #plots == 1 and plots[1]:GetAttribute("OwnerUserId") == nil then
            playerHousing = plots[1]
        end
    end
    local worker = playerHousing and (playerHousing:FindFirstChild("WorkerSlime") or playerHousing:FindFirstChild("Worker"))
    if not worker then return end

    if upgradeType == "Speed" then
        local currentSpeed = worker:GetAttribute("WalkSpeed") or 12
        local cost = math.floor(currentSpeed * 15)
        if PlayerDataService.SpendGold(player, cost) then
            worker:SetAttribute("WalkSpeed", currentSpeed + 4)
        end
    elseif upgradeType == "Level" then
        local currentLevel = worker:GetAttribute("WorkerLevel") or 1
        local cost = currentLevel * 100
        if PlayerDataService.SpendGold(player, cost) then
            worker:SetAttribute("WorkerLevel", currentLevel + 1)
        end
    end
end)
'@, 1)

# The two old plot-registration blocks started the same worker loop twice.
$text = [regex]::Replace($text, '(?s)local housingPlotsFolder = workspace:WaitForChild\("HousingPlots", 10\) or workspace\r?\nfor _, plot in ipairs\(housingPlotsFolder:GetChildren\(\)\) do startWorkerLoop\(plot\) end\r?\nhousingPlotsFolder.ChildAdded:Connect\(startWorkerLoop\)\r?\n.*?local housingPlotsFolder = workspace:WaitForChild\("HousingPlots", 10\) or workspace', 'local housingPlotsFolder = workspace:WaitForChild("HousingPlots", 10) or workspace', 1)
$text = [regex]::Replace($text, 'local function onHousingAdded\(housingFolder\)\r?\n\s*if housingFolder:IsA\("Folder"\) or housingFolder:IsA\("Model"\) then\r?\n\s*startWorkerLoop\(housingFolder\)\r?\n\s*end\r?\nend', @'
local function onHousingAdded(housingFolder)
    if housingFolder:IsA("Folder") or housingFolder:IsA("Model") then
        task.defer(function()
            if housingFolder:FindFirstChild("WorkerSlime") and housingFolder:FindFirstChild("SlimePads") then
                startWorkerLoop(housingFolder)
            end
        end)
    end
end
'@, 1)

[System.IO.File]::WriteAllText($path, $text, $encoding)
