#!/usr/bin/env pwsh

# Module Validation Test Script
# Tests all consolidated modules for functionality

$ErrorActionPreference = 'Stop'
Set-Location '/workspaces/AitherZero'

# List of key modules to test
$ModulesToTest = @(
    'ConfigurationCore',
    'PatchManager',
    'OpenTofuProvider',
    'BackupManager',
    'DevEnvironment',
    'LabRunner',
    'ModuleCommunication',
    'SecurityAutomation',
    'StartupExperience',
    'SystemMonitoring',
    'TestingFramework'
)

$Results = @()

foreach ($Module in $ModulesToTest) {
    $ModulePath = "./aither-core/modules/$Module"
    
    if (Test-Path $ModulePath) {
        try {
            Write-Host "Testing module: $Module" -ForegroundColor Green
            
            # Import module
            $ImportedModule = Import-Module $ModulePath -Force -PassThru
            
            # Get command count
            $Commands = Get-Command -Module $Module
            $CommandCount = $Commands.Count
            
            # Test basic functionality
            $FunctionNames = $Commands.Name -join ', '
            
            $Results += [PSCustomObject]@{
                ModuleName = $Module
                Status = 'Success'
                CommandCount = $CommandCount
                Version = $ImportedModule.Version
                FirstFewCommands = ($Commands | Select-Object -First 5).Name -join ', '
                Error = $null
            }
            
            Write-Host "  ✓ Loaded successfully with $CommandCount commands" -ForegroundColor Green
            
        } catch {
            $Results += [PSCustomObject]@{
                ModuleName = $Module
                Status = 'Failed'
                CommandCount = 0
                Version = $null
                FirstFewCommands = $null
                Error = $_.Exception.Message
            }
            Write-Host "  ✗ Failed to load: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  ✗ Module path not found: $ModulePath" -ForegroundColor Yellow
        $Results += [PSCustomObject]@{
            ModuleName = $Module
            Status = 'NotFound'
            CommandCount = 0
            Version = $null
            FirstFewCommands = $null
            Error = "Module path not found"
        }
    }
}

# Display results
Write-Host "`n=== MODULE VALIDATION RESULTS ===" -ForegroundColor Cyan
$Results | Format-Table -AutoSize

# Summary
$SuccessCount = ($Results | Where-Object { $_.Status -eq 'Success' }).Count
$FailedCount = ($Results | Where-Object { $_.Status -eq 'Failed' }).Count
$NotFoundCount = ($Results | Where-Object { $_.Status -eq 'NotFound' }).Count

Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "✓ Successful: $SuccessCount" -ForegroundColor Green
Write-Host "✗ Failed: $FailedCount" -ForegroundColor Red
Write-Host "⚠ Not Found: $NotFoundCount" -ForegroundColor Yellow
Write-Host "Total Commands: $(($Results | Where-Object { $_.Status -eq 'Success' } | Measure-Object -Property CommandCount -Sum).Sum)"

# Export results
$Results | ConvertTo-Json -Depth 3 | Out-File './docs/module-validation-results.json'
Write-Host "`nResults exported to: ./docs/module-validation-results.json"