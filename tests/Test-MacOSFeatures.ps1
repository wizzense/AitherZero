#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    macOS-specific feature tests for AitherZero
#>

param(
    [string]$OutputPath = '.'
)

# Only run on macOS
if (-not $IsMacOS) {
    Write-Host "Skipping macOS-specific tests on non-macOS platform" -ForegroundColor Yellow
    exit 0
}

Write-Host "Running macOS-specific tests..." -ForegroundColor Cyan

$results = @{
    Platform = 'macOS'
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

# Test 2: Homebrew availability
$test2 = @{
    Name = 'Homebrew'
    Status = 'Failed'
    Details = ''
}

try {
    if (Get-Command brew -ErrorAction SilentlyContinue) {
        $test2.Status = 'Passed'
        $test2.Details = 'Homebrew is installed'
    } else {
        $test2.Status = 'Skipped'
        $test2.Details = 'Homebrew not installed (optional)'
    }
} catch {
    $test2.Status = 'Skipped'
    $test2.Details = 'Cannot check Homebrew status'
}
$results.Tests += $test2

# Test 3: macOS directory structure
$test3 = @{
    Name = 'macOS Paths'
    Status = 'Failed'
    Details = ''
}

try {
    $requiredPaths = @(
        '/Applications',
        '/Users',
        '/System',
        '/Library'
    )
    
    $missingPaths = $requiredPaths | Where-Object { -not (Test-Path $_) }
    if ($missingPaths.Count -eq 0) {
        $test3.Status = 'Passed'
        $test3.Details = 'All standard macOS paths exist'
    } else {
        $test3.Details = "Missing paths: $($missingPaths -join ', ')"
    }
} catch {
    $test3.Details = "Error: $_"
}
$results.Tests += $test3

# Test 4: launchd availability
$test4 = @{
    Name = 'launchd'
    Status = 'Failed'
    Details = ''
}

try {
    if (Get-Command launchctl -ErrorAction SilentlyContinue) {
        $test4.Status = 'Passed'
        $test4.Details = 'launchd is available'
    } else {
        $test4.Details = 'launchd not found'
    }
} catch {
    $test4.Details = "Error: $_"
}
$results.Tests += $test4

# Save results
$outputFile = Join-Path $OutputPath "macos-test-results.json"
$results | ConvertTo-Json -Depth 10 | Set-Content -Path $outputFile

# Display summary
Write-Host "`nmacOS Feature Test Summary:" -ForegroundColor White
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