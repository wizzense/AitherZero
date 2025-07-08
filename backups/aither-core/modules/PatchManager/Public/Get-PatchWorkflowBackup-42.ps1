#Requires -Version 7.0

<#
.SYNOPSIS
    Lists and restores PatchManager safety backups.

.DESCRIPTION
    This function helps you find and restore backups created by PatchManager's
    safety system when uncommitted changes were detected.

.PARAMETER ListOnly
    Only list available backups without restoring.

.PARAMETER Latest
    Automatically restore the most recent backup.

.PARAMETER BackupLocation
    Specific backup location to restore from.

.EXAMPLE
    Get-PatchWorkflowBackup
    # Lists all available backups

.EXAMPLE
    Get-PatchWorkflowBackup -Latest
    # Restores the most recent backup
#>
function Get-PatchWorkflowBackup {
    [CmdletBinding()]
    param(
        [switch]$ListOnly,
        [switch]$Latest,
        [string]$BackupLocation
    )

    # Find all backups in temp directory
    $tempPath = $env:TEMP
    $backups = Get-ChildItem -Path $tempPath -Directory -Filter "AitherZero-Backup-*" -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending

    if ($ListOnly -or (-not $Latest -and -not $BackupLocation)) {
        Write-Host "Available PatchManager backups:" -ForegroundColor Cyan
        $backups | ForEach-Object {
            Write-Host "  $($_.Name) - $($_.FullName)" -ForegroundColor Yellow
            $fileCount = (Get-ChildItem -Path $_.FullName -Recurse -File).Count
            Write-Host "    Files: $fileCount" -ForegroundColor Gray
        }

        Write-Host "`nGit stashes:" -ForegroundColor Cyan
        git stash list | Where-Object { $_ -match "SAFETY-STASH:" } | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Yellow
        }
        return
    }

    if ($Latest) {
        $BackupLocation = $backups[0].FullName
        Write-Host "Restoring latest backup: $($backups[0].Name)" -ForegroundColor Green
    }

    if ($BackupLocation) {
        Restore-PatchWorkflowBackup -BackupLocation $BackupLocation
    }
}

Export-ModuleMember -Function Get-PatchWorkflowBackup
