#Requires -Version 7.0

<#
.SYNOPSIS
    Log viewing and management module for AitherZero
.DESCRIPTION
    Provides comprehensive log viewing, filtering, and management capabilities
#>

$script:ModuleName = 'LogViewer'
$script:ProjectRoot = $env:AITHERZERO_ROOT ?? (Get-Item $PSScriptRoot).Parent.Parent.FullName

# Dynamic command detection for logging
function Write-ModuleLog {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message "[$script:ModuleName] $Message" -Level $Level
    } else {
        Write-Host "[$Level] [$script:ModuleName] $Message"
    }
}

function Get-LogFiles {
    <#
    .SYNOPSIS
        Gets available log files
    .DESCRIPTION
        Returns list of log files with metadata
    .PARAMETER Type
        Type of log files to retrieve (Application, Transcript, All)
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Application', 'Transcript', 'All')]
        [string]$Type = 'All'
    )
    
    $logPath = Join-Path $script:ProjectRoot 'logs'
    
    if (-not (Test-Path $logPath)) {
        Write-ModuleLog "Log directory not found: $logPath" -Level 'Warning'
        return @()
    }
    
    $files = @()
    
    if ($Type -in @('Application', 'All')) {
        $files += Get-ChildItem -Path $logPath -Filter "aitherzero-*.log" | 
            Select-Object Name, FullName, Length, LastWriteTime, 
                @{Name='Type'; Expression={'Application'}},
                @{Name='SizeKB'; Expression={[Math]::Round($_.Length / 1KB, 2)}}
    }
    
    if ($Type -in @('Transcript', 'All')) {
        $files += Get-ChildItem -Path $logPath -Filter "transcript-*.log" |
            Select-Object Name, FullName, Length, LastWriteTime,
                @{Name='Type'; Expression={'Transcript'}},
                @{Name='SizeKB'; Expression={[Math]::Round($_.Length / 1KB, 2)}}
    }
    
    return $files | Sort-Object LastWriteTime -Descending
}

function Show-LogContent {
    <#
    .SYNOPSIS
        Displays log content with formatting
    .DESCRIPTION
        Shows log content with color coding and filtering options
    .PARAMETER Path
        Path to the log file
    .PARAMETER Tail
        Number of lines to show from the end
    .PARAMETER Follow
        Follow the log in real-time
    .PARAMETER Level
        Filter by log level
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [int]$Tail = 30,
        
        [switch]$Follow,
        
        [ValidateSet('Trace', 'Debug', 'Information', 'Warning', 'Error', 'Critical')]
        [string]$Level,
        
        [switch]$NoColor
    )
    
    if (-not (Test-Path $Path)) {
        Write-ModuleLog "Log file not found: $Path" -Level 'Error'
        return
    }
    
    $content = if ($Follow) {
        Write-Host "Following log (press Ctrl+C to stop)..." -ForegroundColor Yellow
        Get-Content $Path -Tail $Tail -Wait
    } else {
        Get-Content $Path -Tail $Tail
    }
    
    # Apply level filter
    if ($Level) {
        $content = $content | Where-Object { $_ -match "\[$Level\s*\]" }
    }
    
    # Colorize output
    $content | ForEach-Object {
        if ($NoColor) {
            Write-Host $_
        } else {
            if ($_ -match '\[CRITICAL\s*\]') {
                Write-Host $_ -ForegroundColor Magenta
            } elseif ($_ -match '\[ERROR\s*\]') {
                Write-Host $_ -ForegroundColor Red
            } elseif ($_ -match '\[WARNING\s*\]') {
                Write-Host $_ -ForegroundColor Yellow
            } elseif ($_ -match '\[DEBUG\s*\]') {
                Write-Host $_ -ForegroundColor Gray
            } elseif ($_ -match '\[TRACE\s*\]') {
                Write-Host $_ -ForegroundColor DarkGray
            } else {
                Write-Host $_
            }
        }
    }
}

function Get-LogStatistics {
    <#
    .SYNOPSIS
        Gets statistics about log files
    .DESCRIPTION
        Returns statistics including log levels, size, and entry counts
    #>
    [CmdletBinding()]
    param(
        [string]$Path
    )
    
    if (-not $Path) {
        $logFiles = Get-LogFiles -Type Application
        if ($logFiles) {
            $Path = $logFiles[0].FullName
        }
    }
    
    if (-not (Test-Path $Path)) {
        return $null
    }
    
    $content = Get-Content $Path
    
    $stats = @{
        FilePath = $Path
        FileName = Split-Path $Path -Leaf
        TotalLines = $content.Count
        SizeKB = [Math]::Round((Get-Item $Path).Length / 1KB, 2)
        LogLevels = @{
            Critical = ($content | Where-Object { $_ -match '\[CRITICAL\s*\]' }).Count
            Error = ($content | Where-Object { $_ -match '\[ERROR\s*\]' }).Count
            Warning = ($content | Where-Object { $_ -match '\[WARNING\s*\]' }).Count
            Information = ($content | Where-Object { $_ -match '\[INFORMATION\s*\]' }).Count
            Debug = ($content | Where-Object { $_ -match '\[DEBUG\s*\]' }).Count
            Trace = ($content | Where-Object { $_ -match '\[TRACE\s*\]' }).Count
        }
        FirstEntry = $null
        LastEntry = $null
    }
    
    if ($content.Count -gt 0) {
        # Extract timestamps
        if ($content[0] -match '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})') {
            $stats.FirstEntry = $Matches[1]
        }
        if ($content[-1] -match '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})') {
            $stats.LastEntry = $Matches[1]
        }
    }
    
    return [PSCustomObject]$stats
}

function Show-LogDashboard {
    <#
    .SYNOPSIS
        Shows an interactive log dashboard
    .DESCRIPTION
        Displays log statistics and provides interactive viewing options
    #>
    [CmdletBinding()]
    param(
        [switch]$AutoRefresh
    )
    
    # Check if we're in non-interactive mode
    $isNonInteractive = -not [Environment]::UserInteractive -or 
                        $env:AITHERZERO_NONINTERACTIVE -eq 'true'
    
    if ($isNonInteractive) {
        # Non-interactive mode - just show summary and exit
        Write-Host "`n  LOG DASHBOARD (Non-Interactive)" -ForegroundColor Cyan
        Write-Host "  ═══════════════════════════════════════════════════════" -ForegroundColor DarkGray
        
        $logFiles = Get-LogFiles -Type All
        if ($logFiles) {
            Write-Host "`n  Available Logs: $($logFiles.Count) files" -ForegroundColor White
            foreach ($file in $logFiles | Select-Object -First 3) {
                $icon = if ($file.Type -eq 'Application') { '📋' } else { '📜' }
                Write-Host "    $icon $($file.Name) ($($file.SizeKB) KB)" -ForegroundColor Gray
            }
            
            $appLog = $logFiles | Where-Object { $_.Type -eq 'Application' } | Select-Object -First 1
            if ($appLog) {
                $stats = Get-LogStatistics -Path $appLog.FullName
                if ($stats) {
                    Write-Host "`n  Statistics:" -ForegroundColor White
                    Write-Host "    Lines: $($stats.TotalLines) | Errors: $($stats.LogLevels.Error) | Warnings: $($stats.LogLevels.Warning)" -ForegroundColor Gray
                }
            }
        }
        
        Write-Host "`n  ℹ️  Run interactively for full dashboard features" -ForegroundColor DarkGray
        return
    }
    
    do {
        Clear-Host
        
        Write-Host "`n  AITHERZERO LOG DASHBOARD" -ForegroundColor Cyan
        Write-Host "  ═══════════════════════════════════════════════════════" -ForegroundColor DarkGray
        
        # Get log files
        $logFiles = Get-LogFiles -Type All
        
        if ($logFiles.Count -eq 0) {
            Write-Host "`n  No log files found" -ForegroundColor Yellow
        } else {
            Write-Host "`n  📁 AVAILABLE LOG FILES:" -ForegroundColor White
            Write-Host "  ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
            
            $i = 1
            foreach ($file in $logFiles | Select-Object -First 10) {
                $icon = if ($file.Type -eq 'Application') { '📋' } else { '📜' }
                Write-Host "  [$i] $icon $($file.Name) ($($file.SizeKB) KB) - $($file.LastWriteTime)" -ForegroundColor Gray
                $i++
            }
            
            # Get statistics for the latest log
            if ($logFiles.Count -gt 0) {
                $latestLog = $logFiles | Where-Object { $_.Type -eq 'Application' } | Select-Object -First 1
                if ($latestLog) {
                    $stats = Get-LogStatistics -Path $latestLog.FullName
                    
                    if ($stats) {
                        Write-Host "`n  📊 CURRENT LOG STATISTICS:" -ForegroundColor White
                        Write-Host "  ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
                        Write-Host "  File: $($stats.FileName)" -ForegroundColor Gray
                        Write-Host "  Size: $($stats.SizeKB) KB | Lines: $($stats.TotalLines)" -ForegroundColor Gray
                        
                        if ($stats.FirstEntry -and $stats.LastEntry) {
                            Write-Host "  Period: $($stats.FirstEntry) → $($stats.LastEntry)" -ForegroundColor Gray
                        }
                        
                        Write-Host "`n  LOG LEVELS:" -ForegroundColor White
                        if ($stats.LogLevels.Critical -gt 0) {
                            Write-Host "    ⚠️  Critical: $($stats.LogLevels.Critical)" -ForegroundColor Magenta
                        }
                        if ($stats.LogLevels.Error -gt 0) {
                            Write-Host "    ❌ Error:    $($stats.LogLevels.Error)" -ForegroundColor Red
                        }
                        if ($stats.LogLevels.Warning -gt 0) {
                            Write-Host "    ⚠️  Warning:  $($stats.LogLevels.Warning)" -ForegroundColor Yellow
                        }
                        Write-Host "    ℹ️  Info:     $($stats.LogLevels.Information)" -ForegroundColor Cyan
                        Write-Host "    🔍 Debug:    $($stats.LogLevels.Debug)" -ForegroundColor Gray
                        Write-Host "    📝 Trace:    $($stats.LogLevels.Trace)" -ForegroundColor DarkGray
                    }
                }
            }
        }
        
        Write-Host "`n  ⚡ QUICK ACTIONS:" -ForegroundColor White
        Write-Host "  ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "  [V] View latest log     [T] View transcript" -ForegroundColor Gray
        Write-Host "  [F] Follow log          [E] View errors only" -ForegroundColor Gray
        Write-Host "  [S] Search logs         [C] Clear old logs" -ForegroundColor Gray
        Write-Host "  [R] Refresh             [Q] Quit" -ForegroundColor Gray
        Write-Host ""
        
        if (-not $AutoRefresh) {
            $choice = Read-Host "Select action"
            
            switch ($choice.ToUpper()) {
                'V' {
                    $latest = $logFiles | Where-Object { $_.Type -eq 'Application' } | Select-Object -First 1
                    if ($latest) {
                        Show-LogContent -Path $latest.FullName -Tail 50
                        Read-Host "`nPress Enter to continue"
                    }
                }
                'T' {
                    $transcript = $logFiles | Where-Object { $_.Type -eq 'Transcript' } | Select-Object -First 1
                    if ($transcript) {
                        Show-LogContent -Path $transcript.FullName -Tail 50
                        Read-Host "`nPress Enter to continue"
                    }
                }
                'F' {
                    $latest = $logFiles | Where-Object { $_.Type -eq 'Application' } | Select-Object -First 1
                    if ($latest) {
                        Show-LogContent -Path $latest.FullName -Follow -Tail 20
                    }
                }
                'E' {
                    $latest = $logFiles | Where-Object { $_.Type -eq 'Application' } | Select-Object -First 1
                    if ($latest) {
                        Show-LogContent -Path $latest.FullName -Level Error -Tail 100
                        Read-Host "`nPress Enter to continue"
                    }
                }
                'S' {
                    $searchTerm = Read-Host "Enter search term"
                    Search-Logs -Pattern $searchTerm
                    Read-Host "`nPress Enter to continue"
                }
                'C' {
                    Clear-OldLogs
                    Read-Host "`nPress Enter to continue"
                }
                'Q' {
                    return
                }
            }
        } else {
            Start-Sleep -Seconds 5
        }
        
    } while ($true)
}

function Search-Logs {
    <#
    .SYNOPSIS
        Searches through log files
    .DESCRIPTION
        Searches for patterns in log files
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Pattern,
        
        [ValidateSet('Application', 'Transcript', 'All')]
        [string]$Type = 'All'
    )
    
    $logFiles = Get-LogFiles -Type $Type
    $results = @()
    
    foreach ($file in $logFiles) {
        $matches = Select-String -Path $file.FullName -Pattern $Pattern
        if ($matches) {
            $results += [PSCustomObject]@{
                File = $file.Name
                Matches = $matches.Count
                Lines = $matches | Select-Object -First 5 | ForEach-Object { $_.Line }
            }
        }
    }
    
    if ($results) {
        Write-Host "`n🔍 SEARCH RESULTS FOR: '$Pattern'" -ForegroundColor Cyan
        foreach ($result in $results) {
            Write-Host "`n  📄 $($result.File) ($($result.Matches) matches)" -ForegroundColor Yellow
            foreach ($line in $result.Lines) {
                Write-Host "    $line" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "No matches found for '$Pattern'" -ForegroundColor Yellow
    }
}

function Clear-OldLogs {
    <#
    .SYNOPSIS
        Clears old log files
    .DESCRIPTION
        Removes log files older than specified days
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [int]$DaysToKeep = 7
    )
    
    $logPath = Join-Path $script:ProjectRoot 'logs'
    $cutoffDate = (Get-Date).AddDays(-$DaysToKeep)
    
    $oldFiles = Get-ChildItem -Path $logPath -Filter "*.log" | 
        Where-Object { $_.LastWriteTime -lt $cutoffDate }
    
    if ($oldFiles) {
        Write-Host "Found $($oldFiles.Count) log files older than $DaysToKeep days" -ForegroundColor Yellow
        
        if ($PSCmdlet.ShouldProcess("$($oldFiles.Count) old log files", "Remove")) {
            $oldFiles | Remove-Item -Force
            Write-Host "Removed $($oldFiles.Count) old log files" -ForegroundColor Green
        }
    } else {
        Write-Host "No log files older than $DaysToKeep days found" -ForegroundColor Green
    }
}

function Get-LoggingStatus {
    <#
    .SYNOPSIS
        Gets current logging status
    .DESCRIPTION
        Returns information about logging configuration and status
    #>
    [CmdletBinding()]
    param()
    
    $status = @{
        ModuleLoaded = $null -ne (Get-Module -Name Logging)
        LogPath = $null
        TranscriptActive = $false
        FileLoggingEnabled = $false
        CurrentLogFile = $null
        Configuration = $null
    }
    
    if ($status.ModuleLoaded) {
        if (Get-Command Get-LogPath -ErrorAction SilentlyContinue) {
            $status.LogPath = Get-LogPath
            if ($status.LogPath -and (Test-Path $status.LogPath)) {
                $status.CurrentLogFile = Get-Item $status.LogPath
                $status.FileLoggingEnabled = $true
            }
        }
        
        if (Get-Command Get-LoggingConfiguration -ErrorAction SilentlyContinue) {
            $status.Configuration = Get-LoggingConfiguration
        }
    }
    
    # Check for active transcript
    try {
        Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
        Start-Transcript -Append -ErrorAction SilentlyContinue | Out-Null
        $status.TranscriptActive = $true
    } catch {
        $status.TranscriptActive = $false
    }
    
    return [PSCustomObject]$status
}

# Initialize module
Write-ModuleLog "LogViewer module initialized"

# Export functions
Export-ModuleMember -Function @(
    'Get-LogFiles'
    'Show-LogContent'
    'Get-LogStatistics'
    'Show-LogDashboard'
    'Search-Logs'
    'Clear-OldLogs'
    'Get-LoggingStatus'
)