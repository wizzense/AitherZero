#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Test script to validate workflow fixes
.DESCRIPTION
    Tests the key components that workflows depend on to ensure they work correctly
#>

[CmdletBinding()]
param(
    [switch]$CI
)

$ErrorActionPreference = 'Continue'
$script:TestsPassed = 0
$script:TestsFailed = 0

function Test-Component {
    param(
        [string]$Name,
        [scriptblock]$Test
    )
    
    Write-Host "Testing: $Name" -ForegroundColor Cyan
    try {
        $result = & $Test
        if ($result -eq $true -or $result -eq $null) {
            Write-Host "✅ PASS: $Name" -ForegroundColor Green
            $script:TestsPassed++
        } else {
            Write-Host "❌ FAIL: $Name - $result" -ForegroundColor Red
            $script:TestsFailed++
        }
    } catch {
        Write-Host "❌ FAIL: $Name - $($_.Exception.Message)" -ForegroundColor Red
        $script:TestsFailed++
    }
}

Write-Host "🔍 Testing Workflow Components" -ForegroundColor Yellow
Write-Host "==============================" -ForegroundColor Yellow

# Test 1: Bootstrap script exists and has proper structure
Test-Component "Bootstrap script exists" {
    Test-Path "./bootstrap.ps1"
}

# Test 2: Key automation scripts exist
Test-Component "Unit tests script exists" {
    Test-Path "./automation-scripts/0402_Run-UnitTests.ps1"
}

Test-Component "PSScriptAnalyzer script exists" {
    Test-Path "./automation-scripts/0404_Run-PSScriptAnalyzer.ps1"
}

Test-Component "Syntax validation script exists" {
    Test-Path "./automation-scripts/0407_Validate-Syntax.ps1"
}

# Test 3: Try to run syntax validation 
Test-Component "Syntax validation can run" {
    $output = pwsh ./automation-scripts/0407_Validate-Syntax.ps1 -FilePath "./bootstrap.ps1" 2>&1
    if ($output -like "*valid*") {
        return $true
    } else {
        return "Output: $output"
    }
}

# Test 4: Check for PSScriptAnalyzer without CI parameter
Test-Component "PSScriptAnalyzer accepts correct parameters" {
    $help = Get-Help "./automation-scripts/0404_Run-PSScriptAnalyzer.ps1" -ErrorAction SilentlyContinue
    if ($help.parameters.parameter.name -contains "CI") {
        return "Script incorrectly has CI parameter"
    }
    return $true
}

# Test 5: Check unit tests script parameters
Test-Component "Unit tests script has CI parameter" {
    $help = Get-Help "./automation-scripts/0402_Run-UnitTests.ps1" -ErrorAction SilentlyContinue
    if ($help.parameters.parameter.name -contains "CI") {
        return $true
    } else {
        return "Unit tests script missing CI parameter"
    }
}

# Test 6: Module manifest exists
Test-Component "Module manifest exists" {
    Test-Path "./AitherZero.psd1"
}

# Test 7: Test directories can be created
Test-Component "Test directories can be created" {
    New-Item -ItemType Directory -Path "./tests/analysis" -Force -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType Directory -Path "./tests/results" -Force -ErrorAction SilentlyContinue | Out-Null
    return (Test-Path "./tests/analysis") -and (Test-Path "./tests/results")
}

# Test 8: Bootstrap runs without error
Test-Component "Bootstrap runs successfully" {
    $output = pwsh ./bootstrap.ps1 -Mode New -NonInteractive 2>&1
    if ($LASTEXITCODE -eq 0) {
        return $true
    } else {
        return "Bootstrap failed with exit code: $LASTEXITCODE"
    }
}

Write-Host "`n📊 Test Results:" -ForegroundColor Yellow
Write-Host "=================" -ForegroundColor Yellow
Write-Host "✅ Passed: $script:TestsPassed" -ForegroundColor Green
Write-Host "❌ Failed: $script:TestsFailed" -ForegroundColor Red

if ($script:TestsFailed -gt 0) {
    Write-Host "`n❌ Some tests failed. Workflow issues may still exist." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n✅ All tests passed! Workflows should work correctly." -ForegroundColor Green
    exit 0
}