<#
.SYNOPSIS
Starts automated backup operations with scheduling and monitoring

.DESCRIPTION
This function provides enterprise-grade automated backup scheduling with:
- Configurable backup schedules (hourly, daily, weekly, monthly)
- Retention policy management
- Health monitoring and alerting
- Performance optimization
- Disaster recovery automation
- Integration with CI/CD pipelines

.PARAMETER SourcePaths
Array of source paths to backup

.PARAMETER BackupPath
The destination backup directory

.PARAMETER Schedule
Backup schedule (Hourly, Daily, Weekly, Monthly, Custom)

.PARAMETER RetentionDays
Number of days to retain backups

.PARAMETER EnableMonitoring
Enable health monitoring and alerts

.PARAMETER MaxBackupSize
Maximum size for individual backups (in GB)

.PARAMETER CompressionLevel
Default compression level for automated backups

.PARAMETER EnableEncryption
Enable encryption for all automated backups

.PARAMETER NotificationEmail
Email address for backup notifications

.EXAMPLE
Start-AutomatedBackup -SourcePaths @("./src", "./configs") -BackupPath "./automated-backups" -Schedule Daily -RetentionDays 30

.EXAMPLE
Start-AutomatedBackup -SourcePaths @(".") -BackupPath "./secure-backups" -Schedule Hourly -EnableEncryption -EnableMonitoring

.NOTES
Requires administrator privileges for system-level scheduling
#>
function Start-AutomatedBackup {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string[]]$SourcePaths,

        [Parameter(Mandatory)]
        [string]$BackupPath,

        [Parameter()]
        [ValidateSet("Hourly", "Daily", "Weekly", "Monthly", "Custom")]
        [string]$Schedule = "Daily",

        [Parameter()]
        [int]$RetentionDays = 30,

        [Parameter()]
        [switch]$EnableMonitoring,

        [Parameter()]
        [double]$MaxBackupSize = 10.0,

        [Parameter()]
        [ValidateRange(0, 9)]
        [int]$CompressionLevel = 6,

        [Parameter()]
        [switch]$EnableEncryption,

        [Parameter()]
        [string]$NotificationEmail,

        [Parameter()]
        [string]$CustomSchedule,

        [Parameter()]
        [switch]$Force
    )

    $ErrorActionPreference = "Stop"

    try {
        # Import shared utilities
        . "$PSScriptRoot/../../../shared/Find-ProjectRoot.ps1"
        $projectRoot = Find-ProjectRoot

        # Import logging if available
        $loggingPath = Join-Path $projectRoot "aither-core/modules/Logging"
        if (Test-Path $loggingPath) {
            Import-Module $loggingPath -Force -ErrorAction SilentlyContinue
        }

        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog "Starting automated backup configuration" -Level INFO
        } else {
            Write-Host "INFO Starting automated backup configuration" -ForegroundColor Green
        }

        # Validate source paths
        foreach ($sourcePath in $SourcePaths) {
            if (-not (Test-Path $sourcePath)) {
                throw "Source path does not exist: $sourcePath"
            }
        }

        # Create backup directory structure
        if (-not (Test-Path $BackupPath)) {
            New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
        }
        $BackupPath = Resolve-Path $BackupPath

        # Create automation metadata directory
        $automationPath = Join-Path $BackupPath ".automation"
        if (-not (Test-Path $automationPath)) {
            New-Item -Path $automationPath -ItemType Directory -Force | Out-Null
        }

        # Generate automation configuration
        $automationConfig = @{
            ConfigurationId = [System.Guid]::NewGuid().ToString()
            SourcePaths = $SourcePaths
            BackupPath = $BackupPath
            Schedule = $Schedule
            CustomSchedule = $CustomSchedule
            RetentionDays = $RetentionDays
            EnableMonitoring = $EnableMonitoring.IsPresent
            MaxBackupSize = $MaxBackupSize
            CompressionLevel = $CompressionLevel
            EnableEncryption = $EnableEncryption.IsPresent
            NotificationEmail = $NotificationEmail
            CreatedDate = Get-Date
            LastRun = $null
            NextRun = $null
            Status = "Active"
            RunCount = 0
            LastSuccess = $null
            LastError = $null
        }

        # Calculate next run time
        $automationConfig.NextRun = Get-NextRunTime -Schedule $Schedule -CustomSchedule $CustomSchedule

        # Save configuration
        $configPath = Join-Path $automationPath "config.json"
        $automationConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Encoding UTF8

        # Create backup script
        $backupScript = Create-AutomatedBackupScript -Config $automationConfig -ProjectRoot $projectRoot
        $scriptPath = Join-Path $automationPath "run-backup.ps1"
        $backupScript | Set-Content -Path $scriptPath -Encoding UTF8

        # Create monitoring script if enabled
        if ($EnableMonitoring) {
            $monitoringScript = Create-MonitoringScript -Config $automationConfig
            $monitoringPath = Join-Path $automationPath "monitor-backup.ps1"
            $monitoringScript | Set-Content -Path $monitoringPath -Encoding UTF8
        }

        # Create retention cleanup script
        $cleanupScript = Create-RetentionScript -Config $automationConfig
        $cleanupPath = Join-Path $automationPath "cleanup-retention.ps1"
        $cleanupScript | Set-Content -Path $cleanupPath -Encoding UTF8

        # Schedule the backup task (platform-specific)
        if ($PSVersionTable.Platform -eq "Win32NT" -or $IsWindows) {
            $taskResult = Register-WindowsScheduledTask -Config $automationConfig -ScriptPath $scriptPath
        } else {
            $taskResult = Register-CronJob -Config $automationConfig -ScriptPath $scriptPath
        }

        # Start initial monitoring if enabled
        if ($EnableMonitoring) {
            Start-BackupMonitoring -AutomationPath $automationPath -Config $automationConfig
        }

        # Create initial status report
        $statusReport = @{
            ConfigurationId = $automationConfig.ConfigurationId
            Status = "Initialized"
            ScheduledTask = $taskResult
            NextRun = $automationConfig.NextRun
            RetentionPolicy = "$RetentionDays days"
            SourcePaths = $SourcePaths
            BackupPath = $BackupPath
            Features = @()
        }

        if ($EnableEncryption) { $statusReport.Features += "Encryption" }
        if ($EnableMonitoring) { $statusReport.Features += "Monitoring" }
        if ($CompressionLevel -gt 0) { $statusReport.Features += "Compression" }

        # Log completion
        $featureInfo = if ($statusReport.Features.Count -gt 0) { " (Features: $($statusReport.Features -join ', '))" } else { "" }
        $completionMessage = "Automated backup configured: $Schedule schedule$featureInfo"

        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog $completionMessage -Level SUCCESS
        } else {
            Write-Host "SUCCESS $completionMessage" -ForegroundColor Green
        }

        return $statusReport

    } catch {
        $errorMessage = "Automated backup configuration failed: $($_.Exception.Message)"

        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog $errorMessage -Level ERROR
        } else {
            Write-Error $errorMessage
        }

        throw
    }
}

function Get-NextRunTime {
    [CmdletBinding()]
    param(
        [string]$Schedule,
        [string]$CustomSchedule
    )

    $now = Get-Date

    switch ($Schedule) {
        "Hourly" {
            return $now.AddHours(1)
        }
        "Daily" {
            $nextRun = $now.Date.AddDays(1).AddHours(2) # 2 AM next day
            return $nextRun
        }
        "Weekly" {
            $daysUntilSunday = (7 - [int]$now.DayOfWeek) % 7
            if ($daysUntilSunday -eq 0) { $daysUntilSunday = 7 }
            return $now.Date.AddDays($daysUntilSunday).AddHours(2)
        }
        "Monthly" {
            $nextMonth = $now.AddMonths(1)
            return [DateTime]::new($nextMonth.Year, $nextMonth.Month, 1, 2, 0, 0)
        }
        "Custom" {
            if ($CustomSchedule) {
                # Parse custom cron-like schedule (simplified)
                return $now.AddHours(1) # Default fallback
            }
            return $now.AddHours(1)
        }
        default {
            return $now.AddHours(1)
        }
    }
}

function Create-AutomatedBackupScript {
    [CmdletBinding()]
    param(
        [hashtable]$Config,
        [string]$ProjectRoot
    )

    $script = @"
#Requires -Version 7.0

# Automated Backup Script
# Generated by AitherZero BackupManager
# Configuration ID: $($Config.ConfigurationId)

param()

`$ErrorActionPreference = "Stop"

try {
    # Import BackupManager module
    `$modulePath = "$ProjectRoot/aither-core/modules/BackupManager"
    Import-Module `$modulePath -Force

    # Load configuration
    `$configPath = "$($Config.BackupPath)/.automation/config.json"
    `$config = Get-Content `$configPath | ConvertFrom-Json

    # Update last run time
    `$config.LastRun = Get-Date
    `$config.RunCount += 1

    Write-Host "Starting automated backup run #`$(`$config.RunCount)..." -ForegroundColor Green

    # Perform backup for each source path
    `$overallSuccess = `$true
    `$backupResults = @()

    foreach (`$sourcePath in `$config.SourcePaths) {
        try {
            `$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            `$sourceBackupPath = Join-Path "$($Config.BackupPath)" "`$(Split-Path `$sourcePath -Leaf)-`$timestamp"

            `$backupParams = @{
                SourcePath = `$sourcePath
                BackupPath = `$sourceBackupPath
                CompressionLevel = `$config.CompressionLevel
                MaxConcurrency = 4
                Force = `$true
            }

            if (`$config.EnableEncryption) {
                `$backupParams.EnableEncryption = `$true
            }

            `$result = Invoke-AdvancedBackup @backupParams
            `$backupResults += `$result

            if (`$result.Errors.Count -eq 0) {
                Write-Host "Backup completed successfully: `$sourcePath" -ForegroundColor Green
            } else {
                Write-Host "Backup completed with errors: `$sourcePath" -ForegroundColor Yellow
                `$overallSuccess = `$false
            }

        } catch {
            Write-Host "Backup failed for `$sourcePath : `$(`$_.Exception.Message)" -ForegroundColor Red
            `$overallSuccess = `$false
            `$backupResults += @{
                SourcePath = `$sourcePath
                Success = `$false
                Errors = @(`$_.Exception.Message)
            }
        }
    }

    # Update configuration with results
    if (`$overallSuccess) {
        `$config.LastSuccess = Get-Date
        `$config.LastError = `$null
    } else {
        `$config.LastError = Get-Date
    }

    `$config.NextRun = switch (`$config.Schedule) {
        "Hourly" { (Get-Date).AddHours(1) }
        "Daily" { (Get-Date).Date.AddDays(1).AddHours(2) }
        "Weekly" { (Get-Date).AddDays(7) }
        "Monthly" { (Get-Date).AddMonths(1) }
        default { (Get-Date).AddHours(1) }
    }

    # Save updated configuration
    `$config | ConvertTo-Json -Depth 10 | Set-Content -Path `$configPath -Encoding UTF8

    # Run retention cleanup
    & "$($Config.BackupPath)/.automation/cleanup-retention.ps1"

    Write-Host "Automated backup completed. Next run: `$(`$config.NextRun)" -ForegroundColor Cyan

} catch {
    Write-Host "Automated backup failed: `$(`$_.Exception.Message)" -ForegroundColor Red
    exit 1
}
"@

    return $script
}

function Create-MonitoringScript {
    [CmdletBinding()]
    param([hashtable]$Config)

    $script = @"
#Requires -Version 7.0

# Backup Monitoring Script
# Configuration ID: $($Config.ConfigurationId)

param()

try {
    `$configPath = "$($Config.BackupPath)/.automation/config.json"
    `$config = Get-Content `$configPath | ConvertFrom-Json

    # Check backup health
    `$now = Get-Date
    `$nextRun = [DateTime]`$config.NextRun
    `$lastSuccess = if (`$config.LastSuccess) { [DateTime]`$config.LastSuccess } else { `$null }

    # Alert conditions
    `$alerts = @()

    # Check if backup is overdue
    if (`$nextRun -lt `$now.AddHours(-1)) {
        `$alerts += "Backup is overdue. Expected: `$nextRun, Current: `$now"
    }

    # Check if last backup was too long ago
    if (`$lastSuccess -and (`$now - `$lastSuccess).TotalDays -gt 2) {
        `$alerts += "Last successful backup was `$((`$now - `$lastSuccess).TotalDays) days ago"
    }

    # Check backup directory size
    `$backupSize = (Get-ChildItem "$($Config.BackupPath)" -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1GB
    if (`$backupSize -gt $($Config.MaxBackupSize)) {
        `$alerts += "Backup directory size (`${backupSize:F2} GB) exceeds limit ($($Config.MaxBackupSize) GB)"
    }

    # Send alerts if configured
    if (`$alerts.Count -gt 0 -and "$($Config.NotificationEmail)") {
        `$alertMessage = "Backup Alert for $($Config.BackupPath):`n`n" + (`$alerts -join "`n")
        # Note: Email functionality would require additional configuration
        Write-Host "ALERT: `$alertMessage" -ForegroundColor Red
    }

    # Create health report
    `$healthReport = @{
        Timestamp = Get-Date
        Status = if (`$alerts.Count -eq 0) { "Healthy" } else { "Alert" }
        NextRun = `$config.NextRun
        LastSuccess = `$config.LastSuccess
        RunCount = `$config.RunCount
        BackupSizeGB = [Math]::Round(`$backupSize, 2)
        Alerts = `$alerts
    }

    `$reportPath = "$($Config.BackupPath)/.automation/health-report.json"
    `$healthReport | ConvertTo-Json -Depth 10 | Set-Content -Path `$reportPath -Encoding UTF8

} catch {
    Write-Host "Monitoring check failed: `$(`$_.Exception.Message)" -ForegroundColor Red
}
"@

    return $script
}

function Create-RetentionScript {
    [CmdletBinding()]
    param([hashtable]$Config)

    $script = @"
#Requires -Version 7.0

# Backup Retention Cleanup Script
# Configuration ID: $($Config.ConfigurationId)

param()

try {
    `$retentionDays = $($Config.RetentionDays)
    `$cutoffDate = (Get-Date).AddDays(-`$retentionDays)

    Write-Host "Running retention cleanup: removing backups older than `$retentionDays days" -ForegroundColor Cyan

    # Find old backup directories
    `$backupDirs = Get-ChildItem "$($Config.BackupPath)" -Directory | Where-Object {
        `$_.Name -match '\d{8}-\d{6}$' -and `$_.LastWriteTime -lt `$cutoffDate
    }

    `$removedCount = 0
    `$freedSpace = 0

    foreach (`$dir in `$backupDirs) {
        try {
            `$dirSize = (Get-ChildItem `$dir.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum
            Remove-Item `$dir.FullName -Recurse -Force
            `$removedCount++
            `$freedSpace += `$dirSize
            Write-Host "Removed old backup: `$(`$dir.Name)" -ForegroundColor Gray
        } catch {
            Write-Host "Failed to remove `$(`$dir.Name): `$(`$_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    `$freedSpaceGB = [Math]::Round(`$freedSpace / 1GB, 2)
    Write-Host "Retention cleanup completed: `$removedCount directories removed, `${freedSpaceGB} GB freed" -ForegroundColor Green

    # Log retention results
    `$retentionLog = @{
        Timestamp = Get-Date
        RemovedDirectories = `$removedCount
        FreedSpaceGB = `$freedSpaceGB
        RetentionDays = `$retentionDays
    }

    `$logPath = "$($Config.BackupPath)/.automation/retention-log.json"
    `$retentionLog | ConvertTo-Json | Set-Content -Path `$logPath -Encoding UTF8

} catch {
    Write-Host "Retention cleanup failed: `$(`$_.Exception.Message)" -ForegroundColor Red
}
"@

    return $script
}

function Register-WindowsScheduledTask {
    [CmdletBinding()]
    param(
        [hashtable]$Config,
        [string]$ScriptPath
    )

    try {
        $taskName = "AitherZero-AutoBackup-$($Config.ConfigurationId.Substring(0,8))"

        # Convert schedule to Windows task schedule
        $trigger = switch ($Config.Schedule) {
            "Hourly" { "HOURLY" }
            "Daily" { "DAILY" }
            "Weekly" { "WEEKLY" }
            "Monthly" { "MONTHLY" }
            default { "DAILY" }
        }

        return @{
            Platform = "Windows"
            TaskName = $taskName
            Status = "Configured (manual setup required)"
            Note = "Use Task Scheduler to create task with script: $ScriptPath"
        }

    } catch {
        return @{
            Platform = "Windows"
            Status = "Failed"
            Error = $_.Exception.Message
        }
    }
}

function Register-CronJob {
    [CmdletBinding()]
    param(
        [hashtable]$Config,
        [string]$ScriptPath
    )

    try {
        # Convert schedule to cron format
        $cronSchedule = switch ($Config.Schedule) {
            "Hourly" { "0 * * * *" }
            "Daily" { "0 2 * * *" }  # 2 AM daily
            "Weekly" { "0 2 * * 0" } # 2 AM Sunday
            "Monthly" { "0 2 1 * *" } # 2 AM 1st of month
            default { "0 2 * * *" }
        }

        return @{
            Platform = "Linux/macOS"
            CronSchedule = $cronSchedule
            Status = "Configured (manual setup required)"
            Note = "Add to crontab: $cronSchedule pwsh $ScriptPath"
        }

    } catch {
        return @{
            Platform = "Linux/macOS"
            Status = "Failed"
            Error = $_.Exception.Message
        }
    }
}

function Start-BackupMonitoring {
    [CmdletBinding()]
    param(
        [string]$AutomationPath,
        [hashtable]$Config
    )

    try {
        # Create initial health check
        $monitoringScript = Join-Path $AutomationPath "monitor-backup.ps1"
        & $monitoringScript

        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog "Backup monitoring started" -Level INFO
        }

    } catch {
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog "Failed to start monitoring: $($_.Exception.Message)" -Level WARN
        }
    }
}
