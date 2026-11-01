$ErrorActionPreference = 'Stop'
$enc = [System.Text.Encoding]::GetEncoding(949)

function Update-LegacyFile($Path, $Transform) {
    $full = Join-Path $PSScriptRoot $Path
    $text = [System.IO.File]::ReadAllText($full, $enc)
    $text = & $Transform $text
    [System.IO.File]::WriteAllText($full, $text, $enc)
}

Update-LegacyFile 'SlimeZoneServer.luau' {
    param($text)
    $text = $text.Replace("local TweenService = game:GetService(`"TweenService`")`r`n", "local TweenService = game:GetService(`"TweenService`")`r`nlocal PlayerDataService = require(script.Parent:WaitForChild(`"PlayerDataService`"))`r`n")

    $pattern = '(?s)local playerData = \{\}.*?(?=local function getLeaderstat)'
    $replacement = @'
local function getPlayerData(player)
    return PlayerDataService.WaitForData(player, 30)
end

local function getRuntime(player)
    return PlayerDataService.GetRuntime(player)
end

'@
    $text = [regex]::Replace($text, $pattern, $replacement, 1)

    $text = $text.Replace("local function getLeaderstat(player, statName)`r`n`tlocal stats = player:FindFirstChild(`"leaderstats`")`r`n`treturn stats and stats:FindFirstChild(statName)`r`nend", @'
local function getLeaderstat(player, statName)
    local stats = player:FindFirstChild("leaderstats")
    return stats and stats:FindFirstChild(statName)
end

local function findPlayerPlot(player)
    local housingPlots = Workspace:FindFirstChild("HousingPlots")
    if not housingPlots then return nil end

    for _, plot in ipairs(housingPlots:GetChildren()) do
        if plot:GetAttribute("OwnerUserId") == player.UserId then
            return plot
        end
    end

    local plots = housingPlots:GetChildren()
    if #plots == 1 and plots[1]:GetAttribute("OwnerUserId") == nil then
        return plots[1]
    end
    return nil
end
'@)

    $text = $text.Replace("`tdata.ActivePads", "`truntime.ActivePads")
    $text = $text.Replace("table.insert(data.ActivePads, pad)", "table.insert(runtime.ActivePads, pad)")
    $text = $text.Replace("local data = getPlayerData(player)`r`n`tdata.ActivePads = {}", "local data = getPlayerData(player)`r`n`tlocal runtime = getRuntime(player)`r`n`tif not data or not runtime then return end`r`n`truntime.ActivePads = {}")
    $text = $text.Replace("local data = getPlayerData(player)`r`n`t`t`tlocal validPads = runtime.ActivePads or {}", "local data = getPlayerData(player)`r`n`t`t`tlocal runtime = getRuntime(player)`r`n`t`t`tif not data or not runtime then break end`r`n`t`t`tlocal validPads = runtime.ActivePads or {}")
    $text = $text.Replace("local goldStat = getLeaderstat(player, GOLD_STAT_NAME)`r`n`t`t`t`t`tif goldStat then`r`n`t`t`t`t`t`tlocal bonusMultiplier = 1 + (data.RebirthCount * 0.5)`r`n`t`t`t`t`t`tgoldStat.Value = goldStat.Value + math.floor(BASE_GOLD_PER_PAD * bonusMultiplier)`r`n`t`t`t`t`tend", "local bonusMultiplier = data.WorkerIncomeMultiplier or 1`r`n`t`t`t`t`tPlayerDataService.AddGold(player, math.floor(BASE_GOLD_PER_PAD * bonusMultiplier))")
    $text = $text.Replace("local data = getPlayerData(player)`r`n`tlocal housingPlots = Workspace:FindFirstChild(`"HousingPlots`")`r`n`tif not housingPlots then return end`r`n`r`n`tlocal playerPlot = housingPlots:FindFirstChild(`"PlayerHousing_1`")", "local data = getPlayerData(player)`r`n`tlocal runtime = getRuntime(player)`r`n`tif not data or not runtime then return end`r`n`tlocal playerPlot = findPlayerPlot(player)")
    $text = $text.Replace("newWorker.Name = `"Worker_`" .. (#data.SpawnedWorkers + 1)", "newWorker.Name = `"Worker_`" .. (#runtime.SpawnedWorkers + 1)")
    $text = $text.Replace("table.insert(data.SpawnedWorkers, newWorker)", "table.insert(runtime.SpawnedWorkers, newWorker)")
    $text = $text.Replace("local playerPlot = housingPlots:FindFirstChild(`"PlayerHousing_1`")", "local playerPlot = findPlayerPlot(player)")
    $text = $text.Replace("for zoneName, config in pairs(ZONE_CONFIG) do`r`n`t`tlocal zonePart = slimeZoneFolder:FindFirstChild(zoneName)`r`n`t`tif zonePart then`r`n`t`t`tif config.DefaultUnlocked then", "for zoneName, config in pairs(ZONE_CONFIG) do`r`n`t`tlocal zonePart = slimeZoneFolder:FindFirstChild(zoneName)`r`n`t`tif zonePart then`r`n`t`t`tif config.DefaultUnlocked or data.UnlockedZones[zoneName] then")
    $text = $text.Replace("`t`t`t`t`t`tlocal goldStat = getLeaderstat(buyer, GOLD_STAT_NAME)`r`n`t`t`t`t`t`tif goldStat and goldStat.Value >= config.Price then`r`n`t`t`t`t`t`t`tgoldStat.Value = goldStat.Value - config.Price`r`n`t`t`t`t`t`t`tunlockZone(player, playerPlot, zonePart, config)`r`n`t`t`t`t`t`tend", "`t`t`t`t`t`tif PlayerDataService.SpendGold(buyer, config.Price) then`r`n`t`t`t`t`t`t`tunlockZone(player, playerPlot, zonePart, config)`r`n`t`t`t`t`t`tend")

    $playerAdded = '(?s)Players\.PlayerAdded:Connect\(function\(player\)\).*?\nend\)'
    $playerAddedReplacement = @'
Players.PlayerAdded:Connect(function(player)
    local data = PlayerDataService.WaitForData(player, 30)
    if not data then return end
    setupPlayerHousing(player)
end)
'@
    $text = [regex]::Replace($text, $playerAdded, $playerAddedReplacement, 1)

    $text = $text.Replace("`tlocal data = getPlayerData(player)`r`n`tlocal goldStat = getLeaderstat(player, GOLD_STAT_NAME)`r`n`r`n`tif action == `"BuyWorker`" then`r`n`t`tlocal maxAllowedWorkers = data.RebirthCount + 1`r`n`t`tif #data.SpawnedWorkers >= maxAllowedWorkers then return end`r`n`t`tlocal price = WORKER_BASE_PRICE * (#data.SpawnedWorkers + 1)`r`n`t`tif goldStat and goldStat.Value >= price then`r`n`t`t`tgoldStat.Value = goldStat.Value - price`r`n`t`t`	spawnWorker(player)`r`n`t`tend`r`n`tend", @'
    local data = getPlayerData(player)
    local runtime = getRuntime(player)
    if not data or not runtime then return end

    if action == "BuyWorker" then
        local maxAllowedWorkers = 1 + (data.MaxWorkerBonus or data.RebirthCount)
        if #runtime.SpawnedWorkers >= maxAllowedWorkers then return end
        local price = WORKER_BASE_PRICE * (#runtime.SpawnedWorkers + 1)
        if PlayerDataService.SpendGold(player, price) then
            spawnWorker(player)
        end
    end
'@)
    $text = [regex]::Replace($text, 'Players\.PlayerRemoving:Connect\(function\(player\) playerData\[player\.UserId\] = nil end\)\r?\n?', '')
    return $text
}

Update-LegacyFile 'SlimeZoneServer.luau' {
    param($text)
    $text = [regex]::Replace($text, '(?m)^local PlayerDataService = require\(script\.Parent:WaitForChild\("PlayerDataService"\)\)\r?\n', '', 5)
    $text = $text.Replace('local TweenService = game:GetService("TweenService")' + "`r`n", 'local TweenService = game:GetService("TweenService")' + "`r`n" + 'local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))' + "`r`n" + 'local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))' + "`r`n")
    $text = [regex]::Replace($text, '(?s)local ZONE_CONFIG = \{.*?\n\}', '', 1)
    $text = $text.Replace('pairs(ZONE_CONFIG)', 'pairs(ZoneConfig)')
    $text = [regex]::Replace($text, '(?s)local function getLeaderstat\(player, statName\).*?\nend\r?\n\r?\n', '', 1)
    $text = [regex]::Replace($text, '(?m)^\s*local data = getPlayerData\(player\)\r?\n\s*local runtime = getRuntime\(player\)\r?\n\s*if not data or not runtime then return end\r?\n\s*local playerPlot = findPlayerPlot\(player\)', '    local data = getPlayerData(player)' + "`r`n" + '    if not data then return end' + "`r`n" + '    local playerPlot = findPlayerPlot(player)', 1)
    return $text
}

Update-LegacyFile 'SlimeZoneServer.luau' {
    param($text)
    $text = [regex]::Replace($text, '(?s)Players\.PlayerAdded:Connect\(function\(player\).*?end\)', @'
Players.PlayerAdded:Connect(function(player)
    local data = PlayerDataService.WaitForData(player, 30)
    if not data then return end
    task.wait(1)
    setupPlayerHousing(player)
end)
'@, 1)
    $text = $text.Replace('local GOLD_STAT_NAME = "Gold"' + "`r`n" + 'local REBIRTH_STAT_NAME = "Rebirth"' + "`r`n", '')
    $text = $text.Replace('local MAX_REBIRTH_LIMIT = 10' + "`r`n", '')
    $text = $text.Replace('local REBIRTH_BASE_PRICE = 1000' + "`r`n", '')
    return $text
}

Update-LegacyFile 'SlimeZoneServer.luau' {
    param($text)

    $text = [regex]::Replace($text, '(?s)local function refreshActivePads\(player, housingPlot\).*?(?=local function startWorkerAI)', @'
local function refreshActivePads(player, housingPlot)
    local data = getPlayerData(player)
    local runtime = getRuntime(player)
    if not data or not runtime then return end
    runtime.ActivePads = {}

    local slimeZoneFolder = housingPlot:FindFirstChild("SlimeZone")
    if not slimeZoneFolder then return end
    for zoneName, isUnlocked in pairs(data.UnlockedZones) do
        if isUnlocked then
            local zonePart = slimeZoneFolder:FindFirstChild(zoneName)
            local padsFolder = zonePart and zonePart:FindFirstChild("SlimePads")
            if padsFolder then
                for _, pad in ipairs(padsFolder:GetChildren()) do
                    if pad:IsA("BasePart") then table.insert(runtime.ActivePads, pad) end
                end
            end
        end
    end
end

'@, 1)

    $text = [regex]::Replace($text, '(?s)local function startWorkerAI\(player, workerModel\).*?(?=local function spawnWorker)', @'
local function startWorkerAI(player, workerModel)
    local humanoid = workerModel:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    for _, part in ipairs(workerModel:GetDescendants()) do
        if part:IsA("BasePart") then part.Anchored = false end
    end

    task.spawn(function()
        while workerModel.Parent and player.Parent do
            local data = getPlayerData(player)
            local runtime = getRuntime(player)
            if not data or not runtime then break end
            local pads = runtime.ActivePads
            if #pads > 0 then
                local targetPad = pads[math.random(1, #pads)]
                if targetPad.Parent then
                    humanoid:MoveTo(targetPad.Position)
                    if humanoid.MoveToFinished:Wait() then
                        local multiplier = data.WorkerIncomeMultiplier or 1
                        PlayerDataService.AddGold(player, math.floor(BASE_GOLD_PER_PAD * multiplier))
                        local originalSize = targetPad.Size
                        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
                        local tweenUp = TweenService:Create(targetPad, tweenInfo, { Size = originalSize + Vector3.new(0.2, 0.2, 0.2) })
                        local tweenDown = TweenService:Create(targetPad, tweenInfo, { Size = originalSize })
                        tweenUp:Play()
                        tweenUp.Completed:Wait()
                        if targetPad.Parent then tweenDown:Play() end
                    end
                end
            end
            task.wait(math.random(1, 3))
        end
    end)
end

'@, 1)

    $text = [regex]::Replace($text, '(?s)function setupPlayerHousing\(player\).*?(?=Players\.PlayerAdded:Connect)', @'
local function setupPlayerHousing(player)
    local data = getPlayerData(player)
    local playerPlot = findPlayerPlot(player)
    if not data or not playerPlot then return end
    local slimeZoneFolder = playerPlot:FindFirstChild("SlimeZone")
    if not slimeZoneFolder then return end

    for zoneName, config in pairs(ZONE_CONFIG) do
        local zonePart = slimeZoneFolder:FindFirstChild(zoneName)
        if zonePart then
            if config.DefaultUnlocked or data.UnlockedZones[zoneName] then
                unlockZone(player, playerPlot, zonePart, config)
            else
                zonePart.Transparency = 0.8
                zonePart.CanCollide = false
                local unlockPad = zonePart:FindFirstChild("UnlockPad")
                if unlockPad then
                    local prompt = unlockPad:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt", unlockPad)
                    prompt.ObjectText = zoneName .. " 구매"
                    prompt.ActionText = config.Price .. " Gold (E)"
                    prompt.HoldDuration = 0.5
                    prompt.RequiresLineOfSight = false
                    prompt.Triggered:Connect(function(buyer)
                        if buyer == player and PlayerDataService.SpendGold(buyer, config.Price) then
                            unlockZone(player, playerPlot, zonePart, config)
                        end
                    end)
                end
            end
        end
    end
end

'@, 1)

    $text = [regex]::Replace($text, '(?s)Players\.PlayerAdded:Connect\(function\(player\)\).*?\nend\)', @'
Players.PlayerAdded:Connect(function(player)
    local data = PlayerDataService.WaitForData(player, 30)
    if not data then return end
    setupPlayerHousing(player)
end)
'@, 1)
    return $text
}
