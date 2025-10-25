#Requires -Version 7.0
<#
.SYNOPSIS
    Enhanced CI progress reporting with real-time updates
.DESCRIPTION
    Provides comprehensive progress reporting for CI/CD pipelines with:
    - Real-time progress indicators
    - Detailed status updates
    - GitHub Actions integration
    - Time estimation
    - Resource monitoring
#>

[CmdletBinding()]
param(
    [string]$Operation = "General",
    [string]$Stage = "Unknown",
    [int]$TotalSteps = 100,
    [int]$CurrentStep = 0,
    [string]$Message = "",
    [switch]$Complete,
    [switch]$Failed,
    [string]$LogPath = "./logs/ci-progress.log"
)

# Ensure logging directory exists
$logDir = Split-Path $LogPath -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Progress tracking state
$script:ProgressState = @{
    StartTime = Get-Date
    LastUpdate = Get-Date
    TotalOperations = 0
    CompletedOperations = 0
    Errors = @()
    Warnings = @()
}

function Write-CIProgress {
    param(
        [string]$Operation,
        [string]$Stage,
        [int]$Progress,
        [string]$Message,
        [string]$Status = "Running",
        [hashtable]$Metrics = @{}
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $elapsed = (Get-Date) - $script:ProgressState.StartTime

    # Calculate progress percentage
    $percentage = if ($TotalSteps -gt 0) { [math]::Round(($CurrentStep / $TotalSteps) * 100, 1) } else { 0 }

    # Create progress bar
    $barWidth = 40
    $filled = [math]::Floor(($percentage / 100) * $barWidth)
    $empty = $barWidth - $filled
    $progressBar = "[$('█' * $filled)$('░' * $empty)]"

    # Status emoji
    $statusEmoji = switch ($Status) {
        "Running" { "🔄" }
        "Complete" { "✅" }
        "Failed" { "❌" }
        "Warning" { "⚠️" }
        default { "📋" }
    }

    # Format output
    $progressLine = "$statusEmoji $Operation - $Stage"
    $detailLine = "$progressBar $percentage% ($CurrentStep/$TotalSteps)"
    $messageLine = if ($Message) { "💬 $Message" } else { "" }
    $timeLine = "⏱️ Elapsed: $($elapsed.ToString('hh\:mm\:ss'))"

    # Output to console with colors
    Write-Host $progressLine -ForegroundColor Cyan
    Write-Host $detailLine -ForegroundColor Yellow
    if ($messageLine) { Write-Host $messageLine -ForegroundColor White }
    Write-Host $timeLine -ForegroundColor Gray

    # Add metrics if provided
    if ($Metrics.Count -gt 0) {
        $metricsLine = "📊 " + (($Metrics.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" }) -join " | ")
        Write-Host $metricsLine -ForegroundColor Magenta
    }

    Write-Host "" # Empty line for spacing

    # Log to file
    $logEntry = @{
        Timestamp = $timestamp
        Operation = $Operation
        Stage = $Stage
        Progress = $percentage
        Status = $Status
        Message = $Message
        ElapsedSeconds = $elapsed.TotalSeconds
        Metrics = $Metrics
    }

    $logEntry | ConvertTo-Json -Compress | Add-Content -Path $LogPath -Force

    # GitHub Actions integration
    if ($env:GITHUB_ACTIONS -eq 'true') {
        # Set GitHub Actions step summary
        $githubSummary = @"
## $statusEmoji $Operation Progress

**Stage:** $Stage
**Progress:** $percentage% ($CurrentStep/$TotalSteps)
**Status:** $Status
**Elapsed:** $($elapsed.ToString('hh\:mm\:ss'))

$progressBar

$(if ($Message) { "**Message:** $Message" })

$(if ($Metrics.Count -gt 0) {
    "**Metrics:**" + "`n" + (($Metrics.GetEnumerator() | ForEach-Object { "- **$($_.Key):** $($_.Value)" }) -join "`n")
})
"@

        $githubSummary | Add-Content -Path $env:GITHUB_STEP_SUMMARY -Force

        # Set GitHub Actions outputs
        Write-Host "::set-output name=progress::$percentage"
        Write-Host "::set-output name=status::$Status"
        Write-Host "::set-output name=elapsed::$($elapsed.TotalSeconds)"
    }
}

# Resource monitoring function
function Get-SystemMetrics {
    $metrics = @{}

    try {
        # Memory usage
        if ($IsWindows) {
            $memory = Get-WmiObject -Class Win32_OperatingSystem
            $metrics.MemoryUsedGB = [math]::Round(($memory.TotalVisibleMemorySize - $memory.FreePhysicalMemory) / 1MB, 2)
            $metrics.MemoryTotalGB = [math]::Round($memory.TotalVisibleMemorySize / 1MB, 2)
        } else {
            # Linux/macOS memory info
            if (Get-Command free -ErrorAction SilentlyContinue) {
                $memInfo = free -m | Select-String "^Mem:"
                if ($memInfo) {
                    $memData = $memInfo.Line -split '\s+' | Where-Object { $_ -ne '' }
                    $metrics.MemoryUsedGB = [math]::Round([int]$memData[2] / 1024, 2)
                    $metrics.MemoryTotalGB = [math]::Round([int]$memData[1] / 1024, 2)
                }
            }
        }

        # CPU usage (simplified)
        $cpuProcess = Get-Process -Id $PID
        $metrics.CPUTimeSeconds = [math]::Round($cpuProcess.CPU, 2)

        # Disk usage for current directory
        $currentDrive = Get-Item . | Select-Object -ExpandProperty Root
        if ($currentDrive -and (Get-Command Get-Volume -ErrorAction SilentlyContinue)) {
            $volume = Get-Volume -DriveLetter $currentDrive.Name.TrimEnd(':\')
            if ($volume) {
                $metrics.DiskUsedGB = [math]::Round(($volume.Size - $volume.SizeRemaining) / 1GB, 2)
                $metrics.DiskFreeGB = [math]::Round($volume.SizeRemaining / 1GB, 2)
            }
        }

    } catch {
        # Metrics collection failed, continue without them
    }

    return $metrics
}

# Main execution
try {
    $metrics = Get-SystemMetrics

    if ($Complete) {
        Write-CIProgress -Operation $Operation -Stage "Completed" -Progress 100 -Message $Message -Status "Complete" -Metrics $metrics
    } elseif ($Failed) {
        $script:ProgressState.Errors += @{
            Operation = $Operation
            Stage = $Stage
            Message = $Message
            Timestamp = Get-Date
        }
        Write-CIProgress -Operation $Operation -Stage "Failed" -Progress $CurrentStep -Message $Message -Status "Failed" -Metrics $metrics
    } else {
        $status = if ($Message -imatch "(warning|warn)") { "Warning" } else { "Running" }
        Write-CIProgress -Operation $Operation -Stage $Stage -Progress $CurrentStep -Message $Message -Status $status -Metrics $metrics
    }

} catch {
    Write-Host "❌ Progress reporting failed: $_" -ForegroundColor Red
    exit 1
}

# Note: Export-ModuleMember only works when this file is loaded as a module
# For direct execution, functions are available in the current scope