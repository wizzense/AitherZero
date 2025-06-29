function Test-PatchWorkflowSafety {
    [CmdletBinding()]
    param(
        [string]$PatchDescription
    )
    
    # Check for uncommitted changes
    $status = git status --porcelain
    if ($status) {
        Write-Warning "SAFETY CHECK: Uncommitted changes detected!"
        Write-Host "The following files have uncommitted changes:" -ForegroundColor Yellow
        $status | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
        
        # Create automatic backup
        $backupDir = Join-Path $env:TEMP "AitherZero-Backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Write-Host "`nCreating safety backup at: $backupDir" -ForegroundColor Cyan
        
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        
        # Backup all modified files
        $status | ForEach-Object {
            $file = ($_ -split ' ', 2)[1].Trim()
            if (Test-Path $file) {
                $destPath = Join-Path $backupDir $file
                $destDir = Split-Path $destPath -Parent
                New-Item -ItemType Directory -Path $destDir -Force -ErrorAction SilentlyContinue | Out-Null
                Copy-Item -Path $file -Destination $destPath -Force
                Write-Host "  Backed up: $file" -ForegroundColor Gray
            }
        }
        
        Write-Host "`nBackup complete! Location: $backupDir" -ForegroundColor Green
        
        # Also create a git stash as secondary backup
        $stashMessage = "SAFETY-STASH: Before $PatchDescription - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        git stash push -u -m $stashMessage
        Write-Host "Git stash created: $stashMessage" -ForegroundColor Green
        
        return @{
            Safe = $false
            BackupLocation = $backupDir
            StashMessage = $stashMessage
        }
    }
    
    return @{ Safe = $true }
}

function Restore-PatchWorkflowBackup {
    [CmdletBinding()]
    param(
        [string]$BackupLocation,
        [string]$StashMessage
    )
    
    if ($BackupLocation -and (Test-Path $BackupLocation)) {
        Write-Host "Restoring from backup: $BackupLocation" -ForegroundColor Yellow
        
        Get-ChildItem -Path $BackupLocation -Recurse -File | ForEach-Object {
            $relativePath = $_.FullName.Substring($BackupLocation.Length + 1)
            $destPath = Join-Path (Get-Location) $relativePath
            
            Write-Host "  Restoring: $relativePath" -ForegroundColor Gray
            Copy-Item -Path $_.FullName -Destination $destPath -Force
        }
        
        Write-Host "Backup restored successfully!" -ForegroundColor Green
    }
    
    if ($StashMessage) {
        Write-Host "Restoring git stash: $StashMessage" -ForegroundColor Yellow
        git stash list | Where-Object { $_ -match [regex]::Escape($StashMessage) } | ForEach-Object {
            $stashId = ($_ -split ':')[0]
            git stash apply $stashId
            Write-Host "Stash restored successfully!" -ForegroundColor Green
        }
    }
}
