$ErrorActionPreference = 'Stop'

$workspace = 'C:\Users\ma912\Documents\ChatGPT\로블록스 게임'
$sourceFolder = 'D:\로블록스 게임 제작\구'
$inputModel = Join-Path $workspace 'slime game 202610.review.rbxmx'
$outputModel = Join-Path $workspace 'slime game 202610.reviewed.rbxmx'

$xml = [System.Xml.XmlDocument]::new()
$xml.PreserveWhitespace = $true
$xml.Load($inputModel)

function Get-ItemName($item) {

    $nameNode = $item.SelectSingleNode('./Properties/*[@name="Name"]')
    if ($nameNode) { return $nameNode.InnerText }
    return ''
}

function Get-ItemPath($item) {

    $segments = [System.Collections.Generic.List[string]]::new()
    $node = $item
    while ($node -and $node.Name -eq 'Item') {
        $name = Get-ItemName $node
        if ($name) { $segments.Insert(0, $name) }
        $node = $node.ParentNode
    }
    return ($segments -join '/')
}

function Set-Source($item, [string]$source) {

    if ($source.Contains(']]>')) {
        throw "Source contains a CDATA terminator: $(Get-ItemName $item)"
    }
    $sourceNode = $item.SelectSingleNode('./Properties/*[@name="Source"]')
    if (-not $sourceNode) { throw "Missing Source property: $(Get-ItemName $item)" }
    while ($sourceNode.HasChildNodes) {
        [void]$sourceNode.RemoveChild($sourceNode.FirstChild)
    }
    [void]$sourceNode.AppendChild($xml.CreateCDataSection($source))
}

$sourceTargets = @{
    'BagDataModule.luau' = 'ReplicatedStorage/BagDataModule'
    'CleaningClientController.luau' = 'StarterGui/ToppingCleaningGui/CleaningClientController'
    'DisplayShelfController.luau' = 'StarterGui/ToppingCleaningGui/DisplayShelfController'
    'DisplayShelfServer.luau' = 'ServerScriptService/DisplayShelfServer'
    'InventoryClientController.luau' = 'StarterGui/InventoryGui/InventoryClientController'
    'ItemDataModule.luau' = 'ReplicatedStorage/ItemDataModule'
    'PlayerDataService.luau' = 'ServerScriptService/PlayerDataService'
    'RebirthClientController.luau' = 'StarterGui/RebirthGui/RebirthClientController'
    'RebirthConfig.luau' = 'ReplicatedStorage/RebirthConfig'
    'RebirthService.luau' = 'ServerScriptService/RebirthService'
    'SlimePhysicalController.luau' = 'StarterPlayer/StarterCharacterScripts/SlimePhysicalController'
    'SlimePvpService.luau' = 'ServerScriptService/SlimePvpService'
    'SlimeZoneServer.luau' = 'ServerScriptService/SlimeZoneServer'
    'ToppingCleaningService.luau' = 'ServerScriptService/ToppingCleaningService'
    'ToppingClickHandler.luau' = 'StarterPlayer/StarterPlayerScripts/ToppingClickHandler'
    'WorkerShopGui.luau' = 'StarterGui/WorkerShopGui'
    'WorkerSlimeService.luau' = 'ServerScriptService/WorkerSlimeService'
    'ZoneConfig.luau' = 'ReplicatedStorage/ZoneConfig'
}

$replaced = [System.Collections.Generic.List[string]]::new()
foreach ($entry in $sourceTargets.GetEnumerator()) {
    $sourcePath = Join-Path $sourceFolder $entry.Key
    if (-not (Test-Path -LiteralPath $sourcePath)) { throw "Missing loose source: $sourcePath" }
    $target = $null
    foreach ($item in $xml.SelectNodes('//Item')) {
        if ((Get-ItemPath $item) -eq $entry.Value) { $target = $item; break }
    }
    if (-not $target) { throw "Missing model target: $($entry.Value)" }

    $source = [System.IO.File]::ReadAllText($sourcePath, [System.Text.Encoding]::UTF8)
    if ($entry.Key -eq 'RebirthConfig.luau') {
        # The config is an additive per-rebirth worker-slot reward.
        $source = $source -replace '(?m)(\[2\]\s*=\s*\{[\s\S]*?MaxWorkerBonus\s*=\s*)2(\s*,)', '${1}1${2}'
    }
    Set-Source $target $source
    $replaced.Add($entry.Value)
}

# Discard direct DataModel children duplicated by their intended service copies.
$duplicateNames = @(
    'PlayerDataService', 'DataManager', 'ToppingCleaningService', 'SlimeZoneServer',
    'SlimePvpService', 'WorkerSlimeService', 'RebirthService', 'DisplayShelfServer'
)
foreach ($rootItem in @($xml.DocumentElement.SelectNodes('./Item'))) {
    if ($duplicateNames -contains (Get-ItemName $rootItem)) {
        [void]$xml.DocumentElement.RemoveChild($rootItem)
    }
}

# DataManager is an empty module and has no references in the supplied scripts.
$dataManager = $null
foreach ($item in $xml.SelectNodes('//Item')) {
    if ((Get-ItemPath $item) -eq 'ServerScriptService/DataManager') {
        $dataManager = $item
        break
    }
}
if ($dataManager) { [void]$dataManager.ParentNode.RemoveChild($dataManager) }

# Give the shelf controller its own ScreenGui instead of sharing the cleaning GUI.
$starterGui = $null
$shelfController = $null
foreach ($item in $xml.SelectNodes('//Item')) {
    $path = Get-ItemPath $item
    if ($path -eq 'StarterGui') { $starterGui = $item }
    if ($path -eq 'StarterGui/ToppingCleaningGui/DisplayShelfController') { $shelfController = $item }
}
if (-not $starterGui -or -not $shelfController) { throw 'Could not isolate the display shelf controller.' }
$shelfGui = $xml.CreateElement('Item')
$shelfGui.SetAttribute('class', 'ScreenGui')
$shelfGui.SetAttribute('referent', 'RBX' + [guid]::NewGuid().ToString('N').ToUpperInvariant())
$properties = $xml.CreateElement('Properties')
$enabled = $xml.CreateElement('bool'); $enabled.SetAttribute('name', 'Enabled'); $enabled.InnerText = 'true'
$reset = $xml.CreateElement('bool'); $reset.SetAttribute('name', 'ResetOnSpawn'); $reset.InnerText = 'false'
$name = $xml.CreateElement('string'); $name.SetAttribute('name', 'Name'); $name.InnerText = 'DisplayShelfGui'
[void]$properties.AppendChild($enabled)
[void]$properties.AppendChild($reset)
[void]$properties.AppendChild($name)
[void]$shelfGui.AppendChild($properties)
[void]$starterGui.AppendChild($shelfGui)
[void]$shelfGui.AppendChild($shelfController)

$xml.Save($outputModel)

# Re-open the output and summarize the active script layout for inspection.
$check = [System.Xml.XmlDocument]::new()
$check.Load($outputModel)
$checkItems = @($check.SelectNodes('//Item'))
$scriptItems = @($check.SelectNodes('//Item[@class="Script" or @class="LocalScript" or @class="ModuleScript"]'))
"Created: $outputModel"
"Instances: $($checkItems.Count)"
"Script containers: $($scriptItems.Count)"
"Updated sources: $($replaced.Count)"
"Display shelf GUI path: $((Get-ItemPath $shelfController))"
