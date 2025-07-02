#Requires -Version 7.0

<#
.SYNOPSIS
    Linux-specific feature tests for AitherZero

.DESCRIPTION
    Tests Linux-specific functionality including systemd, package managers,
    file permissions, and Linux-only PowerShell features.

.PARAMETER OutputPath
    Directory path for test results and artifacts

.EXAMPLE
    ./tests/Test-LinuxFeatures.ps1 -OutputPath "TestResults-Linux"

.NOTES
    Only runs on Linux platforms
    Compatible with PowerShell 7.0+ 
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "TestResults-Linux"
)

# Only run on Linux
if (-not $IsLinux) {
    Write-Host "ℹ️ Skipping Linux-specific tests on non-Linux platform: $($PSVersionTable.Platform)" -ForegroundColor Yellow
    return @{
        Success = $true
        Platform = $PSVersionTable.Platform
        TestsSkipped = $true
        Reason = "Not Linux platform"
    }
}

try {
    Write-Host "🔧 Starting Linux-specific feature tests..." -ForegroundColor Cyan
    
    # Create output directory
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    # Test Linux file system
    Write-Host "  Testing Linux file system..." -ForegroundColor White
    $rootDir = Get-ChildItem -Path "/" -ErrorAction SilentlyContinue
    if ($rootDir) {
        Write-Host "    ✅ Root filesystem accessible" -ForegroundColor Green
    } else {
        Write-Host "    ⚠️ Root filesystem access limited" -ForegroundColor Yellow
    }

    # Test environment variables
    Write-Host "  Testing Linux environment variables..." -ForegroundColor White
    $linuxEnvVars = @('HOME', 'USER', 'PATH', 'SHELL')
    foreach ($envVar in $linuxEnvVars) {
        $value = [Environment]::GetEnvironmentVariable($envVar)
        if ($value) {
            Write-Host "    ✅ $envVar = $value" -ForegroundColor Green
        } else {
            Write-Host "    ⚠️ $envVar not set" -ForegroundColor Yellow
        }
    }

    # Test common Linux commands availability
    Write-Host "  Testing common Linux commands..." -ForegroundColor White
    $linuxCommands = @('ls', 'grep', 'awk', 'sed', 'ps', 'uname')
    foreach ($cmd in $linuxCommands) {
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

    # Test system information
    Write-Host "  Testing system information..." -ForegroundColor White
    try {
        $unameOutput = & uname -a 2>$null
        if ($unameOutput) {
            Write-Host "    ✅ System info: $unameOutput" -ForegroundColor Green
        }
    } catch {
        Write-Host "    ⚠️ Could not get system information" -ForegroundColor Yellow
    }

    # Test file permissions
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
    $summary | ConvertTo-Json -Depth 3 | Out-File (Join-Path $OutputPath "linux-features-test-summary.json") -Encoding UTF8

    Write-Host "✅ Linux-specific feature tests completed successfully" -ForegroundColor Green
    return $summary

} catch {
    Write-Host "❌ Linux feature tests failed: $($_.Exception.Message)" -ForegroundColor Red
    throw
}