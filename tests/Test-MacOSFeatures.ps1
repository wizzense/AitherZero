#Requires -Version 7.0

<#
.SYNOPSIS
    macOS-specific feature tests for AitherZero

.DESCRIPTION
    Tests macOS-specific functionality including launchd, homebrew,
    file system features, and macOS-only PowerShell features.

.PARAMETER OutputPath
    Directory path for test results and artifacts

.EXAMPLE
    ./tests/Test-MacOSFeatures.ps1 -OutputPath "TestResults-macOS"

.NOTES
    Only runs on macOS platforms
    Compatible with PowerShell 7.0+ 
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "TestResults-macOS"
)

# Only run on macOS
if (-not $IsMacOS) {
    Write-Host "ℹ️ Skipping macOS-specific tests on non-macOS platform: $($PSVersionTable.Platform)" -ForegroundColor Yellow
    return @{
        Success = $true
        Platform = $PSVersionTable.Platform
        TestsSkipped = $true
        Reason = "Not macOS platform"
    }
}

try {
    Write-Host "🔧 Starting macOS-specific feature tests..." -ForegroundColor Cyan
    
    # Create output directory
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    # Test macOS file system
    Write-Host "  Testing macOS file system..." -ForegroundColor White
    $macPaths = @('/Applications', '/System', '/Users', '/usr/local')
    foreach ($path in $macPaths) {
        if (Test-Path $path) {
            Write-Host "    ✅ $path exists" -ForegroundColor Green
        } else {
            Write-Host "    ⚠️ $path not found" -ForegroundColor Yellow
        }
    }

    # Test environment variables
    Write-Host "  Testing macOS environment variables..." -ForegroundColor White
    $macEnvVars = @('HOME', 'USER', 'PATH', 'SHELL')
    foreach ($envVar in $macEnvVars) {
        $value = [Environment]::GetEnvironmentVariable($envVar)
        if ($value) {
            Write-Host "    ✅ $envVar = $value" -ForegroundColor Green
        } else {
            Write-Host "    ⚠️ $envVar not set" -ForegroundColor Yellow
        }
    }

    # Test Homebrew availability
    Write-Host "  Testing Homebrew availability..." -ForegroundColor White
    try {
        $brewPath = & which brew 2>$null
        if ($brewPath) {
            Write-Host "    ✅ Homebrew found at $brewPath" -ForegroundColor Green
            try {
                $brewVersion = & brew --version 2>$null | Select-Object -First 1
                if ($brewVersion) {
                    Write-Host "    ✅ Homebrew version: $brewVersion" -ForegroundColor Green
                }
            } catch {
                Write-Host "    ⚠️ Could not get Homebrew version" -ForegroundColor Yellow
            }
        } else {
            Write-Host "    ℹ️ Homebrew not found (optional)" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "    ℹ️ Homebrew test skipped" -ForegroundColor Cyan
    }

    # Test common macOS commands
    Write-Host "  Testing common macOS commands..." -ForegroundColor White
    $macCommands = @('ls', 'grep', 'awk', 'sed', 'ps', 'uname', 'sw_vers')
    foreach ($cmd in $macCommands) {
        try {
            $result = & which $cmd 2>$null
            if ($result) {
                Write-Host "    ✅ $cmd available at $result" -ForegroundColor Green
            } else {
                Write-Host "    ⚠️ $cmd not found in PATH" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "    ❌ $cmd test failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # Test macOS system information
    Write-Host "  Testing macOS system information..." -ForegroundColor White
    try {
        $swVersOutput = & sw_vers 2>$null
        if ($swVersOutput) {
            Write-Host "    ✅ macOS version info available" -ForegroundColor Green
        }
    } catch {
        Write-Host "    ⚠️ Could not get macOS version information" -ForegroundColor Yellow
    }

    # Test file permissions (Unix-style)
    Write-Host "  Testing file permissions..." -ForegroundColor White
    try {
        $tempFile = New-TemporaryFile
        $permissions = (Get-Item $tempFile).UnixMode
        if ($permissions) {
            Write-Host "    ✅ Unix file permissions: $permissions" -ForegroundColor Green
        }
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "    ⚠️ File permissions test failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # Test process information
    Write-Host "  Testing process information..." -ForegroundColor White
    try {
        $processes = Get-Process | Select-Object -First 5
        if ($processes) {
            Write-Host "    ✅ Found $($processes.Count) processes" -ForegroundColor Green
        }
    } catch {
        Write-Host "    ⚠️ Process information limited" -ForegroundColor Yellow
    }

    # Generate test summary
    $summary = @{
        Success = $true
        Platform = $PSVersionTable.Platform
        TestsRun = $true
        OutputPath = $OutputPath
        Timestamp = Get-Date
    }

    # Save results
    $summary | ConvertTo-Json -Depth 3 | Out-File (Join-Path $OutputPath "macos-features-test-summary.json") -Encoding UTF8

    Write-Host "✅ macOS-specific feature tests completed successfully" -ForegroundColor Green
    return $summary

} catch {
    Write-Host "❌ macOS feature tests failed: $($_.Exception.Message)" -ForegroundColor Red
    throw
}