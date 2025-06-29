#!/usr/bin/env pwsh

# Quick test of performance monitoring
. "$PSScriptRoot/aither-core/shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

Import-Module (Join-Path $projectRoot "aither-core/modules/SystemMonitoring") -Force

Write-Host "Testing Get-SystemPerformance..." -ForegroundColor Cyan
try {
    $metrics = Get-SystemPerformance -MetricType System -Duration 2
    Write-Host "✓ Success!" -ForegroundColor Green
    Write-Host "CPU: $($metrics.System.CPU.Average)%" -ForegroundColor Gray
    Write-Host "Memory: $($metrics.System.Memory.Average)%" -ForegroundColor Gray
} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}