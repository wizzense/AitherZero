#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Continuously run test-fix-loop until all issues are resolved or failed
.DESCRIPTION
    Keeps running the test-fix-loop playbook until all test issues are either
    resolved or have failed with max attempts.
#>

param(
    [int]$MaxRuns = 20,
    [int]$DelayBetweenRuns = 10
)

Write-Host "Starting continuous test fix workflow" -ForegroundColor Cyan
Write-Host "Will run up to $MaxRuns times with $DelayBetweenRuns second delays" -ForegroundColor Gray

$runs = 0

while ($runs -lt $MaxRuns) {
    $runs++
    
    # Check current status
    $tracker = Get-Content './test-fix-tracker.json' -Raw | ConvertFrom-Json
    $open = @($tracker.issues | Where-Object { 
        $_.status -eq 'open' -and $_.attempts -lt 3 
    }).Count
    
    $resolved = @($tracker.issues | Where-Object { $_.status -eq 'resolved' }).Count
    $failed = @($tracker.issues | Where-Object { $_.status -eq 'failed' }).Count
    $total = $tracker.issues.Count
    
    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "Run #$runs | Status: $resolved/$total resolved, $failed failed, $open open" -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    
    if ($open -eq 0) {
        Write-Host "`n✅ All fixable issues have been processed!" -ForegroundColor Green
        Write-Host "  Resolved: $resolved" -ForegroundColor Green
        Write-Host "  Failed: $failed" -ForegroundColor Red
        
        if ($resolved -gt 0) {
            Write-Host "`n💡 Next step: Run 0757_Create-FixPR.ps1 to create pull request" -ForegroundColor Yellow
        }
        break
    }
    
    Write-Host "`n🚀 Starting workflow for next issue..." -ForegroundColor Magenta
    
    # Run the workflow
    & ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-fix-loop -NonInteractive
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️ Workflow failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    }
    
    # Brief delay before next run
    if ($open -gt 0 -and $runs -lt $MaxRuns) {
        Write-Host "`nWaiting $DelayBetweenRuns seconds before next run..." -ForegroundColor DarkGray
        Start-Sleep -Seconds $DelayBetweenRuns
    }
}

if ($runs -ge $MaxRuns) {
    Write-Host "`n⚠️ Reached maximum runs ($MaxRuns). Stopping." -ForegroundColor Yellow
}

Write-Host "`n📊 Final Summary:" -ForegroundColor Cyan
$tracker = Get-Content './test-fix-tracker.json' -Raw | ConvertFrom-Json
$resolved = @($tracker.issues | Where-Object { $_.status -eq 'resolved' }).Count
$failed = @($tracker.issues | Where-Object { $_.status -eq 'failed' }).Count
$open = @($tracker.issues | Where-Object { $_.status -eq 'open' }).Count

Write-Host "  Total Issues: $($tracker.issues.Count)"
Write-Host "  Resolved: $resolved" -ForegroundColor Green
Write-Host "  Failed: $failed" -ForegroundColor Red
Write-Host "  Still Open: $open" -ForegroundColor Yellow