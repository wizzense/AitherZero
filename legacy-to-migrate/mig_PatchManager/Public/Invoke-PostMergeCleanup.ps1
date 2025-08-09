#Requires -Version 7.0

<#
.SYNOPSIS
    Handles post-merge cleanup operations for PatchManager workflows

.DESCRIPTION
    This function provides comprehensive cleanup after a PR is merged:
    - Switches back to main branch
    - Pulls latest changes from origin
    - Deletes the local patch branch (if it exists)
    - Optionally validates the merge was successful
    - Provides guidance for next steps

.PARAMETER BranchName
    Name of the patch branch to clean up

.PARAMETER PullRequestNumber
    PR number that was merged (for validation)

.PARAMETER ValidateMerge
    Verify that the merge was successful before cleanup

.PARAMETER Force
    Force cleanup even if validation fails

.PARAMETER DryRun
    Preview cleanup actions without executing them

.EXAMPLE
    Invoke-PostMergeCleanup -BranchName "patch/fix-module-loading" -PullRequestNumber 123
    # Standard cleanup after PR merge

.EXAMPLE
    Invoke-PostMergeCleanup -BranchName "patch/critical-fix" -ValidateMerge -Force
    # Cleanup with merge validation and force if needed

.EXAMPLE
    Invoke-PostMergeCleanup -BranchName "patch/feature-update" -DryRun
    # Preview what cleanup would do
#>

function Invoke-PostMergeCleanup {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BranchName,

        [Parameter(Mandatory = $false)]
        [int]$PullRequestNumber,

        [Parameter(Mandatory = $false)]
        [switch]$ValidateMerge,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    begin {
        # Import required modules
        if (-not (Get-Module -Name Logging -ListAvailable)) {
            Import-Module (Join-Path $PSScriptRoot '../../../Logging') -Force -ErrorAction SilentlyContinue
        }

        function Write-CleanupLog {
            param($Message, $Level = 'INFO')
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Message $Message -Level $Level
            } else {
                Write-Host "[$Level] $Message"
            }
        }

        Write-CleanupLog "Starting post-merge cleanup for branch: $BranchName" -Level 'INFO'

        if ($DryRun) {
            Write-CleanupLog 'DRY RUN MODE: No actual changes will be made' -Level 'WARN'
        }
    }

    process {
        try {
            # Step 1: Get current state
            $currentBranch = git branch --show-current 2>&1
            $isMainBranch = ($currentBranch -eq 'main' -or $currentBranch -eq 'master')

            Write-CleanupLog "Current branch: $currentBranch" -Level 'INFO'

            # Step 2: Validate merge if requested
            if ($ValidateMerge -and $PullRequestNumber) {
                Write-CleanupLog "Validating that PR #$PullRequestNumber was merged..." -Level 'INFO'

                if (-not $DryRun) {
                    try {
                        $repoInfo = Get-GitRepositoryInfo
                        $prStatus = gh pr view $PullRequestNumber --repo $repoInfo.GitHubRepo --json "state,merged" 2>&1
                        
                        if ($LASTEXITCODE -eq 0) {
                            $prData = $prStatus | ConvertFrom-Json
                            
                            if ($prData.merged) {
                                Write-CleanupLog "✓ PR #$PullRequestNumber was successfully merged" -Level 'SUCCESS'
                            } elseif ($prData.state -eq 'CLOSED') {
                                Write-CleanupLog "⚠ PR #$PullRequestNumber was closed without merging" -Level 'WARN'
                                if (-not $Force) {
                                    throw "PR was closed without merging. Use -Force to cleanup anyway."
                                }
                            } else {
                                Write-CleanupLog "⚠ PR #$PullRequestNumber is still open" -Level 'WARN'
                                if (-not $Force) {
                                    throw "PR is still open. Use -Force to cleanup anyway."
                                }
                            }
                        } else {
                            Write-CleanupLog "Warning: Could not validate PR status: $prStatus" -Level 'WARN'
                            if (-not $Force) {
                                throw "Could not validate PR merge status. Use -Force to cleanup anyway."
                            }
                        }
                    } catch {
                        Write-CleanupLog "Merge validation failed: $($_.Exception.Message)" -Level 'ERROR'
                        if (-not $Force) {
                            throw
                        }
                        Write-CleanupLog "Continuing cleanup due to -Force flag" -Level 'WARN'
                    }
                } else {
                    Write-CleanupLog "DRY RUN: Would validate PR #$PullRequestNumber merge status" -Level 'INFO'
                }
            }

            # Step 3: Switch to main branch if not already there
            if (-not $isMainBranch) {
                Write-CleanupLog "Switching to main branch..." -Level 'INFO'

                if ($PSCmdlet.ShouldProcess("main branch", "Switch to")) {
                    if (-not $DryRun) {
                        $switchResult = git checkout main 2>&1
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-CleanupLog "✓ Successfully switched to main branch" -Level 'SUCCESS'
                        } else {
                            # Try master as fallback
                            $switchResult = git checkout master 2>&1
                            if ($LASTEXITCODE -eq 0) {
                                Write-CleanupLog "✓ Successfully switched to master branch" -Level 'SUCCESS'
                            } else {
                                Write-CleanupLog "Failed to switch to main/master: $switchResult" -Level 'ERROR'
                                throw "Could not switch to main branch: $switchResult"
                            }
                        }
                    } else {
                        Write-CleanupLog "DRY RUN: Would switch to main branch" -Level 'INFO'
                    }
                }
            } else {
                Write-CleanupLog "Already on main branch" -Level 'INFO'
            }

            # Step 4: Pull latest changes from origin
            Write-CleanupLog "Pulling latest changes from origin..." -Level 'INFO'

            if ($PSCmdlet.ShouldProcess("origin main", "Pull latest changes")) {
                if (-not $DryRun) {
                    # Fetch first to get latest refs
                    git fetch origin 2>&1 | Out-Null
                    
                    # Determine the default branch name
                    $defaultBranch = git symbolic-ref refs/remotes/origin/HEAD 2>&1 | ForEach-Object { $_.Split('/')[-1] }
                    if (-not $defaultBranch) {
                        $defaultBranch = 'main'  # Default fallback
                    }

                    $pullResult = git pull origin $defaultBranch 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-CleanupLog "✓ Successfully pulled latest changes" -Level 'SUCCESS'
                    } else {
                        Write-CleanupLog "Warning: Pull may have had issues: $pullResult" -Level 'WARN'
                        # Don't fail the cleanup for pull issues
                    }
                } else {
                    Write-CleanupLog "DRY RUN: Would pull latest changes from origin" -Level 'INFO'
                }
            }

            # Step 5: Delete the patch branch (local only - remote should be auto-deleted by GitHub)
            Write-CleanupLog "Checking if patch branch exists locally..." -Level 'INFO'

            if (-not $DryRun) {
                # Check if branch exists locally
                git show-ref --verify --quiet "refs/heads/$BranchName" 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-CleanupLog "Local patch branch exists, deleting..." -Level 'INFO'

                    if ($PSCmdlet.ShouldProcess($BranchName, "Delete local branch")) {
                        git branch -d $BranchName 2>&1 | Out-Null
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-CleanupLog "✓ Successfully deleted local branch: $BranchName" -Level 'SUCCESS'
                        } else {
                            # Try force delete if regular delete fails
                            Write-CleanupLog "Regular delete failed, trying force delete..." -Level 'WARN'
                            $forceDeleteResult = git branch -D $BranchName 2>&1
                            
                            if ($LASTEXITCODE -eq 0) {
                                Write-CleanupLog "✓ Force deleted local branch: $BranchName" -Level 'SUCCESS'
                            } else {
                                Write-CleanupLog "Warning: Could not delete local branch: $forceDeleteResult" -Level 'WARN'
                            }
                        }
                    }
                } else {
                    Write-CleanupLog "Local patch branch does not exist (may have been cleaned up already)" -Level 'INFO'
                }
            } else {
                Write-CleanupLog "DRY RUN: Would check for and delete local branch: $BranchName" -Level 'INFO'
            }

            # Step 6: Cleanup summary and guidance
            Write-CleanupLog "Post-merge cleanup completed successfully" -Level 'SUCCESS'
            Write-CleanupLog "Repository state:" -Level 'INFO'

            if (-not $DryRun) {
                $finalBranch = git branch --show-current 2>&1
                $status = git status --porcelain 2>&1
                $statusCount = if ($status) { ($status | Measure-Object).Count } else { 0 }
                
                Write-CleanupLog "  Current branch: $finalBranch" -Level 'INFO'
                Write-CleanupLog "  Working tree: $statusCount uncommitted changes" -Level 'INFO'
                
                # Show latest commits to confirm merge
                Write-CleanupLog "Recent commits:" -Level 'INFO'
                $recentCommits = git log --oneline -3 2>&1
                if ($recentCommits) {
                    $recentCommits | ForEach-Object {
                        Write-CleanupLog "  $_" -Level 'INFO'
                    }
                }
            } else {
                Write-CleanupLog "  DRY RUN: Would show final repository state" -Level 'INFO'
            }

            # Success result
            return @{
                Success = $true
                Message = 'Post-merge cleanup completed successfully'
                BranchCleaned = $BranchName
                CurrentBranch = if (-not $DryRun) { git branch --show-current 2>&1 } else { 'main (dry run)' }
                DryRun = $DryRun.IsPresent
            }

        } catch {
            $errorMessage = "Post-merge cleanup failed: $($_.Exception.Message)"
            Write-CleanupLog $errorMessage -Level 'ERROR'

            return @{
                Success = $false
                Message = $errorMessage
                BranchCleaned = $BranchName
                DryRun = $DryRun.IsPresent
            }
        }
    }
}

Export-ModuleMember -Function Invoke-PostMergeCleanup
