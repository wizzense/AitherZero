$manifest = Import-PowerShellDataFile '/workspaces/AitherZero/aither-core/modules/SecurityAutomation/SecurityAutomation.psd1'
$expectedFunctions = $manifest.FunctionsToExport
Import-Module /workspaces/AitherZero/aither-core/modules/SecurityAutomation -Force
$actualFunctions = (Get-Module SecurityAutomation).ExportedFunctions.Keys
$missingFunctions = $expectedFunctions | Where-Object { $_ -notin $actualFunctions }
Write-Host "Missing functions:" -ForegroundColor Red
$missingFunctions
Write-Host "Expected: $($expectedFunctions.Count)" -ForegroundColor Yellow
Write-Host "Actual: $($actualFunctions.Count)" -ForegroundColor Yellow