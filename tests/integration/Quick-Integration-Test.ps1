#!/usr/bin/env pwsh
# Quick Integration Test for AitherCore Domain System
# Agent 3 Mission: Integration Testing Architect

#Requires -Version 7.0

Write-Host "🔬 Starting Quick Integration Test for AitherCore Domain System" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# Test Results Collection
$testResults = @{
    StartTime = Get-Date
    Tests = @()
    Summary = @{
        Total = 0
        Passed = 0
        Failed = 0
    }
}

function Test-Step {
    param(
        [string]$Name,
        [scriptblock]$Test
    )
    
    $testResults.Summary.Total++
    Write-Host "🧪 Testing: $Name" -ForegroundColor Yellow
    
    try {
        $result = & $Test
        if ($result) {
            Write-Host "✅ PASSED: $Name" -ForegroundColor Green
            $testResults.Summary.Passed++
            $testResults.Tests += @{ Name = $Name; Result = "PASSED"; Details = $result }
        } else {
            Write-Host "❌ FAILED: $Name - No result returned" -ForegroundColor Red
            $testResults.Summary.Failed++
            $testResults.Tests += @{ Name = $Name; Result = "FAILED"; Details = "No result returned" }
        }
    } catch {
        Write-Host "❌ FAILED: $Name - $($_.Exception.Message)" -ForegroundColor Red
        $testResults.Summary.Failed++
        $testResults.Tests += @{ Name = $Name; Result = "FAILED"; Details = $_.Exception.Message }
    }
}

# Test 1: AitherCore Module Import
Test-Step "AitherCore Module Import" {
    try {
        Import-Module './aither-core/AitherCore.psm1' -Force
        $module = Get-Module AitherCore
        return $module -ne $null
    } catch {
        throw "Failed to import AitherCore module: $_"
    }
}

# Test 2: Write-CustomLog Availability
Test-Step "Write-CustomLog Availability" {
    $logCmd = Get-Command Write-CustomLog -ErrorAction SilentlyContinue
    if ($logCmd) {
        Write-CustomLog -Message "Integration test log message" -Level "INFO"
        return $true
    }
    return $false
}

# Test 3: Domain Initialization
Test-Step "Domain Initialization" {
    try {
        $result = Initialize-CoreApplication -RequiredOnly
        return $result -eq $true
    } catch {
        throw "Failed to initialize core application: $_"
    }
}

# Test 4: Module Status Retrieval
Test-Step "Module Status Retrieval" {
    try {
        $status = Get-CoreModuleStatus
        $domains = $status | Where-Object { $_.Type -eq 'Domain' }
        $modules = $status | Where-Object { $_.Type -eq 'Module' }
        
        Write-Host "   Found $($domains.Count) domains and $($modules.Count) modules" -ForegroundColor Gray
        return $status.Count -gt 0
    } catch {
        throw "Failed to get module status: $_"
    }
}

# Test 5: Configuration System
Test-Step "Configuration System" {
    try {
        $configCmd = Get-Command Get-ConfigurationStore -ErrorAction SilentlyContinue
        if ($configCmd) {
            $config = Get-ConfigurationStore
            return $config -ne $null
        }
        return $false
    } catch {
        throw "Failed to test configuration system: $_"
    }
}

# Test 6: Infrastructure Domain Functions
Test-Step "Infrastructure Domain Functions" {
    try {
        $labStatusCmd = Get-Command Get-LabStatus -ErrorAction SilentlyContinue
        if ($labStatusCmd) {
            $labStatus = Get-LabStatus
            return $labStatus -ne $null
        }
        return $false
    } catch {
        throw "Failed to test infrastructure domain: $_"
    }
}

# Test 7: Module Communication System
Test-Step "Module Communication System" {
    try {
        $apiCmd = Get-Command Register-ModuleAPI -ErrorAction SilentlyContinue
        if ($apiCmd) {
            Register-ModuleAPI -ModuleName "TestModule" -APIVersion "1.0.0" -Endpoints @("test")
            return $true
        }
        return $false
    } catch {
        throw "Failed to test module communication: $_"
    }
}

# Test 8: Event System
Test-Step "Event System" {
    try {
        $eventCmd = Get-Command Publish-ConfigurationEvent -ErrorAction SilentlyContinue
        if ($eventCmd) {
            Publish-ConfigurationEvent -EventName "TestEvent" -EventData @{ Test = "Data" }
            return $true
        }
        return $false
    } catch {
        throw "Failed to test event system: $_"
    }
}

# Test 9: Cross-Domain Integration
Test-Step "Cross-Domain Integration" {
    try {
        # Test that infrastructure can access configuration
        $configCmd = Get-Command Get-ConfigurationStore -ErrorAction SilentlyContinue
        $labCmd = Get-Command Get-LabStatus -ErrorAction SilentlyContinue
        
        if ($configCmd -and $labCmd) {
            $config = Get-ConfigurationStore
            $lab = Get-LabStatus -ErrorAction SilentlyContinue
            return $config -ne $null
        }
        return $false
    } catch {
        throw "Failed to test cross-domain integration: $_"
    }
}

# Test 10: Health Check
Test-Step "Health Check" {
    try {
        $healthResult = Test-CoreApplicationHealth
        return $healthResult -eq $true
    } catch {
        throw "Failed to test application health: $_"
    }
}

# Generate Final Report
$testResults.EndTime = Get-Date
$testResults.Duration = $testResults.EndTime - $testResults.StartTime
$successRate = if ($testResults.Summary.Total -gt 0) { 
    ($testResults.Summary.Passed / $testResults.Summary.Total) * 100 
} else { 0 }

Write-Host "`n" -NoNewline
Write-Host "╔═══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                           INTEGRATION TEST REPORT                            ║" -ForegroundColor Cyan
Write-Host "╠═══════════════════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "║ Test Summary:                                                                 ║" -ForegroundColor Yellow
Write-Host "║   Total Tests: $($testResults.Summary.Total.ToString().PadLeft(2))                                                           ║" -ForegroundColor White
Write-Host "║   Passed: $($testResults.Summary.Passed.ToString().PadLeft(2))                                                            ║" -ForegroundColor Green
Write-Host "║   Failed: $($testResults.Summary.Failed.ToString().PadLeft(2))                                                            ║" -ForegroundColor Red
Write-Host "║   Success Rate: $([math]::Round($successRate, 1).ToString().PadLeft(5))%                                                ║" -ForegroundColor Cyan
Write-Host "║   Duration: $($testResults.Duration.ToString().PadRight(15))                                     ║" -ForegroundColor Gray
Write-Host "╠═══════════════════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "║ Test Details:                                                                 ║" -ForegroundColor Yellow

foreach ($test in $testResults.Tests) {
    $status = if ($test.Result -eq "PASSED") { "✅" } else { "❌" }
    $name = $test.Name.PadRight(40)
    $result = $test.Result.PadLeft(6)
    Write-Host "║ $status $name $result                          ║" -ForegroundColor White
}

Write-Host "╚═══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# Save results to file
$resultsPath = "./test-results/quick-integration-results.json"
$resultsDir = Split-Path $resultsPath -Parent
if (-not (Test-Path $resultsDir)) {
    New-Item -Path $resultsDir -ItemType Directory -Force | Out-Null
}

$testResults | ConvertTo-Json -Depth 10 | Set-Content -Path $resultsPath
Write-Host "📄 Detailed results saved to: $resultsPath" -ForegroundColor Green

# Exit with appropriate code
if ($testResults.Summary.Failed -gt 0) {
    Write-Host "❌ Some tests failed. Integration test result: FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ All tests passed. Integration test result: PASSED" -ForegroundColor Green
    exit 0
}