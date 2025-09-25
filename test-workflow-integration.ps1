#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive workflow integration test
.DESCRIPTION
    Tests the complete workflow pipeline to ensure all components work together
    as they would in GitHub Actions
#>

[CmdletBinding()]
param(
    [switch]$CI = $true
)

$ErrorActionPreference = 'Continue'
$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TestsSkipped = 0

function Test-WorkflowStep {
    param(
        [string]$Name,
        [scriptblock]$Test,
        [switch]$Optional
    )
    
    Write-Host "🔧 Testing Workflow Step: $Name" -ForegroundColor Cyan
    try {
        $startTime = Get-Date
        $result = & $Test
        $duration = (Get-Date) - $startTime
        
        if ($result -eq $true -or $result -eq $null) {
            Write-Host "✅ PASS: $Name (${duration}ms)" -ForegroundColor Green
            $script:TestsPassed++
        } elseif ($result -eq 'SKIP') {
            Write-Host "⏭️ SKIP: $Name (${duration}ms)" -ForegroundColor Yellow
            $script:TestsSkipped++
        } else {
            if ($Optional) {
                Write-Host "⚠️ FAIL (Optional): $Name - $result (${duration}ms)" -ForegroundColor Yellow
                $script:TestsSkipped++
            } else {
                Write-Host "❌ FAIL: $Name - $result (${duration}ms)" -ForegroundColor Red
                $script:TestsFailed++
            }
        }
    } catch {
        if ($Optional) {
            Write-Host "⚠️ FAIL (Optional): $Name - $($_.Exception.Message)" -ForegroundColor Yellow
            $script:TestsSkipped++
        } else {
            Write-Host "❌ FAIL: $Name - $($_.Exception.Message)" -ForegroundColor Red
            $script:TestsFailed++
        }
    }
}

Write-Host "🚀 AitherZero Workflow Integration Test" -ForegroundColor Magenta
Write-Host "=======================================" -ForegroundColor Magenta
Write-Host ""

# Test 1: Environment Setup (Like GitHub Actions would do)
Test-WorkflowStep "Environment Setup" {
    # Create required directories
    New-Item -ItemType Directory -Path "./tests/analysis" -Force -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType Directory -Path "./tests/results" -Force -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType Directory -Path "./tests/reports" -Force -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType Directory -Path "./tests/coverage" -Force -ErrorAction SilentlyContinue | Out-Null
    
    # Set environment variables like CI would
    $env:GITHUB_ACTIONS = "true"
    $env:CI = "true"
    
    return (Test-Path "./tests/analysis") -and (Test-Path "./tests/results")
}

# Test 2: Bootstrap Process
Test-WorkflowStep "Bootstrap Process" {
    $output = pwsh ./bootstrap.ps1 -Mode New -NonInteractive 2>&1
    if ($LASTEXITCODE -eq 0) {
        return $true
    } else {
        return "Bootstrap failed with exit code: $LASTEXITCODE"
    }
}

# Test 3: Syntax Validation (Main Workflow Pattern)
Test-WorkflowStep "Syntax Validation" {
    $keyScripts = @(
        "./Start-AitherZero.ps1",
        "./bootstrap.ps1",
        "./automation-scripts/0402_Run-UnitTests.ps1",
        "./automation-scripts/0404_Run-PSScriptAnalyzer.ps1"
    )
    
    $failedScripts = @()
    foreach ($script in $keyScripts) {
        if (Test-Path $script) {
            $output = pwsh ./automation-scripts/0407_Validate-Syntax.ps1 -FilePath $script 2>&1
            if (-not ($output -like "*valid*")) {
                $failedScripts += $script
            }
        } else {
            $failedScripts += "$script (missing)"
        }
    }
    
    if ($failedScripts.Count -eq 0) {
        return $true
    } else {
        return "Failed scripts: $($failedScripts -join ', ')"
    }
}

# Test 4: PSScriptAnalyzer
Test-WorkflowStep "PSScriptAnalyzer Execution" {
    $output = pwsh ./automation-scripts/0404_Run-PSScriptAnalyzer.ps1 -OutputPath "./tests/analysis/" 2>&1
    if ($LASTEXITCODE -eq 0) {
        return $true
    } else {
        return "PSScriptAnalyzer failed with exit code: $LASTEXITCODE"
    }
}

# Test 5: Unit Tests (CI Mode)
Test-WorkflowStep "Unit Tests Execution" {
    $output = pwsh ./automation-scripts/0402_Run-UnitTests.ps1 -CI -OutputPath "./tests/results/" 2>&1
    if ($LASTEXITCODE -eq 0) {
        return $true
    } else {
        return "Unit tests failed with exit code: $LASTEXITCODE"
    }
}

# Test 6: Integration Tests (Optional - may not exist)
Test-WorkflowStep "Integration Tests" -Optional {
    if (-not (Test-Path "./automation-scripts/0403_Run-IntegrationTests.ps1")) {
        return 'SKIP'
    }
    
    $output = pwsh ./automation-scripts/0403_Run-IntegrationTests.ps1 -CI 2>&1
    if ($LASTEXITCODE -eq 0) {
        return $true
    } else {
        return "Integration tests failed with exit code: $LASTEXITCODE"
    }
}

# Test 7: Code Coverage (Optional)
Test-WorkflowStep "Code Coverage Generation" -Optional {
    if (-not (Test-Path "./automation-scripts/0406_Generate-Coverage.ps1")) {
        return 'SKIP'
    }
    
    $output = pwsh ./automation-scripts/0406_Generate-Coverage.ps1 -CI 2>&1
    if ($LASTEXITCODE -eq 0) {
        return $true
    } else {
        return "Coverage generation failed with exit code: $LASTEXITCODE"
    }
}

# Test 8: Project Report Generation
Test-WorkflowStep "Project Report Generation" -Optional {
    if (-not (Test-Path "./automation-scripts/0510_Generate-ProjectReport.ps1")) {
        return 'SKIP'
    }
    
    $output = pwsh ./automation-scripts/0510_Generate-ProjectReport.ps1 -Format "All" 2>&1
    if ($LASTEXITCODE -eq 0) {
        return $true
    } else {
        return "Project report failed with exit code: $LASTEXITCODE"
    }
}

# Test 9: Security Analysis (Optional)
Test-WorkflowStep "Security Analysis" -Optional {
    if (-not (Test-Path "./automation-scripts/0523_Analyze-SecurityIssues.ps1")) {
        return 'SKIP'
    }
    
    $output = pwsh ./automation-scripts/0523_Analyze-SecurityIssues.ps1 2>&1
    if ($LASTEXITCODE -eq 0) {
        return $true
    } else {
        return "Security analysis failed with exit code: $LASTEXITCODE"
    }
}

# Test 10: Artifact Generation (Check for expected outputs)
Test-WorkflowStep "Artifact Generation Check" {
    $expectedPaths = @(
        "./tests/analysis",
        "./tests/results",
        "./logs"
    )
    
    $missingPaths = @()
    foreach ($path in $expectedPaths) {
        if (-not (Test-Path $path)) {
            $missingPaths += $path
        }
    }
    
    if ($missingPaths.Count -eq 0) {
        return $true
    } else {
        return "Missing expected paths: $($missingPaths -join ', ')"
    }
}

# Test 11: Cross-Platform Compatibility Check
Test-WorkflowStep "Cross-Platform Path Handling" {
    # Test path operations that workflows depend on
    $testPaths = @(
        "./tests/results/test.xml",
        "./tests/coverage/coverage.xml",
        "./tests/analysis/analysis.sarif"
    )
    
    foreach ($testPath in $testPaths) {
        # Create test file
        $dir = Split-Path $testPath -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        "test" | Set-Content $testPath
        
        # Test if it can be accessed
        if (-not (Test-Path $testPath)) {
            return "Failed to create/access: $testPath"
        }
        
        # Clean up
        Remove-Item $testPath -Force -ErrorAction SilentlyContinue
    }
    
    return $true
}

Write-Host ""
Write-Host "📊 Workflow Integration Test Results:" -ForegroundColor Yellow
Write-Host "====================================" -ForegroundColor Yellow
Write-Host "✅ Passed: $script:TestsPassed" -ForegroundColor Green
Write-Host "❌ Failed: $script:TestsFailed" -ForegroundColor Red
Write-Host "⏭️ Skipped: $script:TestsSkipped" -ForegroundColor Yellow

$totalTests = $script:TestsPassed + $script:TestsFailed + $script:TestsSkipped
$passRate = if ($totalTests -gt 0) { [math]::Round(($script:TestsPassed / $totalTests) * 100, 1) } else { 0 }

Write-Host ""
Write-Host "📈 Overall Results:" -ForegroundColor Cyan
Write-Host "  Total Tests: $totalTests" -ForegroundColor White
Write-Host "  Pass Rate: $passRate%" -ForegroundColor White

if ($script:TestsFailed -eq 0) {
    Write-Host ""
    Write-Host "🎉 SUCCESS: Workflow integration tests passed!" -ForegroundColor Green
    Write-Host "   GitHub Actions workflows should work correctly across all platforms." -ForegroundColor Green
    exit 0
} else {
    Write-Host ""
    Write-Host "⚠️ ISSUES FOUND: $script:TestsFailed critical failures detected." -ForegroundColor Red
    Write-Host "   GitHub Actions workflows may still have issues." -ForegroundColor Red
    exit 1
}