#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Windows-specific feature tests for AitherZero
#>

param(
    [string]$OutputPath = '.'
)

# Only run on Windows
if (-not $IsWindows) {
    Write-Host "Skipping Windows-specific tests on non-Windows platform" -ForegroundColor Yellow
    exit 0
}

Write-Host "Running Windows-specific tests..." -ForegroundColor Cyan

$results = @{
    Platform = 'Windows'
    TestedAt = Get-Date
    Tests = @()
}

# Test 1: PowerShell version
$test1 = @{
    Name = 'PowerShell Version'
    Status = 'Failed'
    Details = ''
}

try {
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $test1.Status = 'Passed'
        $test1.Details = "PowerShell $($PSVersionTable.PSVersion)"
    } else {
        $test1.Details = "PowerShell $($PSVersionTable.PSVersion) - Version 7+ required"
    }
} catch {
    $test1.Details = "Error: $_"
}
$results.Tests += $test1

# Test 2: Hyper-V availability
$test2 = @{
    Name = 'Hyper-V Feature'
    Status = 'Failed'
    Details = ''
}

try {
    $hyperv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
    if ($hyperv -and $hyperv.State -eq 'Enabled') {
        $test2.Status = 'Passed'
        $test2.Details = 'Hyper-V is enabled'
    } else {
        $test2.Status = 'Skipped'
        $test2.Details = 'Hyper-V not enabled (optional)'
    }
} catch {
    $test2.Status = 'Skipped'
    $test2.Details = 'Cannot check Hyper-V status (may require admin)'
}
$results.Tests += $test2

# Test 3: Windows directory structure
$test3 = @{
    Name = 'Windows Paths'
    Status = 'Failed'
    Details = ''
}

try {
    $requiredPaths = @(
        $env:ProgramFiles,
        $env:USERPROFILE,
        $env:TEMP
    )
    
    $missingPaths = $requiredPaths | Where-Object { -not (Test-Path $_) }
    if ($missingPaths.Count -eq 0) {
        $test3.Status = 'Passed'
        $test3.Details = 'All standard Windows paths exist'
    } else {
        $test3.Details = "Missing paths: $($missingPaths -join ', ')"
    }
} catch {
    $test3.Details = "Error: $_"
}
$results.Tests += $test3

# Save results
$outputFile = Join-Path $OutputPath "windows-test-results.json"
$results | ConvertTo-Json -Depth 10 | Set-Content -Path $outputFile

# Display summary
Write-Host "`nWindows Feature Test Summary:" -ForegroundColor White
$passed = ($results.Tests | Where-Object { $_.Status -eq 'Passed' }).Count
$failed = ($results.Tests | Where-Object { $_.Status -eq 'Failed' }).Count
$skipped = ($results.Tests | Where-Object { $_.Status -eq 'Skipped' }).Count

Write-Host "  Passed: $passed" -ForegroundColor Green
Write-Host "  Failed: $failed" -ForegroundColor Red
Write-Host "  Skipped: $skipped" -ForegroundColor Yellow

# Exit with appropriate code
if ($failed -gt 0) {
    exit 1
} else {
    exit 0
}