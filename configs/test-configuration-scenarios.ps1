#Requires -Version 7.0

<#
.SYNOPSIS
    Test script for validating the consolidated configuration system
.DESCRIPTION
    Tests multiple configuration scenarios to ensure the system works correctly
#>

param(
    [switch]$Verbose
)

# Import the configuration system
. "$PSScriptRoot/../aither-core/shared/Initialize-ConsolidatedConfiguration.ps1"

function Test-ConfigurationScenario {
    param(
        [string]$ScenarioName,
        [hashtable]$Parameters
    )
    
    Write-Host "🧪 Testing: $ScenarioName" -ForegroundColor Cyan
    
    try {
        $result = Initialize-AitherZeroConfiguration @Parameters
        
        $tests = @(
            @{ Name = "Configuration Loaded"; Condition = $result -ne $null },
            @{ Name = "Has Legacy Format"; Condition = $result.Legacy -ne $null },
            @{ Name = "Has Metadata"; Condition = $result.Metadata -ne $null },
            @{ Name = "System Type Set"; Condition = $result.Metadata.System -ne $null }
        )
        
        $passed = 0
        $total = $tests.Count
        
        foreach ($test in $tests) {
            if ($test.Condition) {
                Write-Host "  ✅ $($test.Name)" -ForegroundColor Green
                $passed++
            } else {
                Write-Host "  ❌ $($test.Name)" -ForegroundColor Red
            }
        }
        
        $success = ($passed -eq $total)
        $status = if ($success) { "PASS" } else { "FAIL" }
        $color = if ($success) { "Green" } else { "Red" }
        
        Write-Host "  📊 Result: $status ($passed/$total tests passed)" -ForegroundColor $color
        
        if ($Verbose -and $result) {
            Write-Host "  📋 Details:" -ForegroundColor Gray
            Write-Host "    System: $($result.Metadata.System)" -ForegroundColor Gray
            Write-Host "    Environment: $($result.Metadata.Environment)" -ForegroundColor Gray
            Write-Host "    Profile: $($result.Metadata.Profile)" -ForegroundColor Gray
            Write-Host "    Config Keys: $($result.Legacy.Keys.Count)" -ForegroundColor Gray
        }
        
        return @{ Success = $success; Passed = $passed; Total = $total; Result = $result }
        
    } catch {
        Write-Host "  💥 ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return @{ Success = $false; Passed = 0; Total = 0; Error = $_.Exception.Message }
    }
    
    Write-Host ""
}

# Main test execution
Write-Host "🚀 AitherZero Configuration System Validation" -ForegroundColor Yellow
Write-Host "=" * 60
Write-Host ""

$scenarios = @(
    @{
        Name = "Default Configuration (No Parameters)"
        Parameters = @{}
    },
    @{
        Name = "Development Environment"
        Parameters = @{ Environment = 'dev' }
    },
    @{
        Name = "Developer Profile"
        Parameters = @{ Environment = 'dev'; Profile = 'developer' }
    },
    @{
        Name = "Minimal Profile"
        Parameters = @{ Environment = 'dev'; Profile = 'minimal' }
    },
    @{
        Name = "Enterprise Profile"
        Parameters = @{ Environment = 'prod'; Profile = 'enterprise' }
    },
    @{
        Name = "Legacy ConfigFile Parameter"
        Parameters = @{ ConfigFile = "$PSScriptRoot/default-config.json" }
    }
)

$results = @()

foreach ($scenario in $scenarios) {
    $result = Test-ConfigurationScenario -ScenarioName $scenario.Name -Parameters $scenario.Parameters
    $results += $result
}

# Summary
Write-Host "📊 VALIDATION SUMMARY" -ForegroundColor Yellow
Write-Host "=" * 60

$totalScenarios = $results.Count
$passedScenarios = ($results | Where-Object { $_.Success }).Count
$failedScenarios = $totalScenarios - $passedScenarios

Write-Host "Total Scenarios: $totalScenarios" -ForegroundColor White
Write-Host "Passed: $passedScenarios" -ForegroundColor Green
Write-Host "Failed: $failedScenarios" -ForegroundColor Red

$overallSuccess = ($failedScenarios -eq 0)
$overallStatus = if ($overallSuccess) { "✅ ALL TESTS PASSED" } else { "❌ SOME TESTS FAILED" }
$overallColor = if ($overallSuccess) { "Green" } else { "Red" }

Write-Host ""
Write-Host $overallStatus -ForegroundColor $overallColor

if ($failedScenarios -gt 0) {
    Write-Host ""
    Write-Host "Failed scenarios:" -ForegroundColor Red
    for ($i = 0; $i -lt $results.Count; $i++) {
        if (-not $results[$i].Success) {
            Write-Host "  • $($scenarios[$i].Name)" -ForegroundColor Red
            if ($results[$i].Error) {
                Write-Host "    Error: $($results[$i].Error)" -ForegroundColor Gray
            }
        }
    }
}

Write-Host ""
Write-Host "🎯 Configuration System Status: $(if ($overallSuccess) { 'READY FOR v0.8.0' } else { 'NEEDS FIXES' })" -ForegroundColor $(if ($overallSuccess) { 'Green' } else { 'Red' })

return $overallSuccess