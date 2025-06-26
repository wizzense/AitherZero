#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests for launcher functionality
.DESCRIPTION
    This test validates that the main launcher and core script work correctly.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Initialize test environment
$TestResults = @{
    Passed = 0
    Failed = 0
    Errors = @()
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$ErrorMsg = ''
    )

    if ($Passed) {
        Write-Host "✅ $TestName" -ForegroundColor Green
        $script:TestResults.Passed++
    } else {
        Write-Host "❌ $TestName" -ForegroundColor Red
        if ($ErrorMsg) {
            Write-Host "   Error: $ErrorMsg" -ForegroundColor Yellow
        }
        $script:TestResults.Failed++
        $script:TestResults.Errors += "$TestName`: $ErrorMsg"
    }
}

function Test-LauncherHelp {
    param([string]$LauncherPath)

    try {
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = "pwsh"
        $processInfo.Arguments = "-ExecutionPolicy Bypass -File `"$LauncherPath`" -Help"
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $process.Start() | Out-Null

        $finished = $process.WaitForExit(5000)
        
        if (-not $finished) {
            $process.Kill()
            return @{ Success = $false; ErrorMsg = "Help command timed out" }
        }

        $output = $process.StandardOutput.ReadToEnd()
        $exitCode = $process.ExitCode

        if ($exitCode -eq 0 -and $output -match 'Usage|Help|Options|AitherZero') {
            return @{ Success = $true; ErrorMsg = '' }
        } else {
            return @{ Success = $false; ErrorMsg = "Help output failed. Exit code: $exitCode" }
        }
    } catch {
        return @{ Success = $false; ErrorMsg = $_.Exception.Message }
    }
}

function Test-ParameterMapping {
    param([string]$LauncherPath)

    try {
        $content = Get-Content $LauncherPath -Raw
        
        # Check for hashtable initialization
        if ($content -match '\$coreArgs\s*=\s*@\{\}') {
            return $true
        } else {
            return $false
        }
    } catch {
        return $false
    }
}

# Main test execution
Write-Host '🧪 Launcher Tests' -ForegroundColor Cyan
Write-Host '=================' -ForegroundColor Cyan

$projectRoot = Split-Path $PSScriptRoot -Parent
$mainLauncher = Join-Path $projectRoot 'templates/launchers/Start-AitherZero.ps1'
$coreScript = Join-Path $projectRoot 'aither-core/aither-core.ps1'

# Test 1: File exists
$existsLauncher = Test-Path $mainLauncher
Write-TestResult "Main launcher exists" $existsLauncher

$existsCoreScript = Test-Path $coreScript
Write-TestResult "Core script exists" $existsCoreScript

if ($existsLauncher) {
    # Test 2: Help works
    $helpResult = Test-LauncherHelp $mainLauncher
    Write-TestResult "Help parameter works" $helpResult.Success $helpResult.ErrorMsg
    
    # Test 3: Parameter mapping
    $mappingResult = Test-ParameterMapping $mainLauncher
    Write-TestResult "Parameter mapping correct" $mappingResult
}

# Results
Write-Host "`n📊 Results:" -ForegroundColor Cyan
Write-Host "✅ Passed: $($TestResults.Passed)" -ForegroundColor Green
Write-Host "❌ Failed: $($TestResults.Failed)" -ForegroundColor Red

if ($TestResults.Failed -gt 0) {
    exit 1
} else {
    Write-Host "`n🎉 All tests passed!" -ForegroundColor Green
    Write-Host "All launcher tests passed" -ForegroundColor Green
    exit 0
}
