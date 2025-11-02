#Requires -Version 7.0

<#
.SYNOPSIS
    Push Git branch to remote repository
.DESCRIPTION
    Pushes the current or specified branch to remote repository with
    options for upstream tracking and force push.
.NOTES
    Stage: Development
    Category: Git
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Branch,

    [string]$Remote = 'origin',

    [switch]$SetUpstream,

    [switch]$Force,

    [switch]$ForceWithLease,

    [switch]$Tags,

    [switch]$All,

    [switch]$DryRun,

    [switch]$NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import Git module
$devModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/development"
Import-Module (Join-Path $devModulePath "GitAutomation.psm1") -Force

Write-Host "Pushing branch to remote..." -ForegroundColor Cyan

# Get current git status
$status = Get-GitStatus

# Determine branch to push
if (-not $Branch) {
    $Branch = $status.Branch
    if (-not $Branch) {
        Write-Error "Could not determine current branch"
        exit 1
    }
}

Write-Host "Branch: $Branch" -ForegroundColor Yellow
Write-Host "Remote: $Remote" -ForegroundColor Yellow

# Check if branch exists on remote
$remoteBranches = git branch -r 2>$null | ForEach-Object { $_.Trim() }
$remoteBranchExists = $remoteBranches -contains "$Remote/$Branch"

# Check for uncommitted changes
if (-not $status.Clean -and -not $NonInteractive -and -not $Force) {
    Write-Warning "You have uncommitted changes:"
    $allChanges = @()
    if ($status.Modified) { $allChanges += $status.Modified }
    if ($status.Untracked) { $allChanges += $status.Untracked }

    $allChanges | ForEach-Object {
        if ($_) {
            $filePath = if ($_.Path) { $_.Path } elseif ($_ -is [string]) { $_ } else { $_.ToString() }
            Write-Host "  $filePath" -ForegroundColor Yellow
        }
    }

    $response = Read-Host "Continue with push? (y/N)"
    if ($response -ne 'y') {
        Write-Host "Push cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Check if we need to set upstream
$needsUpstream = $false
if (-not $remoteBranchExists -or $SetUpstream) {
    $needsUpstream = $true
    Write-Host "Will set upstream tracking to $Remote/$Branch" -ForegroundColor Gray
}

# Build push command
$pushArgs = @()

if ($needsUpstream) {
    $pushArgs += '--set-upstream'
}

if ($Force) {
    Write-Warning "Using force push - this may overwrite remote changes!"
    $pushArgs += '--force'
} elseif ($ForceWithLease) {
    Write-Host "Using force-with-lease for safer force push" -ForegroundColor Gray
    $pushArgs += '--force-with-lease'
}

if ($Tags) {
    $pushArgs += '--tags'
    Write-Host "Including tags in push" -ForegroundColor Gray
}

if ($All) {
    $pushArgs += '--all'
    Write-Host "Pushing all branches" -ForegroundColor Gray
}

if ($DryRun) {
    $pushArgs += '--dry-run'
    Write-Host "[DRY RUN MODE]" -ForegroundColor Magenta
}

if ($VerbosePreference -ne 'SilentlyContinue') {
    $pushArgs += '--verbose'
}

# Add remote and branch
$pushArgs += $Remote
if (-not $All) {
    $pushArgs += $Branch
}

# Show what we're about to do
Write-Host "`nExecuting: git push $($pushArgs -join ' ')" -ForegroundColor Gray

# Execute push
try {
    $output = git push @pushArgs 2>&1

    # Parse output for important information
    $output | ForEach-Object {
        $line = $_.ToString()

        if ($line -match 'Everything up-to-date') {
            Write-Host "✓ Already up-to-date" -ForegroundColor Green
        }
        elseif ($line -match '\[new branch\]') {
            Write-Host "✓ Created new branch on remote" -ForegroundColor Green
        }
        elseif ($line -match '->') {
            Write-Host "  $line" -ForegroundColor Gray
        }
        elseif ($line -match 'rejected') {
            Write-Warning $line
        }
        elseif ($VerbosePreference -ne 'SilentlyContinue') {
            Write-Host "  $line" -ForegroundColor Gray
        }
    }

    if (-not $DryRun) {
        Write-Host "✓ Successfully pushed $Branch to $Remote" -ForegroundColor Green

        # Show remote branch info
        if ($needsUpstream) {
            Write-Host "  Branch '$Branch' set up to track '$Remote/$Branch'" -ForegroundColor Gray
        }

        # Get commit info
        $localCommit = git rev-parse HEAD 2>$null
        $remoteCommit = git rev-parse "$Remote/$Branch" 2>$null

        if ($localCommit -eq $remoteCommit -and $localCommit) {
            $shortCommit = if ($localCommit.Length -ge 7) { $localCommit.Substring(0, 7) } else { $localCommit }
            Write-Host "  Local and remote are in sync at $shortCommit" -ForegroundColor Gray
        }
    }

} catch {
    $errorMessage = $_.Exception.Message

    # Provide helpful error messages
    if ($errorMessage -match 'failed to push') {
        Write-Error "Push failed. The remote may have changes you don't have locally."
        Write-Host "Try:" -ForegroundColor Yellow
        Write-Host "  1. Pull changes: git pull" -ForegroundColor Gray
        Write-Host "  2. Resolve conflicts if any" -ForegroundColor Gray
        Write-Host "  3. Push again: az 0705" -ForegroundColor Gray

        if (-not $Force -and -not $ForceWithLease) {
            Write-Host "`nOr use -ForceWithLease for safer force push" -ForegroundColor Yellow
        }
    }
    elseif ($errorMessage -match 'Permission denied') {
        Write-Error "Authentication failed. Check your Git credentials."
        Write-Host "Try: gh auth login" -ForegroundColor Yellow
    }
    else {
        Write-Error "Failed to push: $_"
    }

    exit 1
}

# Show next steps
if (-not $DryRun) {
    Write-Host "`nNext steps:" -ForegroundColor Yellow

    if ($Branch -ne 'main' -and $Branch -ne 'master') {
        Write-Host "  Create a pull request: az 0703 -Title 'Your PR title'" -ForegroundColor Gray
    }

    # Check if there are unpushed tags
    $unpushedTags = git tag --contains HEAD --no-contains "$Remote/$Branch" 2>$null
    if ($unpushedTags -and -not $Tags) {
        Write-Host "  Push tags: az 0705 -Tags" -ForegroundColor Gray
    }
}