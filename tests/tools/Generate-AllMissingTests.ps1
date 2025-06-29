#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Generates tests for all modules lacking test coverage
.DESCRIPTION
    Identifies modules without tests and generates comprehensive test suites for each
#>

# Import required modules
. "$PSScriptRoot/../../aither-core/shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot
Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force

# Modules identified as lacking tests
$modulesWithoutTests = @(
    'AIToolsIntegration',
    'ConfigurationCarousel',
    'ConfigurationRepository',
    'OrchestrationEngine',
    'ProgressTracking',
    'RestAPIServer',
    'SystemMonitoring'
)

Write-CustomLog -Level 'INFO' -Message "Starting test generation for $($modulesWithoutTests.Count) modules"

$results = @()

foreach ($moduleName in $modulesWithoutTests) {
    Write-Host ""
    Write-CustomLog -Level 'INFO' -Message "Generating tests for: $moduleName"
    
    $modulePath = Join-Path $projectRoot "aither-core/modules" $moduleName
    
    if (Test-Path $modulePath) {
        try {
            $result = & "$PSScriptRoot/Generate-ModuleTests.ps1" `
                -ModuleName $moduleName `
                -ModulePath $modulePath `
                -Force
                
            $results += $result
            Write-CustomLog -Level 'SUCCESS' -Message "Generated tests for $moduleName"
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to generate tests for $moduleName : $_"
        }
    } else {
        Write-CustomLog -Level 'WARNING' -Message "Module path not found: $modulePath"
    }
}

# Summary
Write-Host ""
Write-Host "Test Generation Summary" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan
Write-Host "Total modules processed: $($modulesWithoutTests.Count)"
Write-Host "Successfully generated: $($results.Count)"
Write-Host "Total tests created: $(($results | Measure-Object -Property TestsGenerated -Sum).Sum)"

# Save results
$summaryPath = Join-Path $projectRoot "tests/results" "test-generation-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$results | ConvertTo-Json -Depth 3 | Set-Content $summaryPath
Write-Host ""
Write-Host "Summary saved to: $summaryPath" -ForegroundColor Green