$basePath = $PWD.Path
Import-Module "$basePath/aither-core/modules/Logging" -Force
Import-Module "$basePath/aither-core/modules/SecureCredentials" -Force
Import-Module "$basePath/aither-core/modules/RemoteConnection" -Force

Write-Host "Testing Get-RemoteConnection return type:"

# Test 1: Direct assignment
$result = Get-RemoteConnection
Write-Host "Test 1 - Assignment result is null: $($result -eq $null)"

# Test 2: Direct pipeline
Write-Host "Test 2 - Pipeline test:"
Get-RemoteConnection | ForEach-Object { Write-Host "Item: $_" }

# Test 3: Capture pipeline
Write-Host "Test 3 - Capture pipeline:"
$captured = @(Get-RemoteConnection)
Write-Host "Captured is null: $($captured -eq $null)"
Write-Host "Captured count: $($captured.Count)"
Write-Host "Captured type: $($captured.GetType().Name)"

# Test array forcing
$forced = @()
Write-Host "Empty array type: $($forced.GetType().Name)"
Write-Host "Empty array is array: $($forced -is [array])"
