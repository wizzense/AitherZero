#Requires -Version 7.0

<#
.SYNOPSIS
    Synchronizes local branches with remote to prevent divergence and conflicts

.DESCRIPTION
    This function ensures that local branches are properly synchronized with remote branches
    to prevent divergence issues. It handles:
    - Fetching latest remote changes
    - Detecting divergence between local and remote
    - Safely resetting local branches when diverged
    - Cleaning up orphaned branches
    - Preventing duplicate tags

.PARAMETER BranchName
    Name of the branch to sync (default: current branch)

.PARAMETER Force
    Force reset local branch to match remote if diverged

.PARAMETER CleanupOrphaned
    Remove local branches that don't exist on remote

.PARAMETER ValidateTags
    Check and report duplicate or conflicting tags

.EXAMPLE
    Sync-GitBranch
    # Sync current branch with remote

.EXAMPLE
    Sync-GitBranch -BranchName "main" -Force
    # Force sync main branch with remote

.EXAMPLE
    Sync-GitBranch -CleanupOrphaned -ValidateTags
    # Full cleanup and validation
#>

function Sync-GitBranch {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$BranchName = "",

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$CleanupOrphaned,

        [Parameter(Mandatory = $false)]
        [switch]$ValidateTags
    )

    begin {
        # Import logging if available
        if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
            function Write-CustomLog {
                param($Message, $Level = "INFO")
                Write-Host "[$Level] $Message"
            }
        }

        Write-CustomLog "Starting Git branch synchronization..." -Level "INFO"
    }

    process {
        try {
            # Get current branch if not specified
            if (-not $BranchName) {
                # Use direct git command instead of Invoke-GitCommand to avoid dependency issues
                try {
                    $BranchName = git branch --show-current 2>&1 | Out-String | ForEach-Object Trim
                    if ($LASTEXITCODE -ne 0 -or -not $BranchName) {
                        throw "Could not determine current branch"
                    }
                } catch {
                    throw "Could not determine current branch: $($_.Exception.Message)"
                }
            }

            Write-CustomLog "Synchronizing branch: $BranchName" -Level "INFO"

            # Step 1: Fetch all remote changes
            Write-CustomLog "Fetching latest changes from remote..." -Level "INFO"
            git fetch --all --prune 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to fetch from remote"
            }

            # Step 2: Check if remote branch exists
            $remoteBranch = "origin/$BranchName"
            $remoteExists = git ls-remote --heads origin $BranchName 2>&1
            if ($LASTEXITCODE -ne 0 -or -not $remoteExists) {
                Write-CustomLog "Branch '$BranchName' does not exist on remote" -Level "WARN"
                return @{
                    Success = $true
                    Message = "Local-only branch (no remote tracking)"
                    LocalOnly = $true
                }
            }

            # Step 3: Check for divergence
            $localCommit = git rev-parse $BranchName 2>&1 | Out-String | ForEach-Object Trim
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to get local commit hash for $BranchName"
            }
            
            $remoteCommit = git rev-parse $remoteBranch 2>&1 | Out-String | ForEach-Object Trim
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to get remote commit hash for $remoteBranch"
            }

            if ($localCommit -eq $remoteCommit) {
                Write-CustomLog "Branch '$BranchName' is up to date with remote" -Level "SUCCESS"
            } else {
                # Check if we're ahead, behind, or diverged
                $ahead = git rev-list --count "$remoteBranch..$BranchName" 2>&1 | Out-String | ForEach-Object Trim
                if ($LASTEXITCODE -ne 0) { $ahead = "0" }
                
                $behind = git rev-list --count "$BranchName..$remoteBranch" 2>&1 | Out-String | ForEach-Object Trim
                if ($LASTEXITCODE -ne 0) { $behind = "0" }

                if ($ahead -gt 0 -and $behind -gt 0) {
                    Write-CustomLog "Branch '$BranchName' has DIVERGED from remote!" -Level "WARN"
                    Write-CustomLog "  Local is $ahead commits ahead and $behind commits behind remote" -Level "WARN"

                    if ($Force -or $PSCmdlet.ShouldProcess("Reset $BranchName to match $remoteBranch", "Reset diverged branch?")) {
                        # Stash any uncommitted changes
                        $hasChanges = git status --porcelain 2>&1
                        if ($hasChanges) {
                            Write-CustomLog "Stashing uncommitted changes..." -Level "INFO"
                            git stash push -m "Sync-GitBranch: Auto-stash before reset" 2>&1 | Out-Null
                        }

                        # Reset to remote
                        Write-CustomLog "Resetting '$BranchName' to match remote..." -Level "INFO"
                        git reset --hard $remoteBranch 2>&1 | Out-Null
                        if ($LASTEXITCODE -ne 0) {
                            throw "Failed to reset branch"
                        }

                        Write-CustomLog "Successfully reset '$BranchName' to match remote" -Level "SUCCESS"

                        # Restore stashed changes if any
                        if ($hasChanges) {
                            Write-CustomLog "Attempting to restore stashed changes..." -Level "INFO"
                            git stash pop 2>&1 | Out-Null
                            if ($LASTEXITCODE -ne 0) {
                                Write-CustomLog "Could not automatically restore changes. Run 'git stash list' to see stashed changes" -Level "WARN"
                            }
                        }
                    } else {
                        Write-CustomLog "Skipping reset. Use -Force to reset diverged branch" -Level "INFO"
                    }
                } elseif ($ahead -gt 0) {
                    Write-CustomLog "Branch '$BranchName' is $ahead commits ahead of remote" -Level "INFO"
                    Write-CustomLog "Run 'git push' to update remote" -Level "INFO"
                } elseif ($behind -gt 0) {
                    Write-CustomLog "Branch '$BranchName' is $behind commits behind remote" -Level "INFO"
                    
                    if ($PSCmdlet.ShouldProcess("Pull $behind commits from $remoteBranch", "Update local branch?")) {
                        Write-CustomLog "Pulling changes from remote..." -Level "INFO"
                        git pull --ff-only origin $BranchName 2>&1 | Out-Null
                        if ($LASTEXITCODE -ne 0) {
                            Write-CustomLog "Fast-forward pull failed. Branch may have local changes" -Level "WARN"
                        } else {
                            Write-CustomLog "Successfully updated '$BranchName' from remote" -Level "SUCCESS"
                        }
                    }
                }
            }

            # Step 4: Cleanup orphaned branches
            if ($CleanupOrphaned) {
                Write-CustomLog "Checking for orphaned local branches..." -Level "INFO"
                
                # Get all local branches
                $localBranches = git branch --format="%(refname:short)" 2>&1 | Where-Object { $_ -ne "main" -and $_ -ne "master" }
                
                # Get all remote branches
                $remoteBranches = git branch -r --format="%(refname:short)" 2>&1 | ForEach-Object { $_ -replace "^origin/", "" }
                
                foreach ($branch in $localBranches) {
                    if ($branch -notin $remoteBranches) {
                        Write-CustomLog "Found orphaned branch: $branch" -Level "WARN"
                        
                        if ($PSCmdlet.ShouldProcess("Delete orphaned branch $branch", "Delete orphaned branch?")) {
                            git branch -D $branch 2>&1 | Out-Null
                            if ($LASTEXITCODE -eq 0) {
                                Write-CustomLog "Deleted orphaned branch: $branch" -Level "SUCCESS"
                            }
                        }
                    }
                }
            }

            # Step 5: Validate tags
            if ($ValidateTags) {
                Write-CustomLog "Validating tags..." -Level "INFO"
                
                # Check for tags not on remote
                $localTags = git tag -l 2>&1
                $remoteTags = git ls-remote --tags origin 2>&1 | ForEach-Object { 
                    if ($_ -match "refs/tags/(.+)$") { $matches[1] }
                }
                
                foreach ($tag in $localTags) {
                    if ($tag -notin $remoteTags) {
                        Write-CustomLog "Local tag not on remote: $tag" -Level "WARN"
                    }
                }
                
                # Check for duplicate tags pointing to different commits
                $tagCommits = @{}
                git show-ref --tags 2>&1 | ForEach-Object {
                    if ($_ -match "^(\w+)\s+refs/tags/(.+)$") {
                        $commit = $matches[1]
                        $tag = $matches[2]
                        if ($tagCommits.ContainsKey($tag)) {
                            if ($tagCommits[$tag] -ne $commit) {
                                Write-CustomLog "Duplicate tag with different commits: $tag" -Level "ERROR"
                            }
                        } else {
                            $tagCommits[$tag] = $commit
                        }
                    }
                }
            }

            return @{
                Success = $true
                Message = "Synchronization completed successfully"
                Branch = $BranchName
            }

        } catch {
            Write-CustomLog "Synchronization failed: $($_.Exception.Message)" -Level "ERROR"
            return @{
                Success = $false
                Message = $_.Exception.Message
                Branch = $BranchName
            }
        }
    }
}

Export-ModuleMember -Function Sync-GitBranch