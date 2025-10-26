#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    AitherZero Centralized Logging and Reporting Dashboard
.DESCRIPTION
    Main entry point for viewing centralized logs, test results, code analysis,
    and system metrics in a unified dashboard.
.PARAMETER RefreshInterval
    Auto-refresh interval in seconds (0 = no auto-refresh, default: 0)
.PARAMETER ShowTests
    Include test results section
.PARAMETER ShowAnalysis
    Include code analysis section
.PARAMETER ShowLogs
    Include recent logs section (default: true)
.PARAMETER ShowMetrics
    Include system metrics section
.PARAMETER ShowAll
    Show all sections
.PARAMETER Export
    Export report to file instead of displaying dashboard
.PARAMETER Format
    Export format (HTML, JSON, Markdown) when using -Export
.EXAMPLE
    ./Show-Dashboard.ps1
    Display dashboard with logs only
.EXAMPLE
    ./Show-Dashboard.ps1 -ShowAll -RefreshInterval 30
    Display full dashboard with 30-second auto-refresh
.EXAMPLE
    ./Show-Dashboard.ps1 -Export -Format HTML -ShowAll
    Export comprehensive report to HTML file
.NOTES
    Copyright © 2025 Aitherium Corporation
#>

[CmdletBinding()]
param(
    [int]$RefreshInterval = 0,
    [switch]$ShowTests,
    [switch]$ShowAnalysis,
    [switch]$ShowLogs = $true,
    [switch]$ShowMetrics,
    [switch]$ShowAll,
    [switch]$Export,
    [ValidateSet('HTML', 'JSON', 'Markdown')]
    [string]$Format = 'HTML'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Get script directory
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) {
    $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

# Import required modules
$CentralizedReportingModule = Join-Path $ScriptRoot "domains/utilities/CentralizedReporting.psm1"

if (-not (Test-Path $CentralizedReportingModule)) {
    Write-Host "ERROR: CentralizedReporting module not found at: $CentralizedReportingModule" -ForegroundColor Red
    Write-Host "Please ensure you're running this script from the AitherZero root directory." -ForegroundColor Yellow
    exit 1
}

try {
    Import-Module $CentralizedReportingModule -Force
} catch {
    Write-Host "ERROR: Failed to import CentralizedReporting module: $_" -ForegroundColor Red
    exit 1
}

# Display header
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                      AitherZero Dashboard Launcher                            " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if ($Export) {
    # Export mode
    Write-Host "Generating centralized report..." -ForegroundColor Yellow
    Write-Host ""

    $params = @{
        Format = $Format
    }

    if ($ShowAll) {
        $params.IncludeAll = $true
    } else {
        if ($ShowTests) { $params.IncludeTests = $true }
        if ($ShowAnalysis) { $params.IncludeAnalysis = $true }
        if ($ShowLogs) { $params.IncludeLogs = $true }
        if ($ShowMetrics) { $params.IncludeMetrics = $true }
    }

    $reportPath = Export-CentralizedReport @params

    Write-Host ""
    Write-Host "Report exported successfully!" -ForegroundColor Green
    Write-Host "Location: $reportPath" -ForegroundColor White
    Write-Host ""

    # Offer to open the report
    if ($Format -eq 'HTML' -and $IsWindows) {
        $response = Read-Host "Would you like to open the report? (Y/N)"
        if ($response -eq 'Y' -or $response -eq 'y') {
            Start-Process $reportPath
        }
    }
} else {
    # Dashboard mode
    Write-Host "Launching interactive dashboard..." -ForegroundColor Yellow
    Write-Host ""

    if ($RefreshInterval -gt 0) {
        Write-Host "Dashboard will auto-refresh every $RefreshInterval seconds." -ForegroundColor Gray
        Write-Host "Press Ctrl+C to exit." -ForegroundColor Gray
    }

    Write-Host ""
    Start-Sleep -Seconds 1

    $params = @{
        RefreshInterval = $RefreshInterval
    }

    if ($ShowAll) {
        $params.ShowAll = $true
    } else {
        if ($ShowTests) { $params.ShowTests = $true }
        if ($ShowAnalysis) { $params.ShowAnalysis = $true }
        if ($ShowLogs) { $params.ShowLogs = $true }
        if ($ShowMetrics) { $params.ShowMetrics = $true }
    }

    Show-CentralizedDashboard @params
}
