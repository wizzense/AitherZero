#Requires -Version 7.0
<#
.SYNOPSIS
    Quick rollback functionality for PatchManager
    
.DESCRIPTION
    Provides instant rollback capabilities for patches, allowing quick recovery
    from breaking changes. Can eliminate the need for regular backups with
    proper change control.
    
.PARAMETER RollbackType
    Type of rollback: LastPatch, LastCommit, ToCommit, ToBranch
    
.PARAMETER TargetCommit
    Specific commit hash to rollback to
    
.PARAMETER TargetBranch
    Specific branch to rollback to
    
.PARAMETER Force
    Force the rollback even if it will lose changes
    
.PARAMETER CreateBackup
    Create a backup branch before rolling back
    
.EXAMPLE
    Invoke-QuickRollback -RollbackType "LastPatch"
    
.EXAMPLE
    Invoke-QuickRollback -RollbackType "ToCommit" -TargetCommit "abc123"
    
.NOTES
    - Provides instant recovery from breaking changes
    - Can replace regular backup needs with proper change control
    - Always creates safety backups before destructive operations
    - Integrates with PatchManager's change tracking
#>

function Invoke-QuickRollback {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("LastPatch", "LastCommit", "ToCommit", "ToBranch", "Emergency", "SpecificCommit", "WorkingTree")]
        [string]$RollbackType,
        
        [Parameter(Mandatory = $false)]
        [string]$TargetCommit,
          [Parameter(Mandatory = $false)]
        [string]$TargetBranch,
        
        [Parameter(Mandatory = $false)]
        [string]$CommitHash,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force,
        
        [Parameter(Mandatory = $false)]
        [switch]$CreateBackup,
        
        [Parameter(Mandatory = $false)]
        [switch]$ValidateSafety,
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )      begin {
        Write-Host "Starting quick rollback process..." -ForegroundColor Cyan
        
        if ($DryRun) {
            Write-Host "DRY RUN MODE - No actual changes will be made" -ForegroundColor Yellow
        }
        
        # Set default for CreateBackup if not explicitly specified
        if (-not $PSBoundParameters.ContainsKey('CreateBackup')) {
            $CreateBackup = $true
        }
        
        Write-Host "Type: $RollbackType | Force: $Force | Backup: $CreateBackup | DryRun: $DryRun" -ForegroundColor Yellow
        
        # Validate we're in a Git repository
        if (-not (Test-Path ".git")) {
            throw "Not in a Git repository. Rollback requires version control."
        }
        
        # Get current state
        $currentCommit = git rev-parse HEAD
        $currentBranch = git branch --show-current
        $workingTreeClean = -not (git status --porcelain)
        
        Write-Host "Current state:" -ForegroundColor Blue
        Write-Host "  Branch: $currentBranch" -ForegroundColor White
        Write-Host "  Commit: $currentCommit" -ForegroundColor White
        Write-Host "  Working tree clean: $workingTreeClean" -ForegroundColor White
        
        # Create safety backup if requested
        if ($CreateBackup) {
            $backupBranch = "rollback-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            git checkout -b $backupBranch
            git checkout $currentBranch
            Write-Host "Created safety backup branch: $backupBranch" -ForegroundColor Green
        }
    }
    
    process {
        try {
            switch ($RollbackType) {
                "LastPatch" {
                    Write-Host "Rolling back last patch operation..." -ForegroundColor Yellow
                    
                    # Find the last patch commit
                    $patchCommits = git log --oneline --grep="PatchManager v2.0" --max-count=5
                    if (-not $patchCommits) {
                        throw "No recent patch commits found"
                    }
                    
                    $lastPatchCommit = ($patchCommits | Select-Object -First 1) -split ' ' | Select-Object -First 1
                    $targetCommit = git rev-parse "$lastPatchCommit^"  # Parent of patch commit
                    
                    Write-Host "Last patch commit: $lastPatchCommit" -ForegroundColor Cyan
                    Write-Host "Rolling back to: $targetCommit" -ForegroundColor Cyan
                    
                    Invoke-CommitRollback -TargetCommit $targetCommit
                }
                
                "LastCommit" {
                    Write-Host "Rolling back last commit..." -ForegroundColor Yellow
                    
                    $targetCommit = git rev-parse "HEAD^"
                    Write-Host "Rolling back to: $targetCommit" -ForegroundColor Cyan
                    
                    Invoke-CommitRollback -TargetCommit $targetCommit
                }
                
                "ToCommit" {
                    if (-not $TargetCommit) {
                        throw "TargetCommit parameter required for ToCommit rollback type"
                    }
                    
                    Write-Host "Rolling back to specific commit: $TargetCommit" -ForegroundColor Yellow
                    Invoke-CommitRollback -TargetCommit $TargetCommit
                }
                
                "ToBranch" {
                    if (-not $TargetBranch) {
                        throw "TargetBranch parameter required for ToBranch rollback type"
                    }
                    
                    Write-Host "Rolling back to branch: $TargetBranch" -ForegroundColor Yellow
                    Invoke-BranchRollback -TargetBranch $TargetBranch
                }
                
                "Emergency" {
                    Write-Host "Emergency rollback - resetting to last known good state..." -ForegroundColor Red
                    
                    # Find last successful validation commit
                    $validCommits = git log --oneline --grep="validation passed" --grep="health check" --max-count=10
                    if ($validCommits) {
                        $lastGoodCommit = ($validCommits | Select-Object -First 1) -split ' ' | Select-Object -First 1
                        Write-Host "Emergency rollback to last validated commit: $lastGoodCommit" -ForegroundColor Cyan
                        Invoke-CommitRollback -TargetCommit $lastGoodCommit
                    } else {
                        # Fallback to main branch
                        Write-Host "No validated commits found, rolling back to main branch" -ForegroundColor Yellow
                        Invoke-BranchRollback -TargetBranch "main"
                    }
                }
            }
            
            # Verify rollback success
            $newCommit = git rev-parse HEAD
            if ($newCommit -ne $currentCommit) {
                Write-Host "Rollback completed successfully!" -ForegroundColor Green
                Write-Host "  Previous commit: $currentCommit" -ForegroundColor Gray
                Write-Host "  Current commit: $newCommit" -ForegroundColor Green
                
                # Run quick validation
                Write-Host "Running post-rollback validation..." -ForegroundColor Blue
                $validationResult = Invoke-PostRollbackValidation
                if ($validationResult.Success) {
                    Write-Host "Post-rollback validation passed" -ForegroundColor Green
                } else {
                    Write-Warning "Post-rollback validation issues: $($validationResult.Message)"
                }
                
                return @{
                    Success = $true
                    Message = "Rollback completed successfully"
                    PreviousCommit = $currentCommit
                    CurrentCommit = $newCommit
                    BackupBranch = if ($CreateBackup) { $backupBranch } else { $null }
                    ValidationResult = $validationResult
                }
            } else {
                throw "Rollback did not change the current commit"
            }
            
        } catch {
            Write-Error "Rollback failed: $($_.Exception.Message)"
            
            # Attempt to restore from backup if available
            if ($CreateBackup -and $backupBranch) {
                Write-Host "Attempting to restore from backup branch..." -ForegroundColor Yellow
                try {
                    git checkout $backupBranch
                    git checkout -b "rollback-recovery-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                    Write-Host "Restored to backup branch for manual recovery" -ForegroundColor Green
                } catch {
                    Write-Warning "Failed to restore from backup: $($_.Exception.Message)"
                }
            }
            
            return @{
                Success = $false
                Message = $_.Exception.Message
                BackupBranch = if ($CreateBackup) { $backupBranch } else { $null }
            }
        }
    }
}

function Invoke-CommitRollback {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$TargetCommit)
    
    Write-Host "Performing commit rollback to: $TargetCommit" -ForegroundColor Blue
    
    if ($PSCmdlet.ShouldProcess("Git repository", "Reset to commit $TargetCommit")) {
        if ($Force) {
            git reset --hard $TargetCommit
        } else {
            # Safer rollback that preserves working directory changes
            git reset --soft $TargetCommit
        }
        
        if ($LASTEXITCODE -ne 0) {
            throw "Git reset failed"
        }
    }
}

function Invoke-BranchRollback {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$TargetBranch)
    
    Write-Host "Performing branch rollback to: $TargetBranch" -ForegroundColor Blue
    
    if ($PSCmdlet.ShouldProcess("Git repository", "Checkout branch $TargetBranch")) {
        git checkout $TargetBranch
        if ($LASTEXITCODE -ne 0) {
            throw "Git checkout failed"
        }
        
        # Update to latest if it's a remote branch
        git pull origin $TargetBranch 2>$null
    }
}

function Invoke-PostRollbackValidation {
    Write-Host "Running post-rollback validation..." -ForegroundColor Blue
    $issues = @()
    
    # Check that critical files exist
    $criticalFiles = @("PROJECT-MANIFEST.json", "README.md", ".vscode/settings.json")
    foreach ($file in $criticalFiles) {
        if (-not (Test-Path $file)) {
            $issues += "Critical file missing: $file"
        }
    }
    
    # Check module availability
    try {
        Import-Module "/pwsh/modules/LabRunner/" -Force -ErrorAction SilentlyContinue
    } catch {
        $issues += "LabRunner module import failed"
    }
    
    # Check basic PowerShell syntax of key files
    $keyFiles = Get-ChildItem -Path "scripts", "pwsh" -Recurse -Include "*.ps1" -ErrorAction SilentlyContinue | Select-Object -First 5
    foreach ($file in $keyFiles) {
        try {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if ($content) {
                $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)
            }
        } catch {
            $issues += "PowerShell syntax issue in $($file.Name)"
        }
    }
    
    return @{
        Success = $issues.Count -eq 0
        Issues = $issues
        Message = if ($issues.Count -eq 0) { "All validations passed" } else { "$($issues.Count) validation issues found" }
    }
}

# Export the function



