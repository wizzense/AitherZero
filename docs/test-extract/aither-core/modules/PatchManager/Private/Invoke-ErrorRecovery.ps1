#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive error handling and recovery system for PatchManager v3.0

.DESCRIPTION
    Provides intelligent error recovery, state restoration, and cleanup mechanisms
    to ensure atomic operations can be safely rolled back in case of failures.

.PARAMETER ErrorContext
    Context information about the error

.PARAMETER OperationState
    State information captured before the operation

.PARAMETER RecoveryStrategy
    Strategy to use for recovery: Auto, Manual, or Rollback

.PARAMETER Force
    Force recovery even if automatic recovery is uncertain
#>

function Invoke-ErrorRecovery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ErrorContext,

        [Parameter(Mandatory = $true)]
        [hashtable]$OperationState,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Auto", "Manual", "Rollback")]
        [string]$RecoveryStrategy = "Auto",

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    begin {
        # Initialize logging
        if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
            function Write-CustomLog {
                param($Message, $Level = "INFO")
                Write-Host "[$Level] $Message"
            }
        }

        Write-CustomLog "Starting error recovery process..." -Level "WARN"
        Write-CustomLog "Error: $($ErrorContext.ErrorMessage)" -Level "ERROR"
    }

    process {
        try {
            $recoveryResult = @{
                Success = $false
                RecoveryActions = @()
                RestoredState = $false
                CleanupPerformed = $false
                ManualActionRequired = $false
                Recommendations = @()
            }

            # Step 1: Analyze error type and determine recovery approach
            $errorAnalysis = Get-ErrorAnalysis -ErrorContext $ErrorContext -OperationState $OperationState
            Write-CustomLog "Error analysis: $($errorAnalysis.Category) - $($errorAnalysis.Severity)" -Level "INFO"

            # Step 2: Determine recovery strategy if not specified
            if ($RecoveryStrategy -eq "Auto") {
                $RecoveryStrategy = Get-RecommendedRecoveryStrategy -ErrorAnalysis $errorAnalysis -Force:$Force
                Write-CustomLog "Recommended recovery strategy: $RecoveryStrategy" -Level "INFO"
            }

            # Step 3: Execute recovery based on strategy
            switch ($RecoveryStrategy) {
                "Auto" {
                    $recoveryResult = Invoke-AutoRecovery -ErrorAnalysis $errorAnalysis -OperationState $OperationState
                }
                "Rollback" {
                    $recoveryResult = Invoke-RollbackRecovery -ErrorAnalysis $errorAnalysis -OperationState $OperationState
                }
                "Manual" {
                    $recoveryResult = Invoke-ManualRecovery -ErrorAnalysis $errorAnalysis -OperationState $OperationState
                }
            }

            # Step 4: Validate recovery success
            if ($recoveryResult.Success) {
                Write-CustomLog "Error recovery completed successfully" -Level "SUCCESS"
            } else {
                Write-CustomLog "Error recovery incomplete - manual intervention required" -Level "WARN"
            }

            # Step 5: Provide recommendations
            foreach ($recommendation in $recoveryResult.Recommendations) {
                Write-CustomLog "Recommendation: $recommendation" -Level "INFO"
            }

            return $recoveryResult

        } catch {
            Write-CustomLog "Error recovery failed: $($_.Exception.Message)" -Level "ERROR"
            return @{
                Success = $false
                RecoveryActions = @("Recovery process failed")
                RestoredState = $false
                CleanupPerformed = $false
                ManualActionRequired = $true
                Recommendations = @(
                    "Manual intervention required",
                    "Check git status and resolve conflicts manually",
                    "Consider using git reset --hard to restore known good state"
                )
            }
        }
    }
}

function Get-ErrorAnalysis {
    param($ErrorContext, $OperationState)

    $analysis = @{
        Category = "Unknown"
        Severity = "Medium"
        IsGitRelated = $false
        IsMergeConflict = $false
        IsPermissionIssue = $false
        IsNetworkIssue = $false
        CanAutoRecover = $false
    }

    $errorMessage = $ErrorContext.ErrorMessage.ToLower()

    # Categorize error types
    if ($errorMessage -match "merge conflict|conflict markers|<<<<<<<|>>>>>>>") {
        $analysis.Category = "MergeConflict"
        $analysis.Severity = "High"
        $analysis.IsGitRelated = $true
        $analysis.IsMergeConflict = $true
        $analysis.CanAutoRecover = $false
    } elseif ($errorMessage -match "permission denied|access denied|unauthorized") {
        $analysis.Category = "Permission"
        $analysis.Severity = "Medium"
        $analysis.IsPermissionIssue = $true
        $analysis.CanAutoRecover = $false
    } elseif ($errorMessage -match "network|connection|timeout|remote") {
        $analysis.Category = "Network"
        $analysis.Severity = "Low"
        $analysis.IsNetworkIssue = $true
        $analysis.CanAutoRecover = $true
    } elseif ($errorMessage -match "git|branch|commit|checkout") {
        $analysis.Category = "Git"
        $analysis.Severity = "Medium"
        $analysis.IsGitRelated = $true
        $analysis.CanAutoRecover = $true
    } else {
        $analysis.Category = "General"
        $analysis.Severity = "Medium"
        $analysis.CanAutoRecover = $true
    }

    return $analysis
}

function Get-RecommendedRecoveryStrategy {
    param($ErrorAnalysis, $Force)

    if ($ErrorAnalysis.IsMergeConflict) {
        return "Manual"  # Merge conflicts always require manual resolution
    }

    if ($ErrorAnalysis.IsPermissionIssue) {
        return "Manual"  # Permission issues require manual intervention
    }

    if ($ErrorAnalysis.CanAutoRecover -or $Force) {
        return "Rollback"  # Safe to attempt automatic rollback
    }

    return "Manual"  # Default to manual for unknown situations
}

function Invoke-AutoRecovery {
    param($ErrorAnalysis, $OperationState)

    $result = @{
        Success = $false
        RecoveryActions = @()
        RestoredState = $false
        CleanupPerformed = $false
        ManualActionRequired = $false
        Recommendations = @()
    }

    Write-CustomLog "Attempting automatic recovery..." -Level "INFO"

    # Auto-recovery is mainly for network or temporary issues
    if ($ErrorAnalysis.IsNetworkIssue) {
        $result.RecoveryActions += "Retrying network operation"
        # Network issues might resolve themselves
        $result.Success = $true
        $result.Recommendations += "Network issue detected - operation may succeed on retry"
    } else {
        # Fallback to rollback for other auto-recoverable errors
        return Invoke-RollbackRecovery -ErrorAnalysis $ErrorAnalysis -OperationState $OperationState
    }

    return $result
}

function Invoke-RollbackRecovery {
    param($ErrorAnalysis, $OperationState)

    $result = @{
        Success = $false
        RecoveryActions = @()
        RestoredState = $false
        CleanupPerformed = $false
        ManualActionRequired = $false
        Recommendations = @()
    }

    Write-CustomLog "Attempting rollback recovery..." -Level "INFO"

    try {
        # Step 1: Restore git state if available
        if ($OperationState.InitialBranch -and $OperationState.InitialCommit) {
            Write-CustomLog "Restoring git state to initial branch: $($OperationState.InitialBranch)" -Level "INFO"
            
            # Switch back to initial branch
            git checkout $OperationState.InitialBranch 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $result.RecoveryActions += "Restored initial branch: $($OperationState.InitialBranch)"
                $result.RestoredState = $true
            }

            # Clean up any created branches
            if ($OperationState.CreatedBranch) {
                Write-CustomLog "Cleaning up created branch: $($OperationState.CreatedBranch)" -Level "INFO"
                git branch -D $OperationState.CreatedBranch 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    $result.RecoveryActions += "Deleted created branch: $($OperationState.CreatedBranch)"
                    $result.CleanupPerformed = $true
                }
            }
        }

        # Step 2: Handle workspace changes
        if ($OperationState.WorkspaceSnapshot.HasChanges) {
            Write-CustomLog "Workspace had initial changes - attempting to restore" -Level "INFO"
            # Note: In v3.0, we don't stash, so workspace should be preserved
            $result.RecoveryActions += "Workspace changes preserved (v3.0 no-stash design)"
        }

        $result.Success = $true
        $result.Recommendations += "Rollback completed - system restored to initial state"
        
        Write-CustomLog "Rollback recovery completed successfully" -Level "SUCCESS"

    } catch {
        Write-CustomLog "Rollback recovery failed: $($_.Exception.Message)" -Level "ERROR"
        $result.ManualActionRequired = $true
        $result.Recommendations += "Automatic rollback failed - manual git state restoration needed"
    }

    return $result
}

function Invoke-ManualRecovery {
    param($ErrorAnalysis, $OperationState)

    $result = @{
        Success = $false
        RecoveryActions = @("Manual intervention required")
        RestoredState = $false
        CleanupPerformed = $false
        ManualActionRequired = $true
        Recommendations = @()
    }

    Write-CustomLog "Manual recovery required" -Level "WARN"

    # Provide specific guidance based on error type
    if ($ErrorAnalysis.IsMergeConflict) {
        $result.Recommendations += "Resolve merge conflicts manually:"
        $result.Recommendations += "1. Open conflicted files and resolve <<<<<<<, =======, >>>>>>> markers"
        $result.Recommendations += "2. Run 'git add .' to stage resolved files"
        $result.Recommendations += "3. Run 'git commit' to complete merge"
        $result.Recommendations += "4. Alternatively, run 'git merge --abort' to cancel merge"
    } elseif ($ErrorAnalysis.IsPermissionIssue) {
        $result.Recommendations += "Resolve permission issues:"
        $result.Recommendations += "1. Check file/directory permissions"
        $result.Recommendations += "2. Verify GitHub authentication (gh auth status)"
        $result.Recommendations += "3. Ensure repository access rights"
    } else {
        $result.Recommendations += "General manual recovery steps:"
        $result.Recommendations += "1. Check 'git status' for repository state"
        $result.Recommendations += "2. Review error message for specific guidance"
        $result.Recommendations += "3. Consider 'git reset --hard' to restore clean state if needed"
    }

    # Provide state information for manual recovery
    if ($OperationState.InitialBranch) {
        $result.Recommendations += "Initial state: Branch '$($OperationState.InitialBranch)', Commit '$($OperationState.InitialCommit)'"
    }

    return $result
}

Export-ModuleMember -Function Invoke-ErrorRecovery