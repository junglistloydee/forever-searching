$ErrorActionPreference = 'Stop'
$buildScript = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'build.ps1')
$patternLine = @($buildScript | Where-Object { $_.StartsWith('$forbidden = ') })
if ($patternLine.Count -ne 1) { throw 'Expected one release safety pattern' }
# Evaluate only the checked-in regex assignment, never addon or provider data.
. ([scriptblock]::Create($patternLine[0]))
$dangerous = @(
    'SetBinding("CTRL-F", "X")', 'local save = SaveBindings', 'local profile = LoadBindings',
    'local bind = SetOverrideBindingClick', 'ClearOverrideBindings(frame)',
    'ResetToDefaultBindings()', 'SetCurrentBindingSet(1)',
    'local write = SetCVar', 'ResetCVars()', 'local config = C_CVar',
    'local layout = C_EditMode', 'C_Console.RunCommand("x")',
    'local keys = C_KeyBindings', 'C_VideoOptions.Set(1)',
    'ResetChatWindows()', 'FCF_ResetChatWindows()', 'ConsoleExec("x")',
    'Sound_GameSystem_RestartSoundSystem()', 'SetScreenResolution(1)',
    'RestartGx()', 'ResetVideoSettings()', 'local eval = loadstring',
    'loadfile("x")', 'dofile("x")', 'RunScript("x")', 'RunMacroText("x")',
    'BuyMerchantItem(1,2)', 'local buy = BuybackItem'
)
foreach ($example in $dangerous) {
    if ($example -notmatch $forbidden) { throw "Release guard missed: $example" }
}
foreach ($example in @('NS.ui:SetScale(1)', 'NS.db.settings.sort = "name"', 'NS.RememberSearch("vendor")')) {
    if ($example -match $forbidden) { throw "Release guard rejected addon-local operation: $example" }
}
Write-Output "PASS: release guard rejects $($dangerous.Count) unsafe API/alias examples and permits addon-local operations"
$transmogPatternLine = @($buildScript | Where-Object { $_.StartsWith('$transmogForbidden = ') })
if ($transmogPatternLine.Count -ne 1) { throw 'Expected one transmog safety pattern' }
. ([scriptblock]::Create($transmogPatternLine[0]))
$transmogDangerous = @('api.CommitAndApplyAllPending()', 'local pay = C_TransmogOutfitInfo.CommitAndApplyAllPending',
    'C_TransmogCollection.SetClassFilter(2)', 'C_TransmogCollection.SetSearch("x")',
    'C_TransmogCollection.SetUncollectedShown(true)', 'C_TransmogCollection.SaveCustomSet()',
    'C_TransmogOutfitInfo.ChangeDisplayedOutfit(1)', 'C_TransmogOutfitInfo.SetOutfitSituationsEnabled(true)',
    'C_TransmogOutfitInfo.SetViewedOutfit(1)', 'C_TransmogOutfitInfo.SetSecondarySlotState(1,true)',
    'EquipItemByName(1)', 'EquipCursorItem(1)', 'PickupInventoryItem(1)')
foreach ($example in $transmogDangerous) {
    if ($example -notmatch $transmogForbidden) { throw "Transmog release guard missed: $example" }
}
foreach ($example in @('api.SetPendingTransmog(0,0,12,101,1)', 'C_TransmogCollection.GetSourceInfo(101)', 'model:TryOn(101)')) {
    if ($example -match $transmogForbidden) { throw "Transmog guard rejected permitted operation: $example" }
}
Write-Output "PASS: transmog release guard rejects $($transmogDangerous.Count) commit/filter/gear-write examples and permits preview/pending operations"
