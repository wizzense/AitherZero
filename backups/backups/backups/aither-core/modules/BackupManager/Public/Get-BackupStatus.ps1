function Get-BackupStatus {
    <#
    .SYNOPSIS
        Gets the status of backup operations

    .DESCRIPTION
        Retrieves status information about backup operations and backup health

    .PARAMETER BackupPath
        Path to backup location to check

    .PARAMETER Detailed
        Whether to return detailed backup information
    #>
    [CmdletBinding()]
    param(
        [string]$BackupPath,
        [switch]$Detailed
    )

    Write-CustomLog -Message "📊 Retrieving backup status" -Level "INFO"

    try {
        $status = @{
            Timestamp = Get-Date
            BackupLocations = @()
            TotalBackups = 0
            TotalSize = 0
            HealthStatus = 'Unknown'
        }

        if ($BackupPath -and (Test-Path $BackupPath)) {
            $backups = Get-ChildItem -Path $BackupPath -Directory | Where-Object { $_.Name -match '^backup-\d{8}-\d{6}$' }
            $status.TotalBackups = $backups.Count

            if ($Detailed) {
                $backupDetails = @()
                foreach ($backup in $backups) {
                    $size = (Get-ChildItem -Path $backup.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum
                    $backupDetails += @{
                        Name = $backup.Name
                        Path = $backup.FullName
                        Created = $backup.CreationTime
                        Size = $size
                        SizeFormatted = "{0:N2} MB" -f ($size / 1MB)
                    }
                    $status.TotalSize += $size
                }
                $status.BackupDetails = $backupDetails
            }

            $status.BackupLocations += $BackupPath
            $status.HealthStatus = if ($status.TotalBackups -gt 0) { 'Healthy' } else { 'No Backups' }
        } else {
            $status.HealthStatus = 'No Valid Backup Path'
        }

        Write-CustomLog -Message "✅ Backup status retrieved: $($status.TotalBackups) backups found" -Level "INFO"
        return $status
    } catch {
        Write-CustomLog -Message "❌ Failed to get backup status: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}