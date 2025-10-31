#Requires -Version 7.0
<#
.SYNOPSIS
    AitherZero Maintenance Module - System Maintenance and Cleanup
.DESCRIPTION
    Consolidates maintenance and cleanup functionality from automation scripts.
    Handles system resets, cleanup operations, and maintenance tasks.
.NOTES
    Copyright © 2025 Aitherium Corporation
    Replaces: 9999_Reset-Machine.ps1 and other maintenance scripts
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module state
$script:MaintenanceState = @{
    LastCleanup = $null
    BackupLocation = $null
    CleanupHistory = @()
    ProjectRoot = $env:AITHERZERO_ROOT ?? (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
}

# Import dependencies
if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
    $script:LoggingAvailable = $true
} else {
    $script:LoggingAvailable = $false
}

function Write-MaintenanceLog {
    param(
        [string]$Message,
        [string]$Level = 'Information',
        [hashtable]$Data = @{}
    )

    if ($script:LoggingAvailable) {
        Write-CustomLog -Message $Message -Level $Level -Source 'Maintenance' -Data $Data
    } else {
        $timestamp = Get-Date -Format 'HH:mm:ss'
        $prefix = switch ($Level) {
            'Error' { '❌' }
            'Warning' { '⚠️' }
            'Information' { 'ℹ️' }
            'Success' { '✅' }
            default { '•' }
        }
        Write-Host "[$timestamp] $prefix $Message"
    }
}

function Reset-AitherEnvironment {
    <#
    .SYNOPSIS
        Perform comprehensive environment reset
    .DESCRIPTION
        Resets AitherZero environment to clean state with optional backup
        Consolidates 9999_Reset-Machine.ps1
    .PARAMETER Level
        Reset level: Soft (cache only), Standard (temp files), Hard (full reset), Nuclear (everything)
    .PARAMETER CreateBackup
        Create backup before reset
    .PARAMETER Force
        Skip confirmation prompts
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    param(
        [ValidateSet('Soft', 'Standard', 'Hard', 'Nuclear')]
        [string]$Level = 'Standard',

        [switch]$CreateBackup,

        [switch]$Force
    )

    Write-MaintenanceLog "Starting environment reset - Level: $Level"

    # Confirm destructive operations
    if (-not $Force) {
        $confirmation = Read-Host "This will perform a $Level reset of AitherZero environment. Are you sure? (yes/no)"
        if ($confirmation -ne 'yes') {
            Write-MaintenanceLog "Reset cancelled by user"
            return $false
        }
    }

    # Create backup if requested
    if ($CreateBackup) {
        $backupResult = Backup-AitherEnvironment -IncludeUserData
        if (-not $backupResult) {
            Write-MaintenanceLog "Backup failed, aborting reset" -Level Error
            return $false
        }
    }

    try {
        switch ($Level) {
            'Soft' {
                Clear-AitherCache
                Clear-TestResults -KeepLatest 3
            }
            'Standard' {
                Clear-AitherCache
                Clear-TestResults
                Clear-TemporaryFiles
                Clear-LogFiles -KeepDays 7
            }
            'Hard' {
                Clear-AitherCache
                Clear-TestResults
                Clear-TemporaryFiles
                Clear-LogFiles
                Clear-ReportFiles -KeepLatest 5
                Reset-Configuration -CreateBackup
            }
            'Nuclear' {
                Clear-AllAitherData
                Reset-Configuration -Force
                if ($PSCmdlet.ShouldProcess("PowerShell modules", "Unload all AitherZero modules")) {
                    Unload-AitherModules
                }
            }
        }

        # Record cleanup
        $script:MaintenanceState.LastCleanup = Get-Date
        $script:MaintenanceState.CleanupHistory += @{
            Timestamp = Get-Date
            Level = $Level
            Success = $true
            BackupCreated = $CreateBackup
        }

        Write-MaintenanceLog "Environment reset completed successfully - Level: $Level" -Level Success
        return $true

    } catch {
        Write-MaintenanceLog "Environment reset failed: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Clear-AitherCache {
    <#
    .SYNOPSIS
        Clear all AitherZero cache files
    .DESCRIPTION
        Removes cached test results, module cache, and temporary cache files
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-MaintenanceLog "Clearing AitherZero cache"

    $cachePaths = @(
        Join-Path $script:MaintenanceState.ProjectRoot '.cache'
        Join-Path $script:MaintenanceState.ProjectRoot 'cache'
        Join-Path $env:TEMP 'AitherZero-*'
        if ($IsLinux -or $IsMacOS) { '/tmp/AitherZero-*' } else { $null }
    ) | Where-Object { $_ -and $_ -ne '' }

    foreach ($path in $cachePaths) {
        if (Test-Path $path) {
            Write-MaintenanceLog "Removing cache: $path"
            if ($PSCmdlet.ShouldProcess($path, "Remove cache files")) {
                Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Write-MaintenanceLog "Cache cleanup completed"
}

function Clear-TestResults {
    <#
    .SYNOPSIS
        Clear test result files
    .DESCRIPTION
        Removes test result files with optional retention
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [int]$KeepLatest = 0,
        [int]$KeepDays = 0
    )

    Write-MaintenanceLog "Clearing test results (Keep Latest: $KeepLatest, Keep Days: $KeepDays)"

    $testResultsPath = Join-Path $script:MaintenanceState.ProjectRoot 'test-results'
    if (-not (Test-Path $testResultsPath)) {
        return
    }

    $files = Get-ChildItem -Path $testResultsPath -File | Sort-Object LastWriteTime -Descending

    # Apply retention policies
    $filesToDelete = @()

    if ($KeepLatest -gt 0) {
        $filesToDelete += $files | Select-Object -Skip $KeepLatest
    } elseif ($KeepDays -gt 0) {
        $cutoffDate = (Get-Date).AddDays(-$KeepDays)
        $filesToDelete += $files | Where-Object { $_.LastWriteTime -lt $cutoffDate }
    } else {
        $filesToDelete = $files
    }

    foreach ($file in $filesToDelete) {
        Write-MaintenanceLog "Removing test result: $($file.Name)"
        if ($PSCmdlet.ShouldProcess($file.FullName, "Remove test result file")) {
            Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
        }
    }

    Write-MaintenanceLog "Test results cleanup completed. Removed: $($filesToDelete.Count), Kept: $($files.Count - $filesToDelete.Count)"
}

function Clear-TemporaryFiles {
    <#
    .SYNOPSIS
        Clear temporary files and directories
    .DESCRIPTION
        Removes temporary files created during AitherZero operations
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-MaintenanceLog "Clearing temporary files"

    $tempPaths = @(
        Join-Path $script:MaintenanceState.ProjectRoot 'temp'
        Join-Path $script:MaintenanceState.ProjectRoot 'tmp'
        Join-Path $script:MaintenanceState.ProjectRoot '.tmp'
        Join-Path $script:MaintenanceState.ProjectRoot 'downloads'
    )

    foreach ($path in $tempPaths) {
        if (Test-Path $path) {
            $items = Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                Write-MaintenanceLog "Removing temp item: $($item.Name)"
                if ($PSCmdlet.ShouldProcess($item.FullName, "Remove temporary item")) {
                    Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    Write-MaintenanceLog "Temporary files cleanup completed"
}

function Clear-LogFiles {
    <#
    .SYNOPSIS
        Clear log files with retention policy
    .DESCRIPTION
        Removes old log files while preserving recent ones
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [int]$KeepDays = 30,
        [int]$KeepLatest = 10
    )

    Write-MaintenanceLog "Clearing log files (Keep Days: $KeepDays, Keep Latest: $KeepLatest)"

    $logsPath = Join-Path $script:MaintenanceState.ProjectRoot 'logs'
    if (-not (Test-Path $logsPath)) {
        return
    }

    $logFiles = Get-ChildItem -Path $logsPath -Filter "*.log" | Sort-Object LastWriteTime -Descending

    # Apply retention policy
    $filesToDelete = @()
    if ($KeepDays -gt 0) {
        $cutoffDate = (Get-Date).AddDays(-$KeepDays)
        $filesToDelete = $logFiles | Where-Object { $_.LastWriteTime -lt $cutoffDate }
    }

    # Also keep latest files regardless of age
    if ($KeepLatest -gt 0) {
        $filesToKeep = $logFiles | Select-Object -First $KeepLatest
        $filesToDelete = $filesToDelete | Where-Object { $_ -notin $filesToKeep }
    }

    foreach ($file in $filesToDelete) {
        Write-MaintenanceLog "Removing log file: $($file.Name)"
        if ($PSCmdlet.ShouldProcess($file.FullName, "Remove log file")) {
            Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
        }
    }

    Write-MaintenanceLog "Log files cleanup completed. Removed: $($filesToDelete.Count), Kept: $($logFiles.Count - $filesToDelete.Count)"
}

function Clear-ReportFiles {
    <#
    .SYNOPSIS
        Clear report files with retention
    .DESCRIPTION
        Removes old report files while preserving recent ones
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [int]$KeepLatest = 10,
        [int]$KeepDays = 90
    )

    Write-MaintenanceLog "Clearing report files (Keep Latest: $KeepLatest, Keep Days: $KeepDays)"

    $reportsPath = Join-Path $script:MaintenanceState.ProjectRoot 'reports'
    if (-not (Test-Path $reportsPath)) {
        return
    }

    $reportFiles = Get-ChildItem -Path $reportsPath -File -Recurse | Sort-Object LastWriteTime -Descending

    # Apply retention policy similar to logs
    $filesToDelete = @()
    if ($KeepDays -gt 0) {
        $cutoffDate = (Get-Date).AddDays(-$KeepDays)
        $filesToDelete = $reportFiles | Where-Object { $_.LastWriteTime -lt $cutoffDate }
    }

    if ($KeepLatest -gt 0) {
        $filesToKeep = $reportFiles | Select-Object -First $KeepLatest
        $filesToDelete = $filesToDelete | Where-Object { $_ -notin $filesToKeep }
    }

    foreach ($file in $filesToDelete) {
        Write-MaintenanceLog "Removing report file: $($file.Name)"
        if ($PSCmdlet.ShouldProcess($file.FullName, "Remove report file")) {
            Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
        }
    }

    Write-MaintenanceLog "Report files cleanup completed. Removed: $($filesToDelete.Count), Kept: $($reportFiles.Count - $filesToDelete.Count)"
}

function Clear-AllAitherData {
    <#
    .SYNOPSIS
        Nuclear option - clear all AitherZero data
    .DESCRIPTION
        Removes all generated data while preserving source code
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    param()

    Write-MaintenanceLog "Performing nuclear cleanup - removing ALL AitherZero data" -Level Warning

    $dataDirectories = @(
        'logs', 'temp', 'tmp', '.tmp', 'cache', '.cache',
        'test-results', 'reports', 'backups', 'downloads'
    )

    foreach ($dir in $dataDirectories) {
        $dirPath = Join-Path $script:MaintenanceState.ProjectRoot $dir
        if (Test-Path $dirPath) {
            Write-MaintenanceLog "Removing directory: $dir"
            if ($PSCmdlet.ShouldProcess($dirPath, "Remove data directory")) {
                Remove-Item -Path $dirPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Write-MaintenanceLog "Nuclear cleanup completed" -Level Success
}

function Backup-AitherEnvironment {
    <#
    .SYNOPSIS
        Create backup of AitherZero environment
    .DESCRIPTION
        Creates compressed backup of configuration and data
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$BackupPath = (Join-Path $script:MaintenanceState.ProjectRoot 'backups'),
        [switch]$IncludeUserData,
        [switch]$IncludeLogs
    )

    Write-MaintenanceLog "Creating AitherZero environment backup"

    if (-not (Test-Path $BackupPath)) {
        if ($PSCmdlet.ShouldProcess($BackupPath, "Create backup directory")) {
            New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
        }
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupName = "AitherZero-Backup-$timestamp"
    $tempBackupPath = Join-Path ([System.IO.Path]::GetTempPath()) $backupName

    try {
        if ($PSCmdlet.ShouldProcess($tempBackupPath, "Create temporary backup directory")) {
            New-Item -Path $tempBackupPath -ItemType Directory -Force | Out-Null

            # Copy configuration files
            $configFiles = @('config.psd1', 'config.json', 'AitherZero.psd1')
            foreach ($configFile in $configFiles) {
                $srcPath = Join-Path $script:MaintenanceState.ProjectRoot $configFile
                if (Test-Path $srcPath) {
                    Copy-Item -Path $srcPath -Destination $tempBackupPath -Force
                }
            }

            # Copy user data if requested
            if ($IncludeUserData) {
                $userDataDirs = @('reports', 'test-results')
                foreach ($dir in $userDataDirs) {
                    $srcPath = Join-Path $script:MaintenanceState.ProjectRoot $dir
                    if (Test-Path $srcPath) {
                        $destPath = Join-Path $tempBackupPath $dir
                        Copy-Item -Path $srcPath -Destination $destPath -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            }

            # Copy logs if requested
            if ($IncludeLogs) {
                $logsPath = Join-Path $script:MaintenanceState.ProjectRoot 'logs'
                if (Test-Path $logsPath) {
                    $destLogsPath = Join-Path $tempBackupPath 'logs'
                    Copy-Item -Path $logsPath -Destination $destLogsPath -Recurse -Force -ErrorAction SilentlyContinue
                }
            }

            # Create compressed backup
            $backupZipPath = Join-Path $BackupPath "$backupName.zip"
            if ($PSCmdlet.ShouldProcess($backupZipPath, "Create compressed backup")) {
                Compress-Archive -Path "$tempBackupPath\*" -DestinationPath $backupZipPath -Force
            }

            # Store backup location
            $script:MaintenanceState.BackupLocation = $backupZipPath

            Write-MaintenanceLog "Backup created successfully: $backupZipPath" -Level Success
            return $backupZipPath
        }

    } finally {
        # Cleanup temporary directory
        if (Test-Path $tempBackupPath) {
            Remove-Item -Path $tempBackupPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Reset-Configuration {
    <#
    .SYNOPSIS
        Reset AitherZero configuration to defaults
    .DESCRIPTION
        Resets configuration files to default state
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    param(
        [switch]$CreateBackup,
        [switch]$Force
    )

    Write-MaintenanceLog "Resetting AitherZero configuration"

    if ($CreateBackup) {
        $configFiles = @('config.psd1', 'config.json')
        foreach ($configFile in $configFiles) {
            $configPath = Join-Path $script:MaintenanceState.ProjectRoot $configFile
            if (Test-Path $configPath) {
                $backupPath = "$configPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                if ($PSCmdlet.ShouldProcess($configPath, "Backup configuration")) {
                    Copy-Item -Path $configPath -Destination $backupPath -Force
                    Write-MaintenanceLog "Configuration backed up to: $backupPath"
                }
            }
        }
    }

    # Reset to default configuration
    $defaultConfigPath = Join-Path $script:MaintenanceState.ProjectRoot 'config.example.psd1'
    $configPath = Join-Path $script:MaintenanceState.ProjectRoot 'config.psd1'

    if (Test-Path $defaultConfigPath) {
        if ($PSCmdlet.ShouldProcess($configPath, "Reset to default configuration")) {
            Copy-Item -Path $defaultConfigPath -Destination $configPath -Force
            Write-MaintenanceLog "Configuration reset to defaults" -Level Success
        }
    }
}

function Unload-AitherModules {
    <#
    .SYNOPSIS
        Unload all AitherZero modules from session
    .DESCRIPTION
        Removes all loaded AitherZero modules from the PowerShell session
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-MaintenanceLog "Unloading AitherZero modules"

    $aitherModules = Get-Module | Where-Object {
        $_.Path -like "*$($script:MaintenanceState.ProjectRoot)*" -or
        $_.Name -like "*Aither*"
    }

    foreach ($module in $aitherModules) {
        Write-MaintenanceLog "Unloading module: $($module.Name)"
        if ($PSCmdlet.ShouldProcess($module.Name, "Remove module")) {
            Remove-Module -Name $module.Name -Force -ErrorAction SilentlyContinue
        }
    }

    Write-MaintenanceLog "Module unloading completed. Unloaded: $($aitherModules.Count) modules"
}

function Get-MaintenanceStatus {
    <#
    .SYNOPSIS
        Get maintenance and cleanup status
    .DESCRIPTION
        Returns information about system maintenance state
    #>
    [CmdletBinding()]
    param()

    $status = @{
        LastCleanup = $script:MaintenanceState.LastCleanup
        BackupLocation = $script:MaintenanceState.BackupLocation
        CleanupHistory = $script:MaintenanceState.CleanupHistory
        SystemInfo = @{
            ProjectRoot = $script:MaintenanceState.ProjectRoot
            DiskUsage = @{}
            DirectorySizes = @{}
        }
    }

    # Calculate directory sizes
    $directories = @('logs', 'test-results', 'reports', 'cache', 'temp')
    foreach ($dir in $directories) {
        $dirPath = Join-Path $script:MaintenanceState.ProjectRoot $dir
        if (Test-Path $dirPath) {
            try {
                $size = (Get-ChildItem -Path $dirPath -Recurse -File | Measure-Object -Property Length -Sum).Sum
                $status.SystemInfo.DirectorySizes[$dir] = @{
                    Bytes = $size
                    MB = [math]::Round($size / 1MB, 2)
                    FileCount = (Get-ChildItem -Path $dirPath -Recurse -File).Count
                }
            } catch {
                $status.SystemInfo.DirectorySizes[$dir] = @{ Error = $_.Exception.Message }
            }
        }
    }

    return $status
}

# Export functions
Export-ModuleMember -Function @(
    'Reset-AitherEnvironment',
    'Clear-AitherCache',
    'Clear-TestResults',
    'Clear-TemporaryFiles',
    'Clear-LogFiles',
    'Clear-ReportFiles',
    'Clear-AllAitherData',
    'Backup-AitherEnvironment',
    'Reset-Configuration',
    'Unload-AitherModules',
    'Get-MaintenanceStatus'
)