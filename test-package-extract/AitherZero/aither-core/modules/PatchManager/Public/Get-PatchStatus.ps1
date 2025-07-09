#Requires -Version 7.0

<#
.SYNOPSIS
    Shows current PatchManager status including open PRs, branches, and uncommitted changes

.DESCRIPTION
    Provides a comprehensive view of your current patch workflow state:
    - Open pull requests
    - Local branches with unpushed changes
    - Uncommitted changes
    - Suggestions for next steps

.EXAMPLE
    Get-PatchStatus

.EXAMPLE
    Get-PatchStatus -ShowAll
#>

function Get-PatchStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$ShowAll
    )

    begin {
        if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
            function Write-CustomLog {
                param($Message, $Level = "INFO")
                Write-Host "[$Level] $Message"
            }
        }

        Write-CustomLog "Checking PatchManager status..." -Level "INFO"
    }

    process {
        try {
            $status = @{
                OpenPRs = @()
                LocalBranches = @()
                UncommittedChanges = $false
                CurrentBranch = ""
                Suggestions = @()
            }

            # Get current branch
            $currentBranchResult = Invoke-GitCommand "branch --show-current" -AllowFailure
            if ($currentBranchResult.Success) {
                $status.CurrentBranch = $currentBranchResult.Output | Out-String | ForEach-Object Trim
            }

            # Check for uncommitted changes
            $gitStatusResult = Invoke-GitCommand "status --porcelain" -AllowFailure
            if ($gitStatusResult.Success -and $gitStatusResult.Output) {
                $status.UncommittedChanges = $true
            }

            # Get open PRs
            if (Get-Command gh -ErrorAction SilentlyContinue) {
                try {
                    $repoInfo = Get-GitRepositoryInfo
                    $prs = gh pr list --repo $repoInfo.GitHubRepo --state open --json number,title,headRefName,createdAt --limit 20 | ConvertFrom-Json
                    $status.OpenPRs = $prs | Where-Object { $_.headRefName -like "patch/*" }
                } catch {
                    Write-CustomLog "Unable to fetch PR information: $_" -Level "WARN"
                }
            }

            # Get local branches
            $branchesResult = Invoke-GitCommand "branch -v" -AllowFailure
            if ($branchesResult.Success) {
                $localBranches = $branchesResult.Output | Where-Object { $_ -match '^\s*patch/' }
                $status.LocalBranches = $localBranches
            }

            # Display status
            Write-Host "`n=== PatchManager Status ===" -ForegroundColor Cyan
            Write-Host "Current Branch: $($status.CurrentBranch)" -ForegroundColor Yellow

            if ($status.UncommittedChanges) {
                Write-Host "`nUncommitted Changes: YES" -ForegroundColor Red
                $status.Suggestions += "Commit or stash your changes before creating new patches"
            } else {
                Write-Host "`nUncommitted Changes: None" -ForegroundColor Green
            }

            if ($status.OpenPRs.Count -gt 0) {
                Write-Host "`nOpen Pull Requests ($($status.OpenPRs.Count)):" -ForegroundColor Yellow
                foreach ($pr in $status.OpenPRs) {
                    Write-Host "  - PR #$($pr.number): $($pr.title)" -ForegroundColor Cyan
                    Write-Host "    Branch: $($pr.headRefName)" -ForegroundColor DarkGray
                }

                if ($status.OpenPRs.Count -ge 3) {
                    $status.Suggestions += "Consider merging or closing existing PRs before creating new ones"
                }
            } else {
                Write-Host "`nOpen Pull Requests: None" -ForegroundColor Green
            }

            if ($ShowAll -and $status.LocalBranches.Count -gt 0) {
                Write-Host "`nLocal Patch Branches:" -ForegroundColor Yellow
                foreach ($branch in $status.LocalBranches) {
                    Write-Host "  $branch" -ForegroundColor DarkGray
                }
            }

            # Provide suggestions
            if ($status.Suggestions.Count -gt 0) {
                Write-Host "`nSuggestions:" -ForegroundColor Magenta
                foreach ($suggestion in $status.Suggestions) {
                    Write-Host "  • $suggestion" -ForegroundColor White
                }
            } else {
                Write-Host "`nStatus: Ready for new patches!" -ForegroundColor Green
            }

            # Return to main branch suggestion
            if ($status.CurrentBranch -like "patch/*" -and -not $status.UncommittedChanges) {
                Write-Host "`nTip: You're on a patch branch. Consider returning to main:" -ForegroundColor Yellow
                Write-Host "  git checkout main" -ForegroundColor Cyan
            }

            Write-Host ""

            return $status

        } catch {
            Write-CustomLog "Failed to get patch status: $_" -Level "ERROR"
            throw
        }
    }
}

Export-ModuleMember -Function Get-PatchStatus
