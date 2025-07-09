#Requires -Version 7.0

<#
.SYNOPSIS
    Cleans up old patch branches and helps manage PR workflow

.DESCRIPTION
    Helps maintain a clean patch workflow by:
    - Deleting merged patch branches
    - Removing old local patch branches
    - Optionally closing stale PRs
    - Returning to main branch

.PARAMETER DeleteMerged
    Delete local branches that have been merged

.PARAMETER DeleteOldBranches
    Delete local patch branches older than specified days

.PARAMETER DaysOld
    Number of days to consider a branch "old" (default: 7)

.PARAMETER CloseStaleP
    Close PRs that haven't been updated in specified days

.PARAMETER ReturnToMain
    Switch back to main branch after cleanup

.EXAMPLE
    Invoke-PatchCleanup -DeleteMerged

.EXAMPLE
    Invoke-PatchCleanup -DeleteOldBranches -DaysOld 14 -ReturnToMain
#>

function Invoke-PatchCleanup {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$DeleteMerged,

        [Parameter(Mandatory = $false)]
        [switch]$DeleteOldBranches,

        [Parameter(Mandatory = $false)]
        [int]$DaysOld = 7,

        [Parameter(Mandatory = $false)]
        [switch]$CloseStalePRs,

        [Parameter(Mandatory = $false)]
        [switch]$ReturnToMain
    )

    begin {
        if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
            function Write-CustomLog {
                param($Message, $Level = "INFO")
                Write-Host "[$Level] $Message"
            }
        }

        Write-CustomLog "Starting patch cleanup..." -Level "INFO"
    }

    process {
        try {
            $cleanupCount = 0

            # Get current branch
            $currentBranchResult = Invoke-GitCommand "branch --show-current" -AllowFailure
            $currentBranch = if ($currentBranchResult.Success) { $currentBranchResult.Output | Out-String | ForEach-Object Trim } else { "" }

            # Delete merged branches
            if ($DeleteMerged) {
                Write-CustomLog "Checking for merged branches..." -Level "INFO"

                # Get merged branches
                $mergedResult = Invoke-GitCommand "branch --merged main" -AllowFailure
                if ($mergedResult.Success) {
                    $mergedBranches = $mergedResult.Output | Where-Object {
                        $_ -match '^\s*patch/' -and $_ -notmatch '^\*'
                    }

                    foreach ($branch in $mergedBranches) {
                        $branchName = $branch.Trim()
                        if ($PSCmdlet.ShouldProcess($branchName, "Delete merged branch")) {
                            $deleteResult = Invoke-GitCommand "branch -d '$branchName'" -AllowFailure
                            if ($deleteResult.Success) {
                                Write-CustomLog "Deleted merged branch: $branchName" -Level "SUCCESS"
                                $cleanupCount++
                            }
                        }
                    }
                }
            }

            # Delete old branches
            if ($DeleteOldBranches) {
                Write-CustomLog "Checking for old branches (>$DaysOld days)..." -Level "INFO"

                # Get all patch branches with last commit date
                $branchesResult = Invoke-GitCommand "for-each-ref --format='%(refname:short) %(committerdate:iso8601)' refs/heads/patch/" -AllowFailure
                if ($branchesResult.Success) {
                    $cutoffDate = (Get-Date).AddDays(-$DaysOld)

                    foreach ($line in $branchesResult.Output) {
                        if ($line -match '^(patch/[^\s]+)\s+(.+)$') {
                            $branchName = $matches[1]
                            $lastCommitDate = [DateTime]::Parse($matches[2])

                            if ($lastCommitDate -lt $cutoffDate -and $branchName -ne $currentBranch) {
                                if ($PSCmdlet.ShouldProcess($branchName, "Delete old branch")) {
                                    $deleteResult = Invoke-GitCommand "branch -D '$branchName'" -AllowFailure
                                    if ($deleteResult.Success) {
                                        Write-CustomLog "Deleted old branch: $branchName (last commit: $($lastCommitDate.ToString('yyyy-MM-dd')))" -Level "SUCCESS"
                                        $cleanupCount++
                                    }
                                }
                            }
                        }
                    }
                }
            }

            # Close stale PRs
            if ($CloseStalePRs -and (Get-Command gh -ErrorAction SilentlyContinue)) {
                Write-CustomLog "Checking for stale PRs..." -Level "INFO"

                try {
                    $repoInfo = Get-GitRepositoryInfo
                    $cutoffDate = (Get-Date).AddDays(-$DaysOld).ToString("yyyy-MM-dd")

                    # Get stale PRs
                    $stalePRs = gh pr list --repo $repoInfo.GitHubRepo --state open --search "updated:<$cutoffDate" --json number,title,updatedAt | ConvertFrom-Json

                    foreach ($pr in $stalePRs) {
                        if ($PSCmdlet.ShouldProcess("PR #$($pr.number)", "Close stale PR")) {
                            gh pr close $pr.number --comment "Closing stale PR (no updates in $DaysOld+ days)"
                            Write-CustomLog "Closed stale PR #$($pr.number): $($pr.title)" -Level "SUCCESS"
                            $cleanupCount++
                        }
                    }
                } catch {
                    Write-CustomLog "Unable to check stale PRs: $_" -Level "WARN"
                }
            }

            # Return to main branch
            if ($ReturnToMain -and $currentBranch -ne "main") {
                Write-CustomLog "Returning to main branch..." -Level "INFO"
                $checkoutResult = Invoke-GitCommand "checkout main" -AllowFailure
                if ($checkoutResult.Success) {
                    Write-CustomLog "Switched to main branch" -Level "SUCCESS"
                } else {
                    Write-CustomLog "Failed to switch to main: $($checkoutResult.Output)" -Level "WARN"
                }
            }

            # Summary
            if ($cleanupCount -gt 0) {
                Write-CustomLog "Cleanup complete: $cleanupCount items cleaned" -Level "SUCCESS"
            } else {
                Write-CustomLog "No cleanup needed - workspace is clean!" -Level "INFO"
            }

            return @{
                Success = $true
                ItemsCleaned = $cleanupCount
                CurrentBranch = if ($ReturnToMain -and $currentBranch -ne "main") { "main" } else { $currentBranch }
            }

        } catch {
            Write-CustomLog "Cleanup failed: $_" -Level "ERROR"
            return @{
                Success = $false
                Error = $_.Exception.Message
            }
        }
    }
}

Export-ModuleMember -Function Invoke-PatchCleanup
