#!/opt/microsoft/powershell/7/pwsh

Set-Location '/workspaces/AitherZero'

Import-Module ./aither-core/modules/ConfigurationManager -Force

Write-Host "=========================================="
Write-Host "Configuration Manager Module Test"
Write-Host "=========================================="

Write-Host "`nModule loaded successfully!"

Write-Host "`nExported functions:"
Get-Command -Module ConfigurationManager | ForEach-Object { Write-Host "  - $($_.Name)" }

Write-Host "`nTesting Initialize-ConfigurationManager..."
try {
    $result = Initialize-ConfigurationManager
    if ($result.Success) {
        Write-Host "  ✓ Initialization successful"
        Write-Host "  ✓ Version: $($result.Version)"
        Write-Host "  ✓ Configuration Path: $($result.ConfigurationPath)"
    } else {
        Write-Host "  ✗ Initialization failed: $($result.Error)"
    }
} catch {
    Write-Host "  ✗ Initialization error: $_"
}

Write-Host "`nTesting Get-ConfigurationManagerStatus..."
try {
    $status = Get-ConfigurationManagerStatus
    if ($status.Success) {
        Write-Host "  ✓ Status retrieval successful"
        Write-Host "  ✓ Module Version: $($status.ModuleVersion)"
        Write-Host "  ✓ Is Initialized: $($status.IsInitialized)"
        Write-Host "  ✓ Platform: $($status.Platform)"
    } else {
        Write-Host "  ✗ Status retrieval failed: $($status.Error)"
    }
} catch {
    Write-Host "  ✗ Status error: $_"
}

Write-Host "`n=========================================="
Write-Host "Configuration Manager Test Completed"
Write-Host "=========================================="