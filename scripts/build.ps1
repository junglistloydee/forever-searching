param([string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$addonRoot = Join-Path $projectRoot 'ForeverSearching'
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $projectRoot 'dist' }
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$versionMatch = Select-String -LiteralPath (Join-Path $addonRoot 'ForeverSearching.toc') -Pattern '^## Version: (.+)$'
$version = $versionMatch.Matches[0].Groups[1].Value.Trim()
$outputPath = Join-Path $outputDirectory "ForeverSearching-$version.zip"
$files = @('ForeverSearching.toc', 'ForeverSearching_Camelot.toc', 'Work.lua', 'Controls.lua', 'Data.lua', 'Evidence.lua', 'Distance.lua', 'Settings.lua', 'ItemText.lua', 'Sources.lua', 'Personal.lua', 'Results.lua', 'QuestDetails.lua', 'Merchants.lua', 'Transmog.lua', 'VendorProfiles.lua', 'Links.lua', 'Navigation.lua', 'ShoppingRoute.lua', 'Core.lua', 'ToolsUI.lua', 'TransmogUI.lua', 'UI.lua', 'README.md', 'LICENSE')
# Refuse to package a return of the APIs involved in the binding incident,
# global game-settings writes, or executable data loaders.
if (Test-Path -LiteralPath (Join-Path $addonRoot 'Bindings.xml')) { throw 'Bindings.xml must not be shipped' }
$forbidden = '\b(SetBinding\w*|SaveBindings|LoadBindings|SetOverrideBinding\w*|ClearOverrideBindings|RunBinding|ResetBindings|ResetToDefaultBindings|SetCVar\w*|ResetCVar\w*|ConsoleExec|RunScript|RunMacro\w*|loadstring|loadfile|dofile|SetScreenResolution|RestartGx|ResetVideoSettings|ResetChatWindows|FCF_ResetChatWindows|SetCurrentBindingSet|Sound_GameSystem_RestartSoundSystem|BuyMerchantItem|BuybackItem)\b|\bC_(CVar|EditMode|VideoOptions|Console|KeyBindings)\b'
$unsafe = Select-String -LiteralPath (Get-ChildItem -LiteralPath $addonRoot -File -Filter '*.lua').FullName -Pattern $forbidden
if ($unsafe) { throw "Forbidden game-settings/binding/purchase/evaluation API in release: $($unsafe.Path -join ', ')" }
$transmogForbidden = '\b(CommitAndApply\w*|EquipItemByName|EquipCursorItem|PickupInventoryItem|PickupContainerItem)\b|\bC_TransmogCollection\s*\.\s*(Set\w*|Save\w*|Delete\w*|Rename\w*|Create\w*)\b|\bC_TransmogOutfitInfo\s*\.\s*(ChangeDisplayedOutfit|SetOutfit\w*|SetViewed\w*|SetSecondarySlotState|SetPendingTransmogSheatheCategory)\b'
$unsafeTransmog = Select-String -LiteralPath (Get-ChildItem -LiteralPath $addonRoot -File -Filter '*.lua').FullName -Pattern $transmogForbidden
if ($unsafeTransmog) { throw "Forbidden transmog commit, filter/settings or gear write in release: $($unsafeTransmog.Path -join ', ')" }
foreach ($tocName in @('ForeverSearching.toc', 'ForeverSearching_Camelot.toc')) {
    $tocLines = Get-Content -LiteralPath (Join-Path $addonRoot $tocName)
    $savedVariables = @($tocLines | Where-Object { $_ -match '^## SavedVariables' })
    if ($savedVariables.Count -ne 1 -or $savedVariables[0] -ne '## SavedVariables: ForeverSearchingDB') {
        throw "Unexpected SavedVariables declaration in $tocName"
    }
    foreach ($line in $tocLines) {
        $module = $line.Trim()
        if ($module -and -not $module.StartsWith('#') -and
            ($module -notin $files -or -not $module.EndsWith('.lua') -or -not (Test-Path -LiteralPath (Join-Path $addonRoot $module)))) {
            throw "Unpackaged or unexpected TOC module in ${tocName}: $module"
        }
    }
}
Add-Type -AssemblyName System.IO.Compression
$stream = [System.IO.File]::Open($outputPath, [System.IO.FileMode]::Create)
$archive = [System.IO.Compression.ZipArchive]::new($stream, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in $files) {
        $entry = $archive.CreateEntry("ForeverSearching/$file", [System.IO.Compression.CompressionLevel]::Optimal)
        $entryStream = $entry.Open()
        $sourcePath = if ($file -in @('README.md', 'LICENSE')) { Join-Path $projectRoot $file } else { Join-Path $addonRoot $file }
        $inputStream = [System.IO.File]::OpenRead($sourcePath)
        try { $inputStream.CopyTo($entryStream) }
        finally { $inputStream.Dispose(); $entryStream.Dispose() }
    }
}
finally { $archive.Dispose(); $stream.Dispose() }
Write-Output "Built $outputPath"
