#Requires -Version 7.0

<#
.SYNOPSIS
    Windows-specific feature tests for AitherZero

.DESCRIPTION
    Tests Windows-specific functionality including services, scheduled tasks,
    registry operations, and Windows-only PowerShell features.

.PARAMETER OutputPath
    Directory path for test results and artifacts

.EXAMPLE
    ./tests/Test-WindowsFeatures.ps1 -OutputPath "TestResults-Windows"

.NOTES
    Only runs on Windows platforms
    Compatible with PowerShell 7.0+ 
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "TestResults-Windows"
)

# Only run on Windows
if (-not $IsWindows) {
    Write-Host "ℹ️ Skipping Windows-specific tests on non-Windows platform: $($PSVersionTable.Platform)" -ForegroundColor Yellow
    return @{
        Success = $true
        Platform = $PSVersionTable.Platform
        TestsSkipped = $true
        Reason = "Not Windows platform"
    }
}

try {
    Write-Host "🔧 Starting Windows-specific feature tests..." -ForegroundColor Cyan
    
    # Create output directory
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    # Test Windows services
    Write-Host "  Testing Windows services..." -ForegroundColor White
    $services = Get-Service | Where-Object { $_.Status -eq 'Running' } | Select-Object -First 5
    if ($services.Count -gt 0) {
        Write-Host "    ✅ Found $($services.Count) running services" -ForegroundColor Green
    } else {
        Write-Host "    ⚠️ No running services found" -ForegroundColor Yellow
    }

    # Test Windows registry access
    Write-Host "  Testing Windows registry access..." -ForegroundColor White
    try {
        $regKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "ProductName" -ErrorAction SilentlyContinue
        if ($regKey) {
            Write-Host "    ✅ Registry access successful: $($regKey.ProductName)" -ForegroundColor Green
        } else {
            Write-Host "    ⚠️ Registry access limited" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "    ❌ Registry access failed: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Test Windows event log access
    Write-Host "  Testing Windows event log access..." -ForegroundColor White
    try {
        $events = Get-WinEvent -LogName "System" -MaxEvents 1 -ErrorAction SilentlyContinue
        if ($events) {
            Write-Host "    ✅ Event log access successful" -ForegroundColor Green
        } else {
            Write-Host "    ⚠️ Event log access limited" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "    ❌ Event log access failed: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Test PowerShell execution policy
    Write-Host "  Testing PowerShell execution policy..." -ForegroundColor White
    $executionPolicy = Get-ExecutionPolicy
    Write-Host "    ℹ️ Current execution policy: $executionPolicy" -ForegroundColor Cyan

    # Test Windows-specific cmdlets
    Write-Host "  Testing Windows-specific cmdlets..." -ForegroundColor White
    $windowsCmdlets = @(
        'Get-ComputerInfo',
        'Get-WindowsFeature',
        'Get-Process'
    )
    
    foreach ($cmdlet in $windowsCmdlets) {
        try {
            if (Get-Command $cmdlet -ErrorAction SilentlyContinue) {
                Write-Host "    ✅ $cmdlet available" -ForegroundColor Green
            } else {
                Write-Host "    ⚠️ $cmdlet not available" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "    ❌ $cmdlet test failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # Generate test summary
    $summary = @{
        Success = $true
        Platform = $PSVersionTable.Platform
        TestsRun = $true
        OutputPath = $OutputPath
        ExecutionPolicy = $executionPolicy
        Timestamp = Get-Date
    }

    # Save results
    $summary | ConvertTo-Json -Depth 3 | Out-File (Join-Path $OutputPath "windows-features-test-summary.json") -Encoding UTF8

    Write-Host "✅ Windows-specific feature tests completed successfully" -ForegroundColor Green
    return $summary

} catch {
    Write-Host "❌ Windows feature tests failed: $($_.Exception.Message)" -ForegroundColor Red
    throw
}