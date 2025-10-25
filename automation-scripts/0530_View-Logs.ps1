#Requires -Version 7.0
# Stage: Reporting
# Dependencies: LogViewer
# Description: View and manage AitherZero logs

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [hashtable]$Configuration,

    [Parameter()]
    [ValidateSet('Dashboard', 'Latest', 'Errors', 'Transcript', 'Search', 'Status')]
    [string]$Mode = 'Dashboard',

    [Parameter()]
    [int]$Tail = 30,

    [Parameter()]
    [switch]$Follow,

    [Parameter()]
    [string]$SearchPattern,

    [Parameter()]
    [ValidateSet('Trace', 'Debug', 'Information', 'Warning', 'Error', 'Critical')]
    [string]$Level
)

# Initialize environment
$ProjectRoot = Split-Path $PSScriptRoot -Parent

# Import LogViewer module
$logViewerPath = Join-Path $ProjectRoot "domains/utilities/LogViewer.psm1"
if (Test-Path $logViewerPath) {
    Import-Module $logViewerPath -Force
} else {
    Write-Error "LogViewer module not found at: $logViewerPath"
    exit 1
}

# Import Logging module for Write-CustomLog
$loggingPath = Join-Path $ProjectRoot "domains/core/Logging.psm1"
if (Test-Path $loggingPath) {
    Import-Module $loggingPath -Force -ErrorAction SilentlyContinue
}

function Write-ScriptLog {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level
    } else {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Write-Host "[$timestamp] [$Level] $Message"
    }
}

Write-ScriptLog "Starting log viewer in mode: $Mode"

try {
    # Check if we're in a non-interactive context
    $isNonInteractive = -not [Environment]::UserInteractive -or
                        $env:AITHERZERO_NONINTERACTIVE -eq 'true' -or
                        $Configuration.NonInteractive -eq $true

    switch ($Mode) {
        'Dashboard' {
            if ($isNonInteractive) {
                # In non-interactive mode, show status instead of dashboard
                Write-Host "`n📊 Log Dashboard (Non-Interactive Mode)" -ForegroundColor Cyan
                Write-Host "─────────────────────────────────────────────────" -ForegroundColor DarkGray

                # Show log files
                $logFiles = Get-LogFiles -Type All
                Write-Host "`nAvailable Log Files:" -ForegroundColor White
                foreach ($file in $logFiles | Select-Object -First 5) {
                    $icon = if ($file.Type -eq 'Application') { '📋' } else { '📜' }
                    Write-Host "  $icon $($file.Name) ($($file.SizeKB) KB)" -ForegroundColor Gray
                }

                # Show statistics
                $appLog = $logFiles | Where-Object { $_.Type -eq 'Application' } | Select-Object -First 1
                if ($appLog) {
                    $stats = Get-LogStatistics -Path $appLog.FullName
                    if ($stats) {
                        Write-Host "`nLog Statistics:" -ForegroundColor White
                        Write-Host "  Total Lines: $($stats.TotalLines)" -ForegroundColor Gray
                        Write-Host "  Errors: $($stats.LogLevels.Error)" -ForegroundColor Red
                        Write-Host "  Warnings: $($stats.LogLevels.Warning)" -ForegroundColor Yellow
                        Write-Host "  Info: $($stats.LogLevels.Information)" -ForegroundColor Cyan
                    }
                }

                Write-Host "`nℹ️  Run in interactive mode to access full dashboard features" -ForegroundColor DarkGray
            } else {
                if ($PSCmdlet.ShouldProcess("Interactive log dashboard", "Start interactive log viewing dashboard")) {
                    Write-Host "`n🎯 Starting Log Dashboard..." -ForegroundColor Cyan
                    Show-LogDashboard
                }
            }
        }

        'Latest' {
            Write-Host "`n📋 Showing Latest Log Entries..." -ForegroundColor Cyan
            $logFiles = Get-LogFiles -Type Application
            if ($logFiles) {
                $latest = $logFiles[0]
                Write-Host "File: $($latest.Name)" -ForegroundColor DarkGray
                Write-Host "─────────────────────────────────────────────────" -ForegroundColor DarkGray

                $params = @{
                    Path = $latest.FullName
                    Tail = $Tail
                    Follow = $Follow
                }

                if ($Level) {
                    $params['Level'] = $Level
                }

                Show-LogContent @params

                if (-not $Follow) {
                    Write-Host "`nShowing last $Tail lines. Use -Follow to tail the log." -ForegroundColor DarkGray
                }
            } else {
                Write-Host "No application log files found" -ForegroundColor Yellow
            }
        }

        'Errors' {
            Write-Host "`n❌ Showing Error Log Entries..." -ForegroundColor Red
            $logFiles = Get-LogFiles -Type Application
            if ($logFiles) {
                $latest = $logFiles[0]
                Write-Host "File: $($latest.Name)" -ForegroundColor DarkGray
                Write-Host "─────────────────────────────────────────────────" -ForegroundColor DarkGray

                Show-LogContent -Path $latest.FullName -Level Error -Tail 100

                # Also show warnings if present
                Write-Host "`n⚠️  Recent Warnings:" -ForegroundColor Yellow
                Show-LogContent -Path $latest.FullName -Level Warning -Tail 20
            } else {
                Write-Host "No application log files found" -ForegroundColor Yellow
            }
        }

        'Transcript' {
            Write-Host "`n📜 Showing PowerShell Transcript..." -ForegroundColor Cyan
            $transcripts = Get-LogFiles -Type Transcript
            if ($transcripts) {
                $latest = $transcripts[0]
                Write-Host "File: $($latest.Name)" -ForegroundColor DarkGray
                Write-Host "─────────────────────────────────────────────────" -ForegroundColor DarkGray

                Show-LogContent -Path $latest.FullName -Tail $Tail -Follow:$Follow -NoColor
            } else {
                Write-Host "No transcript files found" -ForegroundColor Yellow
            }
        }

        'Search' {
            if (-not $SearchPattern) {
                if ($isNonInteractive) {
                    Write-Host "`n⚠️  Search mode requires a search pattern in non-interactive mode" -ForegroundColor Yellow
                    Write-Host "Use: -SearchPattern 'your pattern'" -ForegroundColor DarkGray
                    return
                } else {
                    $SearchPattern = Read-Host "Enter search pattern"
                }
            }

            Write-Host "`n🔍 Searching for: '$SearchPattern'" -ForegroundColor Cyan
            Search-Logs -Pattern $SearchPattern -Type All
        }

        'Status' {
            Write-Host "`n📊 LOGGING SYSTEM STATUS" -ForegroundColor Cyan
            Write-Host "════════════════════════════════════════════" -ForegroundColor DarkGray

            $status = Get-LoggingStatus

            Write-Host "`nModule Status:" -ForegroundColor White
            if ($status.ModuleLoaded) {
                Write-Host "  ✅ Logging module loaded" -ForegroundColor Green
            } else {
                Write-Host "  ❌ Logging module not loaded" -ForegroundColor Red
            }

            if ($status.FileLoggingEnabled) {
                Write-Host "  ✅ File logging enabled" -ForegroundColor Green
                Write-Host "     Path: $($status.LogPath)" -ForegroundColor Gray

                if ($status.CurrentLogFile) {
                    $sizeKB = [Math]::Round($status.CurrentLogFile.Length / 1KB, 2)
                    Write-Host "     Size: $sizeKB KB" -ForegroundColor Gray
                    Write-Host "     Modified: $($status.CurrentLogFile.LastWriteTime)" -ForegroundColor Gray
                }
            } else {
                Write-Host "  ⚠️  File logging disabled" -ForegroundColor Yellow
            }

            if ($status.TranscriptActive) {
                Write-Host "  ✅ PowerShell transcript active" -ForegroundColor Green
            } else {
                Write-Host "  ⚠️  PowerShell transcript inactive" -ForegroundColor Yellow
            }

            # Show log files summary
            Write-Host "`nLog Files:" -ForegroundColor White
            $allLogs = Get-LogFiles -Type All
            $appLogs = $allLogs | Where-Object { $_.Type -eq 'Application' }
            $transcripts = $allLogs | Where-Object { $_.Type -eq 'Transcript' }

            Write-Host "  📋 Application logs: $($appLogs.Count) files" -ForegroundColor Gray
            if ($appLogs) {
                $totalSizeKB = [Math]::Round(($appLogs | Measure-Object -Property Length -Sum).Sum / 1KB, 2)
                Write-Host "     Total size: $totalSizeKB KB" -ForegroundColor DarkGray
            }

            Write-Host "  📜 Transcript logs: $($transcripts.Count) files" -ForegroundColor Gray
            if ($transcripts) {
                $totalSizeKB = [Math]::Round(($transcripts | Measure-Object -Property Length -Sum).Sum / 1KB, 2)
                Write-Host "     Total size: $totalSizeKB KB" -ForegroundColor DarkGray
            }

            # Show configuration if available
            if ($status.Configuration) {
                Write-Host "`nConfiguration:" -ForegroundColor White
                Write-Host "  Level: $($status.Configuration.Level)" -ForegroundColor Gray
                Write-Host "  Targets: $($status.Configuration.Targets -join ', ')" -ForegroundColor Gray
                Write-Host "  Path: $($status.Configuration.Path)" -ForegroundColor Gray
            }
        }
    }

    Write-ScriptLog "Log viewer completed successfully"
    exit 0

} catch {
    Write-ScriptLog "Error in log viewer: $_" -Level 'Error'
    Write-Error $_
    exit 1
}
