#Requires -Version 7.0

<#
.SYNOPSIS
    Schedule automatic report generation for AitherZero project
.DESCRIPTION
    Sets up scheduled report generation using either cron (Linux/Mac) or Task Scheduler (Windows)
    Reports are generated daily at 9 AM and after test runs
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ProjectPath = ($PSScriptRoot | Split-Path -Parent),
    [ValidateSet('Daily', 'Hourly', 'OnTestRun', 'Disable')]
    [string]$Schedule = 'Daily',
    [string]$Time = '09:00'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import logging module
$loggingModule = Join-Path $ProjectPath "domains/utilities/Logging.psm1"
if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force
}

function Write-ScheduleLog {
    param([string]$Message, [string]$Level = 'Information')
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "ReportScheduler"
    } else {
        Write-Host "[$Level] $Message"
    }
}

Write-ScheduleLog "Configuring report generation schedule: $Schedule"

# Create wrapper script for cron
$wrapperScript = @'
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
'@

$wrapperPath = Join-Path $ProjectPath ".tools/scheduled-report.ps1"
$wrapperDir = Split-Path $wrapperPath -Parent
if (-not (Test-Path $wrapperDir)) {
    if ($PSCmdlet.ShouldProcess($wrapperDir, "Create directory")) {
        New-Item -ItemType Directory -Path $wrapperDir -Force | Out-Null
    }
}
if ($PSCmdlet.ShouldProcess($wrapperPath, "Create wrapper script")) {
    $wrapperScript | Set-Content $wrapperPath -Force
}

if ($IsWindows) {
    Write-ScheduleLog "Configuring Windows Task Scheduler"

    $taskName = "AitherZero-ReportGeneration"
    $action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-File `"$wrapperPath`""

    switch ($Schedule) {
        'Daily' {
            $trigger = New-ScheduledTaskTrigger -Daily -At $Time
        }
        'Hourly' {
            $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)
        }
        'OnTestRun' {
            Write-ScheduleLog "OnTestRun schedule is handled by hooks, not Task Scheduler"
            return
        }
        'Disable' {
            if ($PSCmdlet.ShouldProcess($taskName, "Remove scheduled task")) {
                try {
                    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
                    Write-ScheduleLog "Scheduled report generation disabled"
                } catch {
                    Write-ScheduleLog "No scheduled task found to disable" -Level 'Warning'
                }
            }
            return
        }
    }

    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

    if ($PSCmdlet.ShouldProcess($taskName, "Create/update scheduled task")) {
        try {
            # Remove existing task if present
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

            # Register new task
            Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "Automatic report generation for AitherZero project"
            Write-ScheduleLog "Windows scheduled task created successfully"
        } catch {
            Write-ScheduleLog "Failed to create Windows scheduled task: $_" -Level 'Error'
        }
    }

} else {
    Write-ScheduleLog "Configuring cron job for Linux/Mac"

    # Create cron entry
    $cronTime = switch ($Schedule) {
        'Daily' {
            $hour = [int]($Time.Split(':')[0])
            $minute = [int]($Time.Split(':')[1])
            "$minute $hour * * *"
        }
        'Hourly' {
            "0 * * * *"
        }
        'OnTestRun' {
            Write-ScheduleLog "OnTestRun schedule is handled by hooks, not cron"
            return
        }
        'Disable' {
            # Remove cron job
            if ($PSCmdlet.ShouldProcess("cron job", "Remove scheduled cron job")) {
                try {
                    $currentCron = crontab -l 2>/dev/null | Where-Object { $_ -notmatch 'AitherZero.*scheduled-report' }
                    if ($currentCron) {
                        $currentCron | crontab -
                    } else {
                        crontab -r 2>/dev/null
                    }
                    Write-ScheduleLog "Cron job removed successfully"
                } catch {
                    Write-ScheduleLog "No cron job found to remove" -Level 'Warning'
                }
            }
            return
        }
    }

    $cronEntry = "$cronTime cd $ProjectPath && /usr/bin/pwsh $wrapperPath >> $ProjectPath/logs/cron-reports.log 2>&1 # AitherZero scheduled-report"

    if ($PSCmdlet.ShouldProcess("cron job", "Create/update scheduled cron job")) {
        try {
            # Get current crontab
            $currentCron = @(crontab -l 2>/dev/null | Where-Object { $_ -notmatch 'AitherZero.*scheduled-report' })

            # Add new entry
            $newCron = $currentCron + $cronEntry

            # Set new crontab
            $newCron | crontab -

            Write-ScheduleLog "Cron job configured successfully: $cronTime"
            Write-ScheduleLog "View with: crontab -l"
        } catch {
            Write-ScheduleLog "Failed to configure cron job: $_" -Level 'Error'
        }
    }
}

# Configure hook-based triggers
if ($Schedule -eq 'OnTestRun' -or $Schedule -eq 'Daily') {
    $hookConfig = Join-Path $ProjectPath ".claude/settings.json"
    if (Test-Path $hookConfig) {
        try {
            $config = Get-Content $hookConfig -Raw | ConvertFrom-Json

            # Ensure report generation is enabled in hooks
            if (-not $config.PSObject.Properties['reporting']) {
                $config | Add-Member -MemberType NoteProperty -Name 'reporting' -Value @{} -Force
            }

            $config.reporting = @{
                autoGenerate = $true
                onTestRun = ($Schedule -eq 'OnTestRun' -or $Schedule -eq 'Daily')
                formats = @('HTML', 'JSON', 'Markdown')
                retentionDays = 7
            }

            if ($PSCmdlet.ShouldProcess($hookConfig, "Update hook configuration")) {
                $config | ConvertTo-Json -Depth 10 | Set-Content $hookConfig
                Write-ScheduleLog "Hook configuration updated for automatic report generation"
            }
        } catch {
            Write-ScheduleLog "Failed to update hook configuration: $_" -Level 'Warning'
        }
    }
}

Write-ScheduleLog "Report generation schedule configuration complete"

# Display current schedule
Write-Host ""
Write-Host "Report Generation Schedule:" -ForegroundColor Cyan
Write-Host "===========================" -ForegroundColor Cyan

if ($Schedule -eq 'Disable') {
    Write-Host "Automatic report generation is DISABLED" -ForegroundColor Yellow
} else {
    Write-Host "Schedule Type: $Schedule" -ForegroundColor Green
    if ($Schedule -eq 'Daily') {
        Write-Host "Time: $Time" -ForegroundColor Green
    }
    Write-Host "Reports Path: $ProjectPath/tests/reports" -ForegroundColor Green
    Write-Host ""
    Write-Host "Reports will be generated:" -ForegroundColor Cyan
    Write-Host "  - Automatically based on schedule" -ForegroundColor White
    Write-Host "  - After test runs (if enabled)" -ForegroundColor White
    Write-Host "  - Manually via: ./az 0510" -ForegroundColor White
}

Write-Host ""
Write-Host "To view the latest report:" -ForegroundColor Cyan
Write-Host "  ./az 0511 -ShowAll" -ForegroundColor White