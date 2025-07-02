#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Linux-specific feature tests for AitherZero
#>

param(
    [string]$OutputPath = '.'
)

# Only run on Linux
if (-not $IsLinux) {
    Write-Host "Skipping Linux-specific tests on non-Linux platform" -ForegroundColor Yellow
    exit 0
}

Write-Host "Running Linux-specific tests..." -ForegroundColor Cyan

$results = @{
    Platform = 'Linux'
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

# Test 2: Package manager availability
$test2 = @{
    Name = 'Package Manager'
    Status = 'Failed'
    Details = ''
}

try {
    $packageManagers = @('apt', 'yum', 'dnf', 'pacman', 'zypper')
    $found = $null
    
    foreach ($pm in $packageManagers) {
        if (Get-Command $pm -ErrorAction SilentlyContinue) {
            $found = $pm
            break
        }
    }
    
    if ($found) {
        $test2.Status = 'Passed'
        $test2.Details = "Package manager: $found"
    } else {
        $test2.Details = 'No supported package manager found'
    }
} catch {
    $test2.Details = "Error: $_"
}
$results.Tests += $test2

# Test 3: Linux directory structure
$test3 = @{
    Name = 'Linux Paths'
    Status = 'Failed'
    Details = ''
}

try {
    $requiredPaths = @(
        '/etc',
        '/usr',
        '/home',
        '/tmp'
    )
    
    $missingPaths = $requiredPaths | Where-Object { -not (Test-Path $_) }
    if ($missingPaths.Count -eq 0) {
        $test3.Status = 'Passed'
        $test3.Details = 'All standard Linux paths exist'
    } else {
        $test3.Details = "Missing paths: $($missingPaths -join ', ')"
    }
} catch {
    $test3.Details = "Error: $_"
}
$results.Tests += $test3

# Test 4: systemd availability (optional)
$test4 = @{
    Name = 'systemd'
    Status = 'Failed'
    Details = ''
}

try {
    if (Get-Command systemctl -ErrorAction SilentlyContinue) {
        $test4.Status = 'Passed'
        $test4.Details = 'systemd is available'
    } else {
        $test4.Status = 'Skipped'
        $test4.Details = 'systemd not available (optional)'
    }
} catch {
    $test4.Status = 'Skipped'
    $test4.Details = 'Cannot check systemd status'
}
$results.Tests += $test4

# Save results
$outputFile = Join-Path $OutputPath "linux-test-results.json"
$results | ConvertTo-Json -Depth 10 | Set-Content -Path $outputFile

# Display summary
Write-Host "`nLinux Feature Test Summary:" -ForegroundColor White
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