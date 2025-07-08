function Backup-Configuration {
    <#
    .SYNOPSIS
        Create a backup of the current configuration
    .DESCRIPTION
        Creates a timestamped backup of the current configuration store
    .PARAMETER Path
        Custom path for the backup file (optional)
    .PARAMETER Reason
        Reason for creating the backup
    .PARAMETER IncludeSchemas
        Include schemas in the backup
    .PARAMETER Compress
        Compress the backup file
    .EXAMPLE
        Backup-Configuration -Reason "Before environment changes"
    .EXAMPLE
        Backup-Configuration -Path "C:\Backups\config-backup.json" -IncludeSchemas
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string]$Path,

        [Parameter()]
        [string]$Reason = "Manual backup",

        [Parameter()]
        [switch]$IncludeSchemas,

        [Parameter()]
        [switch]$Compress
    )

    try {
        # Generate backup path if not provided
        if (-not $Path) {
            $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $configDir = Split-Path $script:ConfigurationStore.StorePath -Parent
            $backupDir = Join-Path $configDir 'backups'

            if (-not (Test-Path $backupDir)) {
                New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            }

            $Path = Join-Path $backupDir "config-backup-$timestamp.json"
        }

        if ($PSCmdlet.ShouldProcess($Path, "Create configuration backup")) {
            # Prepare backup data
            $backupData = @{
                BackupMetadata = @{
                    CreatedAt = Get-Date
                    CreatedBy = $env:USERNAME ?? $env:USER ?? 'unknown'
                    Reason = $Reason
                    OriginalPath = $script:ConfigurationStore.StorePath
                    Platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } else { 'macOS' }
                    PowerShellVersion = $PSVersionTable.PSVersion.ToString()
                    AitherZeroVersion = '1.0.0'
                }
                Configuration = $script:ConfigurationStore.Clone()
            }

            # Remove schemas if not requested
            if (-not $IncludeSchemas) {
                $backupData.Configuration.Remove('Schemas')
            }

            # Ensure backup directory exists
            $backupDir = Split-Path $Path -Parent
            if ($backupDir -and -not (Test-Path $backupDir)) {
                New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            }

            # Save backup
            if ($Compress) {
                $json = $backupData | ConvertTo-Json -Depth 10 -Compress
            } else {
                $json = $backupData | ConvertTo-Json -Depth 10
            }

            Set-Content -Path $Path -Value $json -Encoding UTF8

            Write-CustomLog -Level 'SUCCESS' -Message "Configuration backup created: $Path"

            # Publish event
            if (Get-Command 'Submit-TestEvent' -ErrorAction SilentlyContinue) {
                Submit-TestEvent -EventType 'ConfigurationBackup' -Data @{
                    BackupPath = $Path
                    Reason = $Reason
                    IncludeSchemas = $IncludeSchemas.IsPresent
                    Compressed = $Compress.IsPresent
                    Timestamp = Get-Date
                }
            }

            return @{
                BackupPath = $Path
                BackupSize = (Get-Item $Path).Length
                Reason = $Reason
                CreatedAt = Get-Date
            }
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to create configuration backup: $_"
        throw
    }
}
