$ErrorActionPreference = 'Stop'
$encoding = [System.Text.Encoding]::GetEncoding(949)
$backup = 'D:\로블록스 게임 제작\구\_codex_backup_20261002_all\WorkerSlimeService.luau'
$path = Join-Path $PSScriptRoot 'WorkerSlimeService.luau'
Copy-Item -LiteralPath $backup -Destination $path -Force
$text = [System.IO.File]::ReadAllText($path, $encoding)

$requireLine = 'local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))'
if (-not $text.Contains($requireLine)) {
	$text = $text.Replace('local ReplicatedStorage = game:GetService("ReplicatedStorage")', 'local ReplicatedStorage = game:GetService("ReplicatedStorage")' + "`r`n" + $requireLine)
}

$payoutMatch = [regex]::Match($text, '(?m)^\t{4}local ownerUserId = housingFolder:GetAttribute\("OwnerUserId"\)\r?$')
if (-not $payoutMatch.Success) { throw 'Could not find the worker payout block.' }
$start = $payoutMatch.Index
$marker = $text.IndexOf('-- 3.', $start)
if ($marker -lt 0) { throw 'Could not find the end of the worker payout block.' }
$lineStart = $text.LastIndexOf("`r`n", $marker)
if ($lineStart -lt $start) { throw 'Could not find payout block boundary.' }
$replacement = @'
                local ownerUserId = housingFolder:GetAttribute("OwnerUserId")
                local owner = ownerUserId and Players:GetPlayerByUserId(ownerUserId)
                if owner then
                    local data = PlayerDataService.GetData(owner)
                    local incomeMultiplier = data and data.WorkerIncomeMultiplier or 1
                    local finalGold = math.floor(earnedGold * incomeMultiplier)
                    PlayerDataService.AddGold(owner, finalGold)
                    showFloatingGoldText(rootPart, finalGold)
                end
'@ -replace "`n", "`r`n"
$replacement += "`r`n"
$text = $text.Substring(0, $start) + $replacement + $text.Substring($lineStart + 2)

$upgradePattern = '(?s)upgradeWorkerEvent\.OnServerEvent:Connect\(function\(player, upgradeType\).*?\r?\nend\)'
$upgradeReplacement = @'
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
        if #plots == 1 and plots[1]:GetAttribute("OwnerUserId") == nil then playerHousing = plots[1] end
    end
    local worker = playerHousing and playerHousing:FindFirstChild("WorkerSlime")
    if not worker then return end

    if upgradeType == "Speed" then
        local currentSpeed = worker:GetAttribute("WalkSpeed") or 12
        if PlayerDataService.SpendGold(player, math.floor(currentSpeed * 15)) then
            worker:SetAttribute("WalkSpeed", currentSpeed + 4)
        end
    elseif upgradeType == "Level" then
        local currentLevel = worker:GetAttribute("WorkerLevel") or 1
        if PlayerDataService.SpendGold(player, currentLevel * 100) then
            worker:SetAttribute("WorkerLevel", currentLevel + 1)
        end
    end
end)
'@
$matches = [regex]::Matches($text, $upgradePattern)
if ($matches.Count -ne 1) { throw "Expected one upgrade handler, found $($matches.Count)." }
$text = [regex]::Replace($text, $upgradePattern, $upgradeReplacement, 1)
[System.IO.File]::WriteAllText($path, $text, $encoding)
