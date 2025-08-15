#Requires -Version 7.0

<#
.SYNOPSIS
    Monitor test fix workflow progress
.DESCRIPTION
    Provides real-time monitoring of the test fix workflow, showing Claude's activity,
    test validation results, and overall progress.
    
    Exit Codes:
    0   - Monitoring completed
    1   - Error during monitoring
    
.NOTES
    Stage: Testing
    Order: 0758
    Dependencies: 0751, test-fix-tracker.json
    Tags: testing, monitoring, claude, progress
#>

[CmdletBinding()]
param(
    [string]$TrackerPath = './test-fix-tracker.json',
    [string]$LogPath = './logs/aitherzero-*.log',
    [string]$TranscriptPath = './logs/transcript-*.log',
    [int]$RefreshSeconds = 5,
    [switch]$Continuous,
    [switch]$ShowLogs
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata
$scriptMetadata = @{
    Stage = 'Testing'
    Order = 0758
    Dependencies = @('0751')
    Tags = @('testing', 'monitoring', 'claude', 'progress')
    RequiresAdmin = $false
}

function Write-ScriptLog {
    param(
        [string]$Level = 'Information',
        [string]$Message
    )
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level -Component 'Monitor-TestFix'
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $color = @{
            'Error' = 'Red'
            'Warning' = 'Yellow'
            'Information' = 'White'
            'Debug' = 'Gray'
        }[$Level]
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    }
}

function Show-Progress {
    param($tracker)
    
    $open = @($tracker.issues | Where-Object { $_.status -eq 'open' }).Count
    $fixing = @($tracker.issues | Where-Object { $_.status -eq 'fixing' }).Count
    $validating = @($tracker.issues | Where-Object { $_.status -eq 'validating' }).Count
    $resolved = @($tracker.issues | Where-Object { $_.status -eq 'resolved' }).Count
    $failed = @($tracker.issues | Where-Object { $_.status -eq 'failed' }).Count
    $total = $tracker.issues.Count
    
    # Clear screen for better display
    if (-not $ShowLogs) {
        Clear-Host
    }
    
    Write-Host "`n" -NoNewline
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host "TEST FIX WORKFLOW MONITOR" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host "Updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "Branch: $($tracker.currentBranch)" -ForegroundColor Gray
    Write-Host ""
    
    # Progress bar
    $progressPercent = if ($total -gt 0) { 
        [math]::Round((($resolved + $failed) / $total) * 100, 1) 
    } else { 0 }
    
    Write-Host "Overall Progress: " -NoNewline
    $barLength = 40
    $filledLength = [math]::Floor($progressPercent / 100 * $barLength)
    $emptyLength = $barLength - $filledLength
    
    Write-Host "[" -NoNewline
    Write-Host ("█" * $filledLength) -ForegroundColor Green -NoNewline
    Write-Host ("░" * $emptyLength) -ForegroundColor DarkGray -NoNewline
    Write-Host "] $progressPercent%"
    Write-Host ""
    
    # Status breakdown
    Write-Host "📊 Issue Status:" -ForegroundColor Cyan
    Write-Host "  Total Issues: $total"
    
    if ($open -gt 0) {
        Write-Host "  📝 Open: $open" -ForegroundColor Yellow
    }
    
    if ($fixing -gt 0) {
        Write-Host "  🔧 Being Fixed by Claude: $fixing" -ForegroundColor Magenta
    }
    
    if ($validating -gt 0) {
        Write-Host "  🔍 Validating: $validating" -ForegroundColor Blue
    }
    
    if ($resolved -gt 0) {
        Write-Host "  ✅ Resolved: $resolved" -ForegroundColor Green
    }
    
    if ($failed -gt 0) {
        Write-Host "  ❌ Failed (max attempts): $failed" -ForegroundColor Red
    }
    
    # Current activity
    Write-Host "`n🎯 Current Activity:" -ForegroundColor Cyan
    
    $currentIssue = $tracker.issues | Where-Object { 
        $_.status -in @('fixing', 'validating') 
    } | Select-Object -First 1
    
    if ($currentIssue) {
        Write-Host "  Working on: $($currentIssue.testName)" -ForegroundColor White
        Write-Host "  Status: $($currentIssue.status)" -ForegroundColor Yellow
        Write-Host "  Attempt: $($currentIssue.attempts) of 3" -ForegroundColor Gray
        Write-Host "  File: $($currentIssue.file):$($currentIssue.line)" -ForegroundColor Gray
        
        if ($currentIssue.githubIssue) {
            Write-Host "  GitHub Issue: #$($currentIssue.githubIssue)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  No active processing" -ForegroundColor Gray
    }
    
    # Recent Claude activity
    if (Test-Path './claude-artifacts/') {
        $recentFiles = Get-ChildItem './claude-artifacts/*.txt' -ErrorAction SilentlyContinue | 
            Sort-Object LastWriteTime -Descending | 
            Select-Object -First 3
        
        if ($recentFiles) {
            Write-Host "`n📝 Recent Claude Activity:" -ForegroundColor Cyan
            foreach ($file in $recentFiles) {
                $age = (Get-Date) - $file.LastWriteTime
                $ageStr = if ($age.TotalMinutes -lt 1) { 
                    "$([int]$age.TotalSeconds)s ago" 
                } elseif ($age.TotalHours -lt 1) {
                    "$([int]$age.TotalMinutes)m ago"
                } else {
                    "$([int]$age.TotalHours)h ago"
                }
                Write-Host "  $($file.Name) - $ageStr" -ForegroundColor Gray
            }
        }
    }
}

function Show-Logs {
    param([int]$Lines = 10)
    
    Write-Host "`n📋 Recent Log Entries:" -ForegroundColor Cyan
    
    # Get latest log file
    $latestLog = Get-ChildItem $LogPath | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    
    if ($latestLog) {
        Get-Content $latestLog -Tail $Lines | ForEach-Object {
            if ($_ -match 'Claude') {
                Write-Host $_ -ForegroundColor Magenta
            } elseif ($_ -match 'ERROR|Failed') {
                Write-Host $_ -ForegroundColor Red
            } elseif ($_ -match 'WARNING') {
                Write-Host $_ -ForegroundColor Yellow
            } elseif ($_ -match 'SUCCESS|Resolved|Passed') {
                Write-Host $_ -ForegroundColor Green
            } else {
                Write-Host $_ -ForegroundColor Gray
            }
        }
    }
}

try {
    Write-ScriptLog -Message "Starting test fix monitoring"
    
    if (-not (Test-Path $TrackerPath)) {
        Write-ScriptLog -Level Error -Message "Tracker file not found: $TrackerPath"
        exit 1
    }
    
    do {
        # Load current tracker state
        $tracker = Get-Content $TrackerPath -Raw | ConvertFrom-Json -AsHashtable
        
        # Ensure issues is an array
        if ($tracker.issues -isnot [array]) {
            $tracker.issues = @($tracker.issues)
        }
        
        # Show progress
        Show-Progress -tracker $tracker
        
        # Show logs if requested
        if ($ShowLogs) {
            Show-Logs -Lines 10
        }
        
        # Check if workflow is complete
        $activeIssues = @($tracker.issues | Where-Object { 
            $_.status -in @('open', 'fixing', 'validating') -and 
            $_.attempts -lt 3 
        }).Count
        
        if ($activeIssues -eq 0) {
            Write-Host "`n" -NoNewline
            Write-Host "=" * 60 -ForegroundColor Green
            Write-Host "WORKFLOW COMPLETE!" -ForegroundColor Green
            Write-Host "=" * 60 -ForegroundColor Green
            
            $resolved = @($tracker.issues | Where-Object { $_.status -eq 'resolved' }).Count
            $failed = @($tracker.issues | Where-Object { $_.status -eq 'failed' }).Count
            
            if ($resolved -gt 0) {
                Write-Host "✅ Successfully fixed $resolved test(s)" -ForegroundColor Green
                Write-Host "💡 Next: Run 0757_Create-FixPR.ps1 to create pull request" -ForegroundColor Yellow
            }
            
            if ($failed -gt 0) {
                Write-Host "⚠️ $failed test(s) require manual intervention" -ForegroundColor Red
            }
            
            if (-not $Continuous) {
                break
            }
        }
        
        if ($Continuous) {
            Write-Host "`nRefreshing in $RefreshSeconds seconds... (Ctrl+C to stop)" -ForegroundColor DarkGray
            Start-Sleep -Seconds $RefreshSeconds
        }
        
    } while ($Continuous)
    
    Write-ScriptLog -Message "Monitoring completed"
    exit 0
}
catch {
    Write-ScriptLog -Level Error -Message "Monitoring error: $_"
    exit 1
}