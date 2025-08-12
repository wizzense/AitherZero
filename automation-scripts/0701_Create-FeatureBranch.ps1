#Requires -Version 7.0

<#
.SYNOPSIS
    Create a feature branch with conventional naming
.DESCRIPTION
    Creates a new feature branch following project conventions and optionally
    creates an associated GitHub issue.
.NOTES
    Stage: Development
    Category: Git
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('feature', 'fix', 'docs', 'refactor', 'test', 'chore')]
    [string]$Type,
    
    [Parameter(Mandatory)]
    [string]$Name,
    
    [string]$Description,
    
    [switch]$CreateIssue,
    
    [string[]]$Labels,
    
    [switch]$Checkout,
    
    [switch]$Push,
    
    [switch]$Force,
    
    [switch]$NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import development modules
$devModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/development"
Import-Module (Join-Path $devModulePath "GitAutomation.psm1") -Force
Import-Module (Join-Path $devModulePath "IssueTracker.psm1") -Force

Write-Host "Creating $Type branch..." -ForegroundColor Cyan

# Normalize name for branch
$normalizedName = $Name -replace '\s+', '-' -replace '[^a-zA-Z0-9-]', '' -replace '--+', '-'
$branchName = "$Type/$normalizedName"

# Check if we're on a clean state
$status = Get-GitStatus
if (-not $status.Clean -and -not $Force -and -not $NonInteractive) {
    Write-Warning "You have uncommitted changes. Please commit or stash them first."
    Write-Host "Changed files:" -ForegroundColor Yellow
    $status.Modified + $status.Staged | ForEach-Object { Write-Host "  $($_.Path)" }
    
    $response = Read-Host "Continue anyway? (y/N)"
    if ($response -ne 'y') {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 0
    }
} elseif (-not $status.Clean) {
    Write-Warning "Uncommitted changes detected. Proceeding due to Force/NonInteractive mode."
}

# Default to checkout unless explicitly disabled
if ($PSBoundParameters.ContainsKey('Checkout')) {
    $doCheckout = $Checkout
} else {
    $doCheckout = $true
}

# Check if branch already exists
$existingBranch = git branch --list $branchName 2>$null
$remoteBranch = git branch -r --list "origin/$branchName" 2>$null

if ($existingBranch -or $remoteBranch) {
    Write-Host "Branch '$branchName' already exists" -ForegroundColor Yellow
    
    # Get branch conflict resolution preference from config or parameters
    $conflictResolution = if ($Force) { 
        'checkout' 
    } elseif ($NonInteractive) {
        # In non-interactive mode, check config for preference
        $config = if (Get-Command Get-AitherConfiguration -ErrorAction SilentlyContinue) {
            Get-AitherConfiguration
        } else {
            @{}
        }
        $config.Development?.GitAutomation?.BranchConflictResolution ?? 'checkout'
    } else {
        # Interactive mode - ask user
        Write-Host "How would you like to handle this?" -ForegroundColor Yellow
        Write-Host "  1. Checkout existing branch"
        Write-Host "  2. Create new branch with suffix (e.g., -2)"
        Write-Host "  3. Delete and recreate branch"
        Write-Host "  4. Abort"
        
        $choice = Read-Host "Choose option (1-4)"
        switch ($choice) {
            '1' { 'checkout' }
            '2' { 'suffix' }
            '3' { 'recreate' }
            '4' { 'abort' }
            default { 'abort' }
        }
    }
    
    switch ($conflictResolution) {
        'checkout' {
            Write-Host "Checking out existing branch..." -ForegroundColor Cyan
            git checkout $branchName 2>$null
            
            # Pull latest if remote exists
            if ($remoteBranch) {
                Write-Host "Pulling latest changes..." -ForegroundColor Cyan
                git pull origin $branchName 2>$null
            }
            
            Write-Host "✓ Using existing branch: $branchName" -ForegroundColor Green
        }
        'suffix' {
            # Find next available suffix
            $suffix = 2
            while ($true) {
                $newBranchName = "$branchName-$suffix"
                $exists = git branch --list $newBranchName 2>$null
                if (-not $exists) {
                    $branchName = $newBranchName
                    break
                }
                $suffix++
                if ($suffix -gt 99) {
                    Write-Error "Could not find available branch name"
                    exit 1
                }
            }
            
            Write-Host "Creating new branch: $branchName" -ForegroundColor Cyan
            if ($PSCmdlet.ShouldProcess($branchName, "Create new Git branch")) {
                $result = New-GitBranch -Name $branchName -Checkout:$doCheckout -Push:$Push
                Write-Host "✓ Created branch: $branchName" -ForegroundColor Green
            }
        }
        'recreate' {
            Write-Host "Deleting existing branch..." -ForegroundColor Yellow
            
            # Switch to main/master first if we're on the branch to delete
            $currentBranch = git rev-parse --abbrev-ref HEAD 2>$null
            if ($currentBranch -eq $branchName) {
                git checkout main 2>$null || git checkout master 2>$null
            }
            
            # Delete local branch
            git branch -D $branchName 2>$null
            
            # Delete remote branch if exists
            if ($remoteBranch) {
                git push origin --delete $branchName 2>$null
            }
            
            # Create fresh branch
            if ($PSCmdlet.ShouldProcess($branchName, "Recreate Git branch")) {
                $result = New-GitBranch -Name $branchName -Checkout:$doCheckout -Push:$Push
                Write-Host "✓ Recreated branch: $branchName" -ForegroundColor Green
            }
        }
        'abort' {
            Write-Host "Branch creation aborted" -ForegroundColor Yellow
            exit 0
        }
        default {
            # Default to checkout for backward compatibility
            git checkout $branchName 2>$null
            Write-Host "✓ Using existing branch: $branchName" -ForegroundColor Green
        }
    }
} else {
    # Branch doesn't exist, create it normally
    try {
        if ($PSCmdlet.ShouldProcess($branchName, "Create Git branch")) {
            $result = New-GitBranch -Name $branchName -Checkout:$doCheckout -Push:$Push
            Write-Host "✓ Created branch: $branchName" -ForegroundColor Green
        }
    } catch {
        Write-Error "Failed to create branch: $_"
        exit 1
    }
}

# Create GitHub issue if requested
$issueNumber = $null
if ($CreateIssue) {
    Write-Host "Creating GitHub issue..." -ForegroundColor Yellow

    # Build issue title
    $issueTitle = switch ($Type) {
        'feature' { "Feature: $Name" }
        'fix' { "Bug: $Name" }
        'docs' { "Documentation: $Name" }
        'refactor' { "Refactor: $Name" }
        'test' { "Test: $Name" }
        'chore' { "Chore: $Name" }
    }

    # Build issue body
    $issueBody = @"
## Description
$($Description ?? "TODO: Add description")

## Branch
\`$branchName\`

## Tasks
- [ ] Implementation
- [ ] Tests
- [ ] Documentation
- [ ] Review

## Acceptance Criteria
TODO: Define acceptance criteria
"@

    # Add default labels based on type
    $defaultLabels = @($Type)
    if ($Labels) {
        $defaultLabels += $Labels
    }
    
    try {
        if ($PSCmdlet.ShouldProcess("GitHub issue", "Create issue for $issueTitle")) {
            $issue = New-GitHubIssue -Title $issueTitle -Body $issueBody -Labels $defaultLabels
            $issueNumber = $issue.Number
            Write-Host "✓ Created issue #$issueNumber" -ForegroundColor Green
            Write-Host "  URL: $($issue.Url)" -ForegroundColor Gray
        }
    } catch {
        Write-Warning "Failed to create issue: $_"
    }
}

# Create initial commit if on new branch
if ($doCheckout) {
    $readmePath = "README-$Type.md"
    $readmeContent = @"
# $Name

## Overview
$($Description ?? "TODO: Add description")

$(if ($issueNumber) { "## Related Issue`nResolves #$issueNumber" })

## Implementation Notes
TODO: Add implementation notes

## Testing
TODO: Describe testing approach
"@
    
    if ($PSCmdlet.ShouldProcess($readmePath, "Create initial README and commit")) {
        $readmeContent | Set-Content $readmePath

        # Stage and commit
        git add $readmePath
    
    # Map branch type to commit type
    $commitType = switch ($Type) {
        'feature' { 'feat' }
        'fix' { 'fix' }
        'docs' { 'docs' }
        'refactor' { 'refactor' }
        'test' { 'test' }
        'chore' { 'chore' }
        default { 'feat' }
    }
    
    $commitMessage = "Initial commit for $Name"
    if ($issueNumber) {
        $commitMessage += "`n`nRefs #$issueNumber"
    }
    
        Invoke-GitCommit -Message $commitMessage -Type $commitType -Scope "init"
        Write-Host "✓ Created initial commit" -ForegroundColor Green

        if ($Push) {
            Sync-GitRepository -Operation Push
            Write-Host "✓ Pushed branch to remote" -ForegroundColor Green
        }
    }
}

# Summary
Write-Host "`nFeature branch created successfully!" -ForegroundColor Green
Write-Host "  Branch: $branchName" -ForegroundColor Cyan
if ($issueNumber) {
    Write-Host "  Issue: #$issueNumber" -ForegroundColor Cyan
}

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "  1. Implement your changes"
Write-Host "  2. Run tests: az 0402"
Write-Host "  3. Create PR: az 0703 -Title '$Name'"