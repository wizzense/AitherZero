function Start-BackupOperation {
    <#
    .SYNOPSIS
        Starts a backup operation

    .DESCRIPTION
        Initiates a backup operation with specified parameters

    .PARAMETER Source
        Source path to backup

    .PARAMETER Destination
        Destination path for backup

    .PARAMETER Type
        Type of backup operation (Full, Incremental, Differential)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Source,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Destination,

        [ValidateSet('Full', 'Incremental', 'Differential')]
        [string]$Type = 'Full'
    )

    Write-CustomLog -Message "🔄 Starting $Type backup operation from $Source to $Destination" -Level "INFO"

    try {
        if ($PSCmdlet.ShouldProcess($Source, "Backup to $Destination")) {
            # Validate source exists
            if (-not (Test-Path $Source)) {
                throw "Source path does not exist: $Source"
            }

            # Create destination if it doesn't exist
            if (-not (Test-Path $Destination)) {
                New-Item -Path $Destination -ItemType Directory -Force | Out-Null
            }

            # Perform backup operation
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $backupName = "backup-$timestamp"
            $backupPath = Join-Path $Destination $backupName

            Write-CustomLog -Message "📁 Creating backup at: $backupPath" -Level "INFO"
            Copy-Item -Path $Source -Destination $backupPath -Recurse -Force

            $result = @{
                Status = 'Success'
                BackupPath = $backupPath
                StartTime = Get-Date
                Type = $Type
                Source = $Source
                Destination = $Destination
            }

            Write-CustomLog -Message "✅ Backup operation completed successfully" -Level "SUCCESS"
            return $result
        }
    } catch {
        Write-CustomLog -Message "❌ Backup operation failed: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}
