function Restore-Configuration {
    <#
    .SYNOPSIS
        Restore configuration from a backup
    .DESCRIPTION
        Restores configuration from a previously created backup file
    .PARAMETER Path
        Path to the backup file to restore from
    .PARAMETER CreateBackup
        Create a backup of current configuration before restoring
    .PARAMETER RestoreSchemas
        Restore schemas from backup (if available)
    .PARAMETER Force
        Force restoration without confirmation
    .EXAMPLE
        Restore-Configuration -Path "C:\Backups\config-backup.json" -CreateBackup
    .EXAMPLE
        Restore-Configuration -Path "config-backup-20250101-120000.json" -RestoreSchemas -Force
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [switch]$CreateBackup,

        [Parameter()]
        [switch]$RestoreSchemas,

        [Parameter()]
        [switch]$Force
    )

    try {
        # Validate backup file exists
        if (-not (Test-Path $Path)) {
            throw "Backup file not found: $Path"
        }

        # Read and parse backup file
        $backupContent = Get-Content $Path -Raw -Encoding UTF8
        $backupData = $backupContent | ConvertFrom-Json -AsHashtable

        if (-not $backupData) {
            throw "Failed to parse backup file or file is empty"
        }

        # Validate backup structure
        if (-not $backupData.Configuration) {
            throw "Invalid backup file: missing Configuration section"
        }

        # Get backup metadata for display
        $backupInfo = ""
        if ($backupData.BackupMetadata) {
            $metadata = $backupData.BackupMetadata
            $backupInfo = "`n  Created: $($metadata.CreatedAt)`n  Reason: $($metadata.Reason)`n  By: $($metadata.CreatedBy)"
        }

        if (-not $Force) {
            $title = "Restore Configuration"
            $message = "This will replace the current configuration with the backup from '$Path'.$backupInfo`n`nAre you sure you want to continue?"

            if (-not $PSCmdlet.ShouldProcess($Path, $title)) {
                return $false
            }
        }

        # Create backup of current configuration if requested
        if ($CreateBackup) {
            Write-CustomLog -Level 'INFO' -Message "Creating backup of current configuration before restore"
            Backup-Configuration -Reason "Before restore from $Path"
        }

        # Prepare configuration for restoration
        $configToRestore = $backupData.Configuration

        # Handle schemas
        if ($RestoreSchemas -and $configToRestore.Schemas) {
            Write-CustomLog -Level 'INFO' -Message "Restoring schemas from backup"
        } elseif ($configToRestore.Schemas) {
            # Preserve current schemas if not explicitly restoring them
            $configToRestore.Schemas = $script:ConfigurationStore.Schemas
        }

        # Preserve StorePath and HotReload settings
        $configToRestore.StorePath = $script:ConfigurationStore.StorePath
        if (-not $configToRestore.HotReload) {
            $configToRestore.HotReload = $script:ConfigurationStore.HotReload
        }

        # Validate restored configuration
        $requiredKeys = @('Modules', 'Environments', 'CurrentEnvironment')
        foreach ($key in $requiredKeys) {
            if (-not $configToRestore.ContainsKey($key)) {
                throw "Invalid backup configuration: missing required key '$key'"
            }
        }

        # Validate current environment exists
        if (-not $configToRestore.Environments.ContainsKey($configToRestore.CurrentEnvironment)) {
            Write-CustomLog -Level 'WARN' -Message "Current environment '$($configToRestore.CurrentEnvironment)' not found in backup, setting to 'default'"
            $configToRestore.CurrentEnvironment = 'default'
        }

        # Restore configuration
        $script:ConfigurationStore = $configToRestore

        # Save restored configuration
        Save-ConfigurationStore

        Write-CustomLog -Level 'SUCCESS' -Message "Configuration restored from backup: $Path"

        # Trigger hot reload for all modules if enabled
        if ($script:ConfigurationStore.HotReload.Enabled) {
            Write-CustomLog -Level 'INFO' -Message "Triggering hot reload for all modules"
            foreach ($moduleName in $script:ConfigurationStore.Modules.Keys) {
                try {
                    Invoke-ConfigurationReload -ModuleName $moduleName -Environment $script:ConfigurationStore.CurrentEnvironment
                } catch {
                    Write-CustomLog -Level 'WARN' -Message "Failed to reload module '$moduleName': $_"
                }
            }
        }

        # Publish event
        if (Get-Command 'Publish-TestEvent' -ErrorAction SilentlyContinue) {
            Publish-TestEvent -EventName 'ConfigurationRestored' -EventData @{
                BackupPath = $Path
                BackupCreated = $CreateBackup.IsPresent
                SchemasRestored = $RestoreSchemas.IsPresent
                Timestamp = Get-Date
            }
        }

        return @{
            RestoredFrom = $Path
            BackupMetadata = $backupData.BackupMetadata
            CurrentEnvironment = $script:ConfigurationStore.CurrentEnvironment
            ModuleCount = $script:ConfigurationStore.Modules.Count
            EnvironmentCount = $script:ConfigurationStore.Environments.Count
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to restore configuration: $_"
        throw
    }
}
