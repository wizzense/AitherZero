#Requires -Version 7.0

<#
.SYNOPSIS
    Repository synchronization module for AitherZero <-> aitherlab
.DESCRIPTION
    Manages bidirectional sync between public AitherZero and private aitherlab
#>

function Sync-ToAitherLab {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$CommitMessage,

        [string]$BranchName = "sync/aitherzero-$(Get-Date -Format 'yyyyMMdd-HHmmss')",

        [string[]]$FilesToSync = @(),

        [switch]$CreatePR,

        [switch]$Force
    )

    begin {
        Import-Module "$PSScriptRoot/../Logging" -Force
        Write-CustomLog -Level 'INFO' -Message "Starting sync to aitherlab"
    }

    process {
        try {
            # Ensure we're in a clean state
            $status = git status --porcelain
            if ($status -and -not $Force) {
                throw "Working directory has uncommitted changes. Use -Force to override."
            }

            # Fetch latest from aitherlab
            Write-CustomLog -Level 'INFO' -Message "Fetching latest from aitherlab"
            git fetch aitherlab

            # Create sync branch
            Write-CustomLog -Level 'INFO' -Message "Creating sync branch: $BranchName"
            git checkout -b $BranchName

            # Cherry-pick or merge specific changes
            if ($FilesToSync.Count -gt 0) {
                Write-CustomLog -Level 'INFO' -Message "Syncing specific files: $($FilesToSync -join ', ')"
                foreach ($file in $FilesToSync) {
                    git checkout HEAD -- $file
                }
            }

            # Push to aitherlab
            if ($PSCmdlet.ShouldProcess("aitherlab", "Push branch $BranchName")) {
                git push aitherlab $BranchName
                Write-CustomLog -Level 'SUCCESS' -Message "Pushed branch to aitherlab"

                if ($CreatePR) {
                    Write-CustomLog -Level 'INFO' -Message "Creating PR on aitherlab"
                    # Use GitHub CLI if available
                    try {
                        gh pr create --repo yourusername/aitherlab `
                            --base main `
                            --head $BranchName `
                            --title "Sync from AitherZero: $CommitMessage" `
                            --body "Automated sync from public AitherZero repository"
                    } catch {
                        Write-CustomLog -Level 'WARN' -Message "GitHub CLI not available or failed: $($_.Exception.Message)"
                    }
                }
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Sync failed: $($_.Exception.Message)"
            throw
        } finally {
            # Return to original branch
            git checkout -
        }
    }
}

function Sync-FromAitherLab {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Branch = "main",

        [string[]]$ExcludeFiles = @(".github/workflows/*", "*.secret*", "*.env*"),

        [switch]$DryRun
    )

    begin {
        Import-Module "$PSScriptRoot/../Logging" -Force
        Write-CustomLog -Level 'INFO' -Message "Starting sync from aitherlab"
    }

    process {
        try {
            # Fetch from aitherlab
            git fetch aitherlab

            # Preview changes
            $changes = git diff aitherlab/$Branch..HEAD --name-only
            Write-CustomLog -Level 'INFO' -Message "Files that will be updated: $($changes -join ', ')"

            if ($DryRun) {
                Write-Host "DRY RUN - No changes will be applied" -ForegroundColor Yellow
                return
            }

            # Merge changes, excluding sensitive files
            if ($PSCmdlet.ShouldProcess("local", "Merge from aitherlab/$Branch")) {
                # Create temp branch
                git checkout -b temp-sync-branch aitherlab/$Branch

                # Remove excluded files
                foreach ($pattern in $ExcludeFiles) {
                    git rm -rf $pattern 2>$null
                }

                # Commit exclusions
                git commit -m "Exclude sensitive files from sync" 2>$null

                # Merge back
                git checkout -
                git merge temp-sync-branch --no-ff -m "Sync from aitherlab (filtered)"

                # Cleanup
                git branch -D temp-sync-branch
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Sync failed: $($_.Exception.Message)"
            throw
        }
    }
}

function Get-SyncStatus {
    [CmdletBinding()]
    param()

    begin {
        Import-Module "$PSScriptRoot/../Logging" -Force
    }

    process {
        Write-Host "`nRepository Sync Status:" -ForegroundColor Cyan
        Write-Host "======================" -ForegroundColor Cyan

        # Check remotes
        Write-Host "`nConfigured Remotes:" -ForegroundColor Yellow
        git remote -v

        # Check divergence
        Write-Host "`nDivergence from aitherlab:" -ForegroundColor Yellow
        try {
            git fetch aitherlab --quiet
            $ahead = git rev-list --count aitherlab/main..HEAD
            $behind = git rev-list --count HEAD..aitherlab/main

            Write-Host "  Ahead:  $ahead commits" -ForegroundColor $(if ($ahead -gt 0) { 'Green' } else { 'Gray' })
            Write-Host "  Behind: $behind commits" -ForegroundColor $(if ($behind -gt 0) { 'Yellow' } else { 'Gray' })
        } catch {
            Write-Host "  Unable to check divergence: $($_.Exception.Message)" -ForegroundColor Red
        }

        # Show different files
        Write-Host "`nFiles different from aitherlab:" -ForegroundColor Yellow
        try {
            git diff aitherlab/main --name-only
        } catch {
            Write-Host "  Unable to compare files" -ForegroundColor Red
        }
    }
}

Export-ModuleMember -Function @(
    'Sync-ToAitherLab',
    'Sync-FromAitherLab',
    'Get-SyncStatus'
)
