#Requires -Version 7.0

<#
.SYNOPSIS
    Rollback functionality for PatchManager - simplified and reliable.

.DESCRIPTION
    Provides safe rollback capabilities for patch operations.
    Part of the core PatchManager functions that replace the legacy sprawling scripts.

.PARAMETER RollbackType
    Type of rollback: LastCommit, PreviousBranch, SpecificCommit

.PARAMETER CommitHash
    Specific commit hash to rollback to (required for SpecificCommit)

.PARAMETER CreateBackup
    Create backup before rollback

.PARAMETER Force
    Force rollback without confirmation

.EXAMPLE
    Invoke-PatchRollback -RollbackType "LastCommit"
    
.EXAMPLE
    Invoke-PatchRollback -RollbackType "SpecificCommit" -CommitHash "abc123" -CreateBackup

.NOTES
    This function is part of the simplified PatchManager core.
    Uses consistent logging and error handling patterns.
#>

function Invoke-PatchRollback {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("LastCommit", "PreviousBranch", "SpecificCommit")]
        [string]$RollbackType = "LastCommit",        
        [Parameter(Mandatory = $false)]
        [string]$CommitHash,
        
        [Parameter(Mandatory = $false)]
        [switch]$CreateBackup,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force,
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )
    
    begin {
        Import-Module (Join-Path $PSScriptRoot '..' '..' 'Logging') -Force
        
        Write-CustomLog -Level 'INFO' -Message "Starting patch rollback: $RollbackType"
        
        if ($RollbackType -eq "SpecificCommit" -and -not $CommitHash) {
            Write-CustomLog -Level 'ERROR' -Message "CommitHash is required for SpecificCommit rollback"
            throw "CommitHash parameter is required when RollbackType is 'SpecificCommit'"
        }
    }
    
    process {
        try {
            # Validation checks
            if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
                throw "Git is not available. Rollback operations require Git."
            }
              # Check if we're in a git repository
            git status --porcelain 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Not in a Git repository. Cannot perform rollback."
            }
            
            # Create backup if requested
            if ($CreateBackup) {
                Write-CustomLog -Level 'INFO' -Message "Creating backup before rollback"
                $backupBranch = "backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                git branch $backupBranch
                if ($LASTEXITCODE -eq 0) {
                    Write-CustomLog -Level 'SUCCESS' -Message "Backup branch created: $backupBranch"
                } else {
                    Write-CustomLog -Level 'WARN' -Message "Failed to create backup branch"
                }
            }
            
            # Perform rollback based on type
            switch ($RollbackType) {
                "LastCommit" {
                    Write-CustomLog -Level 'INFO' -Message "Rolling back to previous commit"
                    if ($PSCmdlet.ShouldProcess("Git repository", "Reset to HEAD~1")) {
                        if ($DryRun) {
                            Write-CustomLog -Level 'INFO' -Message "[DRY RUN] Would execute: git reset --hard HEAD~1"
                        } else {
                            git reset --hard HEAD~1
                            if ($LASTEXITCODE -eq 0) {
                                Write-CustomLog -Level 'SUCCESS' -Message "Successfully rolled back to previous commit"
                            } else {
                                throw "Failed to rollback to previous commit"
                            }
                        }
                    }
                }
                
                "PreviousBranch" {
                    Write-CustomLog -Level 'INFO' -Message "Switching to previous branch"
                    if ($PSCmdlet.ShouldProcess("Git repository", "Checkout previous branch")) {
                        if ($DryRun) {
                            Write-CustomLog -Level 'INFO' -Message "[DRY RUN] Would execute: git checkout -"
                        } else {
                            git checkout -
                            if ($LASTEXITCODE -eq 0) {
                                Write-CustomLog -Level 'SUCCESS' -Message "Successfully switched to previous branch"
                            } else {
                                throw "Failed to switch to previous branch"
                            }
                        }
                    }
                }
                
                "SpecificCommit" {
                    Write-CustomLog -Level 'INFO' -Message "Rolling back to specific commit: $CommitHash"
                    if ($PSCmdlet.ShouldProcess("Git repository", "Reset to $CommitHash")) {
                        if ($DryRun) {
                            Write-CustomLog -Level 'INFO' -Message "[DRY RUN] Would execute: git reset --hard $CommitHash"
                        } else {
                            git reset --hard $CommitHash
                            if ($LASTEXITCODE -eq 0) {
                                Write-CustomLog -Level 'SUCCESS' -Message "Successfully rolled back to commit: $CommitHash"
                            } else {
                                throw "Failed to rollback to commit: $CommitHash"
                            }
                        }
                    }
                }
            }
            
            # Return success result
            return @{
                Success = $true
                RollbackType = $RollbackType
                CommitHash = $CommitHash
                BackupCreated = $CreateBackup.IsPresent
                Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                DryRun = $DryRun.IsPresent
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Rollback failed: $($_.Exception.Message)"
            return @{
                Success = $false
                Error = $_.Exception.Message
                RollbackType = $RollbackType
                Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            }
        }
    }
}

Export-ModuleMember -Function Invoke-PatchRollback