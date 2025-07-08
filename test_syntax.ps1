try {
    pwsh -NoProfile -Command "Test-Path '/workspaces/AitherZero/aither-core/modules/SecurityAutomation/Public/SystemManagement/Get-SystemSecurityInventory.ps1' -IsValid"
} catch {
    Write-Host "Error: $($_.Exception.Message)"
}