#!/usr/bin/env pwsh
# AitherZero Report Generation Wrapper
param()

$scriptPath = Join-Path $PSScriptRoot "../automation-scripts/0510_Generate-ProjectReport.ps1"
$logPath = Join-Path $PSScriptRoot "../logs/scheduled-reports.log"

try {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$timestamp] Starting scheduled report generation" | Add-Content $logPath

    # Run report generation
    & $scriptPath -Format All

    "[$timestamp] Report generation completed successfully" | Add-Content $logPath
} catch {
    "[$timestamp] Report generation failed: $_" | Add-Content $logPath
    exit 1
}
