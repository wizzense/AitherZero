$filePath = "/workspaces/AitherZero/aither-core/modules/SecurityAutomation/Public/SystemManagement/Get-SystemSecurityInventory.ps1"
$content = Get-Content $filePath -Raw
$openBraces = ($content.ToCharArray() | Where-Object { $_ -eq '{' }).Count
$closeBraces = ($content.ToCharArray() | Where-Object { $_ -eq '}' }).Count
Write-Host "Open braces: $openBraces"
Write-Host "Close braces: $closeBraces"
Write-Host "Balance: $($openBraces - $closeBraces)"