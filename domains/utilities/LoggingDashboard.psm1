#Requires -Version 7.0
<#
.SYNOPSIS
    AitherZero Logging Dashboard - Interactive log viewer and management
.DESCRIPTION
    Provides an interactive dashboard for viewing, searching, and managing logs
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module state
$script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:LogPath = Join-Path $script:ProjectRoot "logs"
$script:RefreshInterval = 5
$script:AutoRefresh = $false
$script:FilterSettings = @{
    Level = $null
    Source = $null
    Pattern = $null
    TimeRange = 'Last Hour'
}

function Show-LogDashboard {
    <#
    .SYNOPSIS
        Display interactive logging dashboard
    .DESCRIPTION
        Shows a real-time dashboard for monitoring and analyzing logs
    .PARAMETER AutoRefresh
        Enable automatic refresh of log data
    .PARAMETER RefreshInterval
        Refresh interval in seconds
    .EXAMPLE
        Show-LogDashboard -AutoRefresh -RefreshInterval 3
    #>
    [CmdletBinding()]
    param(
        [switch]$AutoRefresh,
        
        [int]$RefreshInterval = 5,
        
        [switch]$ShowTranscript,
        
        [switch]$FollowTail
    )

    $script:AutoRefresh = $AutoRefresh
    $script:RefreshInterval = $RefreshInterval

    Clear-Host
    Write-Host "`n╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              AitherZero Logging Dashboard v1.0                    ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    do {
        Show-LogSummary
        Show-LogMenu
        
        if ($FollowTail) {
            Show-LogTail -Lines 20
        }
        
        if ($AutoRefresh) {
            Write-Host "`nAuto-refresh in $RefreshInterval seconds... (Press 'q' to stop)" -ForegroundColor DarkGray
            $timer = [System.Diagnostics.Stopwatch]::StartNew()
            while ($timer.Elapsed.TotalSeconds -lt $RefreshInterval) {
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    if ($key.KeyChar -eq 'q') {
                        $script:AutoRefresh = $false
                        break
                    }
                }
                Start-Sleep -Milliseconds 100
            }
            $timer.Stop()
            if ($script:AutoRefresh) { Clear-Host }
        } else {
            $choice = Read-Host "`nSelect option"
            Process-MenuChoice -Choice $choice
        }
    } while ($script:AutoRefresh -or $choice -ne 'q')
}

function Show-LogSummary {
    Write-Host "`n📊 LOG SUMMARY" -ForegroundColor Yellow
    Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    
    # Get log files
    $logFiles = Get-ChildItem -Path $script:LogPath -Filter "*.log" -ErrorAction SilentlyContinue
    $transcriptFiles = Get-ChildItem -Path $script:LogPath -Filter "transcript-*.log" -ErrorAction SilentlyContinue
    
    # Display log file info
    Write-Host "📁 Log Directory: " -NoNewline -ForegroundColor Cyan
    Write-Host $script:LogPath
    
    Write-Host "📝 Log Files: " -NoNewline -ForegroundColor Cyan
    Write-Host "$($logFiles.Count) files found"
    
    if ($logFiles) {
        $totalSize = ($logFiles | Measure-Object -Property Length -Sum).Sum / 1MB
        Write-Host "💾 Total Size: " -NoNewline -ForegroundColor Cyan
        Write-Host "$([Math]::Round($totalSize, 2)) MB"
        
        # Get today's log
        $todayLog = $logFiles | Where-Object { $_.Name -match (Get-Date -Format 'yyyy-MM-dd') } | Select-Object -First 1
        if ($todayLog) {
            Write-Host "📅 Today's Log: " -NoNewline -ForegroundColor Cyan
            Write-Host "$($todayLog.Name) ($([Math]::Round($todayLog.Length / 1KB, 2)) KB)"
            
            # Count log levels
            $content = Get-Content $todayLog.FullName -ErrorAction SilentlyContinue
            if ($content) {
                $levels = @{
                    Critical = ($content | Select-String '\[CRITICAL\s*\]').Count
                    Error = ($content | Select-String '\[ERROR\s*\]').Count
                    Warning = ($content | Select-String '\[WARNING\s*\]').Count
                    Information = ($content | Select-String '\[INFORMATION\]').Count
                    Debug = ($content | Select-String '\[DEBUG\s*\]').Count
                    Trace = ($content | Select-String '\[TRACE\s*\]').Count
                }
                
                Write-Host "`n📈 Log Level Distribution:" -ForegroundColor Yellow
                foreach ($level in $levels.GetEnumerator() | Sort-Object Name) {
                    $color = @{
                        Critical = 'Magenta'
                        Error = 'Red'
                        Warning = 'Yellow'
                        Information = 'White'
                        Debug = 'Gray'
                        Trace = 'DarkGray'
                    }[$level.Key]
                    
                    if ($level.Value -gt 0) {
                        Write-Host "   $($level.Key): " -NoNewline -ForegroundColor $color
                        Write-Host $level.Value
                    }
                }
                
                # Recent activity
                $recentLogs = $content | Select-Object -Last 5
                if ($recentLogs) {
                    Write-Host "`n🕒 Recent Activity:" -ForegroundColor Yellow
                    foreach ($log in $recentLogs) {
                        if ($log -match '^\[([\d-\s:.]+)\]\s+\[(\w+)\s*\]\s+\[([^\]]+)\]\s+(.*)$') {
                            $time = [DateTime]::Parse($Matches[1])
                            $timeDiff = (Get-Date) - $time
                            $timeAgo = if ($timeDiff.TotalMinutes -lt 1) { 
                                "$([int]$timeDiff.TotalSeconds)s ago" 
                            } elseif ($timeDiff.TotalHours -lt 1) { 
                                "$([int]$timeDiff.TotalMinutes)m ago" 
                            } else { 
                                "$([int]$timeDiff.TotalHours)h ago" 
                            }
                            
                            Write-Host "   [$timeAgo] " -NoNewline -ForegroundColor DarkGray
                            Write-Host "$($Matches[3]): " -NoNewline -ForegroundColor Cyan
                            Write-Host $($Matches[4].Substring(0, [Math]::Min(50, $Matches[4].Length))) -ForegroundColor White
                        }
                    }
                }
            }
        }
    }
    
    # Transcript info
    if ($transcriptFiles) {
        Write-Host "`n📜 Transcripts: " -NoNewline -ForegroundColor Cyan
        Write-Host "$($transcriptFiles.Count) files"
        $transcriptSize = ($transcriptFiles | Measure-Object -Property Length -Sum).Sum / 1MB
        Write-Host "   Size: $([Math]::Round($transcriptSize, 2)) MB" -ForegroundColor DarkGray
    }
}

function Show-LogMenu {
    Write-Host "`n🔧 ACTIONS" -ForegroundColor Yellow
    Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host "[1] View Today's Log        [6] Search Logs"
    Write-Host "[2] View Log Tail          [7] Export Report"
    Write-Host "[3] View Transcript        [8] Clear Old Logs"
    Write-Host "[4] Filter Logs            [9] Toggle Auto-Refresh"
    Write-Host "[5] View Audit Logs        [0] Settings"
    Write-Host ""
    Write-Host "[r] Refresh                [q] Quit"
}

function Process-MenuChoice {
    param([string]$Choice)
    
    switch ($Choice) {
        '1' { Show-TodayLog }
        '2' { Show-LogTail }
        '3' { Show-Transcript }
        '4' { Set-LogFilter }
        '5' { Show-AuditLogs }
        '6' { Search-InteractiveLogs }
        '7' { Export-InteractiveReport }
        '8' { Clear-OldLogs }
        '9' { Toggle-AutoRefresh }
        '0' { Show-Settings }
        'r' { Clear-Host }
        'q' { return }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
}

function Show-TodayLog {
    param([int]$Lines = 50)
    
    $logFile = Join-Path $script:LogPath "aitherzero-$(Get-Date -Format 'yyyy-MM-dd').log"
    
    if (Test-Path $logFile) {
        Write-Host "`n📋 TODAY'S LOG (Last $Lines lines)" -ForegroundColor Yellow
        Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
        
        Get-Content $logFile -Tail $Lines | ForEach-Object {
            if ($_ -match '^\[([\d-\s:.]+)\]\s+\[(\w+)\s*\]\s+\[([^\]]+)\]\s+(.*)$') {
                $level = $Matches[2].Trim()
                $color = @{
                    'CRITICAL' = 'Magenta'
                    'ERROR' = 'Red'
                    'WARNING' = 'Yellow'
                    'INFORMATION' = 'White'
                    'DEBUG' = 'Gray'
                    'TRACE' = 'DarkGray'
                }[$level] ?? 'White'
                
                Write-Host $_ -ForegroundColor $color
            } else {
                Write-Host $_
            }
        }
    } else {
        Write-Host "No log file found for today" -ForegroundColor Yellow
    }
    
    Read-Host "`nPress Enter to continue"
}

function Show-LogTail {
    param([int]$Lines = 20)
    
    $logFile = Join-Path $script:LogPath "aitherzero-$(Get-Date -Format 'yyyy-MM-dd').log"
    
    if (Test-Path $logFile) {
        Write-Host "`n📜 LOG TAIL (Last $Lines lines)" -ForegroundColor Yellow
        Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
        
        Get-Content $logFile -Tail $Lines -Wait | ForEach-Object {
            if ($_ -match '\[ERROR\s*\]') {
                Write-Host $_ -ForegroundColor Red
            } elseif ($_ -match '\[WARNING\s*\]') {
                Write-Host $_ -ForegroundColor Yellow
            } elseif ($_ -match '\[DEBUG\s*\]') {
                Write-Host $_ -ForegroundColor Gray
            } else {
                Write-Host $_
            }
            
            # Check for key press to stop
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if ($key.KeyChar -eq 'q') { break }
            }
        }
    }
}

function Show-Transcript {
    $transcriptFile = Get-ChildItem -Path $script:LogPath -Filter "transcript-*.log" | 
        Sort-Object LastWriteTime -Descending | 
        Select-Object -First 1
    
    if ($transcriptFile) {
        Write-Host "`n📜 POWERSHELL TRANSCRIPT" -ForegroundColor Yellow
        Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
        Write-Host "File: $($transcriptFile.Name)" -ForegroundColor Cyan
        Write-Host "Size: $([Math]::Round($transcriptFile.Length / 1KB, 2)) KB" -ForegroundColor Cyan
        Write-Host "`nLast 50 lines:" -ForegroundColor Yellow
        
        Get-Content $transcriptFile.FullName -Tail 50 | Write-Host
        
        Read-Host "`nPress Enter to continue"
    } else {
        Write-Host "No transcript file found" -ForegroundColor Yellow
    }
}

function Set-LogFilter {
    Write-Host "`n🔍 LOG FILTER SETTINGS" -ForegroundColor Yellow
    Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    
    Write-Host "Current Filters:" -ForegroundColor Cyan
    Write-Host "  Level: $($script:FilterSettings.Level ?? 'All')"
    Write-Host "  Source: $($script:FilterSettings.Source ?? 'All')"
    Write-Host "  Pattern: $($script:FilterSettings.Pattern ?? 'None')"
    Write-Host "  Time Range: $($script:FilterSettings.TimeRange)"
    
    Write-Host "`nSet new filters (press Enter to keep current):" -ForegroundColor Yellow
    
    $newLevel = Read-Host "Level (Trace/Debug/Information/Warning/Error/Critical)"
    if ($newLevel) { $script:FilterSettings.Level = $newLevel }
    
    $newSource = Read-Host "Source filter"
    if ($newSource) { $script:FilterSettings.Source = $newSource }
    
    $newPattern = Read-Host "Search pattern"
    if ($newPattern) { $script:FilterSettings.Pattern = $newPattern }
    
    Write-Host "`nFilters updated!" -ForegroundColor Green
}

function Search-InteractiveLogs {
    $searchTerm = Read-Host "`nEnter search term"
    
    if ($searchTerm) {
        Write-Host "`n🔍 SEARCH RESULTS" -ForegroundColor Yellow
        Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
        
        $logFiles = Get-ChildItem -Path $script:LogPath -Filter "*.log"
        $results = @()
        
        foreach ($file in $logFiles) {
            $matches = Select-String -Path $file.FullName -Pattern $searchTerm
            if ($matches) {
                $results += $matches
                Write-Host "`n📁 $($file.Name):" -ForegroundColor Cyan
                $matches | Select-Object -First 10 | ForEach-Object {
                    Write-Host "  Line $($_.LineNumber): $($_.Line)"
                }
            }
        }
        
        Write-Host "`nTotal matches: $($results.Count)" -ForegroundColor Green
        Read-Host "`nPress Enter to continue"
    }
}

function Export-InteractiveReport {
    Write-Host "`n📊 EXPORT LOG REPORT" -ForegroundColor Yellow
    Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    
    Write-Host "[1] HTML Report"
    Write-Host "[2] JSON Export"
    Write-Host "[3] CSV Summary"
    
    $format = Read-Host "`nSelect format"
    
    if (Get-Command Export-LogReport -ErrorAction SilentlyContinue) {
        $reportPath = Export-LogReport -Format @{
            '1' = 'HTML'
            '2' = 'JSON'
            '3' = 'CSV'
        }[$format] ?? 'HTML'
        
        Write-Host "`n✅ Report exported to: $reportPath" -ForegroundColor Green
        
        if ($format -eq '1' -and $IsWindows) {
            $open = Read-Host "Open in browser? (Y/N)"
            if ($open -eq 'Y') {
                Start-Process $reportPath
            }
        }
    }
    
    Read-Host "`nPress Enter to continue"
}

function Clear-OldLogs {
    Write-Host "`n🗑️ CLEAR OLD LOGS" -ForegroundColor Yellow
    Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    
    $days = Read-Host "Keep logs from last how many days? (default: 7)"
    if (-not $days) { $days = 7 }
    
    if (Get-Command Clear-Logs -ErrorAction SilentlyContinue) {
        Clear-Logs -DaysToKeep $days -Confirm
        Write-Host "✅ Old logs cleared" -ForegroundColor Green
    }
    
    Read-Host "`nPress Enter to continue"
}

function Toggle-AutoRefresh {
    $script:AutoRefresh = -not $script:AutoRefresh
    Write-Host "`n✅ Auto-refresh: $($script:AutoRefresh ? 'Enabled' : 'Disabled')" -ForegroundColor Green
    Start-Sleep -Seconds 1
}

function Show-Settings {
    Write-Host "`n⚙️ LOGGING SETTINGS" -ForegroundColor Yellow
    Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    
    if (Get-Module -Name Logging) {
        $loggingModule = Get-Module -Name Logging
        
        Write-Host "Module Version: $($loggingModule.Version)" -ForegroundColor Cyan
        Write-Host "Module Path: $($loggingModule.Path)" -ForegroundColor Cyan
        
        # Get current settings using reflection if available
        Write-Host "`nCurrent Configuration:" -ForegroundColor Yellow
        
        if (Get-Command Get-LogPath -ErrorAction SilentlyContinue) {
            Write-Host "  Log Path: $(Get-LogPath)" -ForegroundColor White
        }
        
        Write-Host "`nActions:" -ForegroundColor Yellow
        Write-Host "[1] Change Log Level"
        Write-Host "[2] Change Log Targets"
        Write-Host "[3] Enable/Disable Rotation"
        Write-Host "[4] Enable/Disable Audit Logging"
        Write-Host "[5] Toggle Transcript Logging"
        
        $action = Read-Host "`nSelect action (or Enter to go back)"
        
        switch ($action) {
            '1' {
                $level = Read-Host "Enter log level (Trace/Debug/Information/Warning/Error/Critical)"
                if ($level -and (Get-Command Set-LogLevel -ErrorAction SilentlyContinue)) {
                    Set-LogLevel -Level $level
                    Write-Host "✅ Log level set to: $level" -ForegroundColor Green
                }
            }
            '2' {
                Write-Host "Available targets: Console, File, Json, EventLog"
                $targets = Read-Host "Enter targets (comma-separated)"
                if ($targets -and (Get-Command Set-LogTargets -ErrorAction SilentlyContinue)) {
                    Set-LogTargets -Targets ($targets -split ',')
                    Write-Host "✅ Log targets updated" -ForegroundColor Green
                }
            }
            '3' {
                $enable = Read-Host "Enable log rotation? (Y/N)"
                if ($enable -eq 'Y') {
                    if (Get-Command Enable-LogRotation -ErrorAction SilentlyContinue) {
                        Enable-LogRotation
                        Write-Host "✅ Log rotation enabled" -ForegroundColor Green
                    }
                } else {
                    if (Get-Command Disable-LogRotation -ErrorAction SilentlyContinue) {
                        Disable-LogRotation
                        Write-Host "✅ Log rotation disabled" -ForegroundColor Green
                    }
                }
            }
            '4' {
                $enable = Read-Host "Enable audit logging? (Y/N)"
                if ($enable -eq 'Y') {
                    if (Get-Command Enable-AuditLogging -ErrorAction SilentlyContinue) {
                        Enable-AuditLogging
                        Write-Host "✅ Audit logging enabled" -ForegroundColor Green
                    }
                } else {
                    if (Get-Command Disable-AuditLogging -ErrorAction SilentlyContinue) {
                        Disable-AuditLogging
                        Write-Host "✅ Audit logging disabled" -ForegroundColor Green
                    }
                }
            }
            '5' {
                Toggle-TranscriptLogging
            }
        }
    }
    
    Read-Host "`nPress Enter to continue"
}

function Show-AuditLogs {
    Write-Host "`n🔒 AUDIT LOGS" -ForegroundColor Yellow
    Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    
    $auditPath = Join-Path $script:LogPath "audit"
    if (Test-Path $auditPath) {
        $auditFiles = Get-ChildItem -Path $auditPath -Filter "*.jsonl"
        
        if ($auditFiles) {
            Write-Host "Found $($auditFiles.Count) audit log files" -ForegroundColor Cyan
            
            if (Get-Command Get-AuditLogs -ErrorAction SilentlyContinue) {
                $recent = Get-AuditLogs -StartTime (Get-Date).AddHours(-24)
                
                if ($recent) {
                    Write-Host "`nLast 24 hours activity:" -ForegroundColor Yellow
                    $recent | Select-Object -First 20 | ForEach-Object {
                        Write-Host "[$($_.Timestamp)] " -NoNewline -ForegroundColor DarkGray
                        Write-Host "$($_.EventType): " -NoNewline -ForegroundColor Cyan
                        Write-Host "$($_.Action) " -NoNewline -ForegroundColor White
                        Write-Host "($($_.Result))" -ForegroundColor $(if ($_.Result -eq 'Success') { 'Green' } else { 'Red' })
                    }
                }
            }
        } else {
            Write-Host "No audit logs found" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Audit logging not configured" -ForegroundColor Yellow
    }
    
    Read-Host "`nPress Enter to continue"
}

function Toggle-TranscriptLogging {
    $transcriptFile = Join-Path $script:LogPath "transcript-$(Get-Date -Format 'yyyy-MM-dd').log"
    
    try {
        Stop-Transcript -ErrorAction SilentlyContinue
        Write-Host "✅ Transcript logging stopped" -ForegroundColor Green
    } catch {
        Start-Transcript -Path $transcriptFile -Append
        Write-Host "✅ Transcript logging started: $transcriptFile" -ForegroundColor Green
    }
}

function Get-LogStatistics {
    <#
    .SYNOPSIS
        Get detailed statistics about logs
    #>
    [CmdletBinding()]
    param(
        [datetime]$StartTime = (Get-Date).AddDays(-7),
        [datetime]$EndTime = (Get-Date)
    )
    
    $stats = @{
        TotalEntries = 0
        ByLevel = @{}
        BySource = @{}
        ByHour = @{}
        Errors = @()
        Warnings = @()
        TopSources = @()
    }
    
    $logFiles = Get-ChildItem -Path $script:LogPath -Filter "*.log" | 
        Where-Object { $_.LastWriteTime -ge $StartTime -and $_.LastWriteTime -le $EndTime }
    
    foreach ($file in $logFiles) {
        $content = Get-Content $file.FullName
        $stats.TotalEntries += $content.Count
        
        foreach ($line in $content) {
            if ($line -match '^\[([\d-\s:.]+)\]\s+\[(\w+)\s*\]\s+\[([^\]]+)\]\s+(.*)$') {
                $timestamp = [DateTime]::Parse($Matches[1])
                $level = $Matches[2].Trim()
                $source = $Matches[3]
                $message = $Matches[4]
                
                # Count by level
                if (-not $stats.ByLevel.ContainsKey($level)) {
                    $stats.ByLevel[$level] = 0
                }
                $stats.ByLevel[$level]++
                
                # Count by source
                if (-not $stats.BySource.ContainsKey($source)) {
                    $stats.BySource[$source] = 0
                }
                $stats.BySource[$source]++
                
                # Count by hour
                $hour = $timestamp.Hour
                if (-not $stats.ByHour.ContainsKey($hour)) {
                    $stats.ByHour[$hour] = 0
                }
                $stats.ByHour[$hour]++
                
                # Collect errors and warnings
                if ($level -eq 'ERROR') {
                    $stats.Errors += [PSCustomObject]@{
                        Timestamp = $timestamp
                        Source = $source
                        Message = $message
                    }
                } elseif ($level -eq 'WARNING') {
                    $stats.Warnings += [PSCustomObject]@{
                        Timestamp = $timestamp
                        Source = $source
                        Message = $message
                    }
                }
            }
        }
    }
    
    # Get top sources
    $stats.TopSources = $stats.BySource.GetEnumerator() | 
        Sort-Object Value -Descending | 
        Select-Object -First 10
    
    return $stats
}

# Export functions
Export-ModuleMember -Function @(
    'Show-LogDashboard',
    'Get-LogStatistics'
)