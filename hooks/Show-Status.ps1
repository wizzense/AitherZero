#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Unified status dashboard for PR and CI monitoring
    
.DESCRIPTION
    Combines PR status and CI monitoring into a single comprehensive view.
    Shows everything you need to know about your PR's readiness to merge.
    
.PARAMETER PRNumber
    PR number to monitor. Auto-detects from current branch if not specified.
    
.PARAMETER Watch
    Enable live monitoring with auto-refresh
    
.PARAMETER Interval
    Refresh interval in seconds (default: 10)
    
.EXAMPLE
    ./hooks/Show-Status.ps1
    
.EXAMPLE
    ./hooks/Show-Status.ps1 -Watch -Interval 5
    
.EXAMPLE
    ./hooks/Show-Status.ps1 -PRNumber 557
#>

[CmdletBinding()]
param(
    [int]$PRNumber,
    [switch]$Watch,
    [int]$Interval = 10
)

# Find script directory and load dependencies
$scriptDir = $PSScriptRoot

# Load the PR and CI status scripts
. "$scriptDir/Get-PRStatus.ps1"
. "$scriptDir/Get-CIStatus.ps1"

function Show-UnifiedStatus {
    param([int]$PR)
    
    Clear-Host
    
    # Header
    Write-Host "`n" -NoNewline
    Write-Host "╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                    UNIFIED STATUS DASHBOARD                       ║" -ForegroundColor Cyan
    Write-Host "║                  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')                      ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    try {
        # Get PR status (suppress default output)
        $prOutput = & "$scriptDir/Get-PRStatus.ps1" -PRNumber $PR -OutputFormat JSON 2>$null | ConvertFrom-Json
        
        # Get CI status for the PR's branch
        $ciOutput = & "$scriptDir/Get-CIStatus.ps1" -Branch $prOutput.pr.headRefName -OutputFormat JSON 2>$null | ConvertFrom-Json
        
        # PR Summary Section
        Write-Host "`n📋 PULL REQUEST #$PR" -ForegroundColor Yellow
        Write-Host "   Title: $($prOutput.pr.title)"
        Write-Host "   Branch: $($prOutput.pr.headRefName) → $($prOutput.pr.baseRefName)"
        Write-Host "   Author: $($prOutput.pr.author.login)"
        Write-Host "   State: " -NoNewline
        $stateColor = if ($prOutput.pr.state -eq 'OPEN') { 'Green' } else { 'Red' }
        Write-Host $prOutput.pr.state -ForegroundColor $stateColor
        
        # Quick Status Indicators
        Write-Host "`n✅ READINESS INDICATORS" -ForegroundColor Yellow
        
        $ready = $true
        $blockers = @()
        
        # Check CI status
        if ($prOutput.checks.Failure -gt 0) {
            Write-Host "   ❌ CI Checks: $($prOutput.checks.Failure) failing" -ForegroundColor Red
            $ready = $false
            $blockers += "Fix $($prOutput.checks.Failure) failing CI checks"
        } elseif ($prOutput.checks.Pending -gt 0) {
            Write-Host "   ⏳ CI Checks: $($prOutput.checks.Pending) pending" -ForegroundColor Yellow
            $ready = $false
            $blockers += "Wait for $($prOutput.checks.Pending) pending checks"
        } else {
            Write-Host "   ✅ CI Checks: All passing!" -ForegroundColor Green
        }
        
        # Check reviews
        $approvals = $prOutput.pr.reviews | Where-Object { $_.state -eq 'APPROVED' } | Measure-Object | Select-Object -ExpandProperty Count
        if ($approvals -eq 0) {
            Write-Host "   ⏳ Reviews: No approvals yet" -ForegroundColor Yellow
            $blockers += "Get code review approval"
        } else {
            Write-Host "   ✅ Reviews: $approvals approval(s)" -ForegroundColor Green
        }
        
        # Check merge conflicts
        if ($prOutput.pr.mergeable -eq $false) {
            Write-Host "   ❌ Mergeable: Conflicts detected" -ForegroundColor Red
            $ready = $false
            $blockers += "Resolve merge conflicts"
        } elseif ($prOutput.pr.mergeable -eq $true) {
            Write-Host "   ✅ Mergeable: No conflicts" -ForegroundColor Green
        } else {
            Write-Host "   ⏳ Mergeable: Checking..." -ForegroundColor Yellow
        }
        
        # CI Details Section
        if ($ciOutput.currentRun) {
            Write-Host "`n🔄 LATEST CI RUN" -ForegroundColor Yellow
            Write-Host "   Run #$($ciOutput.currentRun.runNumber): $($ciOutput.currentRun.displayTitle)"
            Write-Host "   Status: " -NoNewline
            
            $ciStatus = if ($ciOutput.currentRun.status -eq 'completed') {
                "$($ciOutput.currentRun.conclusion)"
            } else {
                "$($ciOutput.currentRun.status)"
            }
            
            $ciColor = switch ($ciStatus) {
                'success' { 'Green' }
                'failure' { 'Red' }
                'in_progress' { 'Yellow' }
                'queued' { 'DarkYellow' }
                default { 'Gray' }
            }
            
            Write-Host $ciStatus -ForegroundColor $ciColor
            
            # Job breakdown
            if ($ciOutput.analysis) {
                Write-Host "   Jobs: " -NoNewline
                Write-Host "$($ciOutput.analysis.Passed)" -ForegroundColor Green -NoNewline
                Write-Host "/" -NoNewline
                Write-Host "$($ciOutput.analysis.Failed)" -ForegroundColor Red -NoNewline
                Write-Host "/" -NoNewline
                Write-Host "$($ciOutput.analysis.InProgress)" -ForegroundColor Yellow -NoNewline
                Write-Host "/" -NoNewline
                Write-Host "$($ciOutput.analysis.Queued)" -ForegroundColor DarkYellow -NoNewline
                Write-Host " (Pass/Fail/Running/Queued)"
            }
        }
        
        # Action Items
        if ($blockers.Count -gt 0 -or $prOutput.recommendations.Count -gt 0) {
            Write-Host "`n🎯 ACTION ITEMS" -ForegroundColor Yellow
            
            $allActions = $blockers + $prOutput.recommendations
            $uniqueActions = $allActions | Select-Object -Unique
            
            foreach ($action in $uniqueActions) {
                Write-Host "   • $action" -ForegroundColor White
            }
        }
        
        # Bottom Line
        Write-Host "`n" -NoNewline
        if ($ready -and $prOutput.pr.state -eq 'OPEN') {
            Write-Host "🚀 READY TO MERGE!" -ForegroundColor Green -BackgroundColor DarkGreen
        } else {
            Write-Host "⏳ NOT READY - $(($blockers | Measure-Object).Count) blocker(s)" -ForegroundColor Yellow -BackgroundColor DarkYellow
        }
        
    } catch {
        Write-Host "`n❌ ERROR: $_" -ForegroundColor Red
    }
    
    if ($Watch) {
        Write-Host "`n[Refreshing every $Interval seconds - Press Ctrl+C to exit]" -ForegroundColor DarkGray
    }
}

# Main loop
try {
    # Auto-detect PR if not specified
    if (-not $PRNumber) {
        $currentBranch = git branch --show-current
        $prList = gh pr list --head "$currentBranch" --json number --jq '.[0].number' 2>$null
        if ($prList) {
            $PRNumber = [int]$prList
        } else {
            throw "Could not detect PR number. Please specify with -PRNumber parameter."
        }
    }
    
    do {
        Show-UnifiedStatus -PR $PRNumber
        
        if ($Watch) {
            Start-Sleep -Seconds $Interval
        }
    } while ($Watch)
    
} catch {
    Write-Error "Failed to show status: $_"
    exit 1
}