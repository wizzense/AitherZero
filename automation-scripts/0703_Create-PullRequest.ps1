#Requires -Version 7.0

<#
.SYNOPSIS
    Create a pull request with templates and automation
.DESCRIPTION
    Creates a GitHub pull request with automatic template selection,
    reviewers assignment, and optional auto-merge.
.NOTES
    Stage: Development
    Category: GitHub
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$Title,
    
    [string]$Body,
    
    [string]$Base,
    
    [ValidateSet('feature', 'bugfix', 'hotfix', 'docs', 'refactor')]
    [string]$Template,
    
    [string[]]$Reviewers,
    
    [string[]]$Assignees,
    
    [string[]]$Labels,
    
    [switch]$Draft,
    
    [switch]$AutoMerge,
    
    [ValidateSet('merge', 'squash', 'rebase')]
    [string]$MergeMethod = 'squash',
    
    [switch]$LinkIssue,
    
    [int[]]$Closes,
    
    [switch]$RunChecks,
    
    [switch]$OpenInBrowser,
    
    [switch]$NonInteractive,
    
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import modules
$devModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/development"
Import-Module (Join-Path $devModulePath "GitAutomation.psm1") -Force
Import-Module (Join-Path $devModulePath "PullRequestManager.psm1") -Force
Import-Module (Join-Path $devModulePath "IssueTracker.psm1") -Force

Write-Host "Creating pull request..." -ForegroundColor Cyan

# Check GitHub CLI
try {
    Test-GitHubCLI
} catch {
    Write-Error "GitHub CLI not available: $_"
    exit 1
}

# Get current branch and repository info
$gitStatus = Get-GitStatus
$gitRepo = Get-GitRepository

if (-not $gitStatus.Branch -or $gitStatus.Branch -eq 'main' -or $gitStatus.Branch -eq 'master') {
    Write-Error "Cannot create PR from default branch. Create a feature branch first."
    exit 1
}

# Check for uncommitted changes
if (-not $gitStatus.Clean) {
    if (-not $NonInteractive -and -not $Force) {
        Write-Warning "You have uncommitted changes:"
        $gitStatus.Modified + $gitStatus.Untracked | ForEach-Object { 
            Write-Host "  $($_.Path)" -ForegroundColor Yellow
        }
        
        $response = Read-Host "Continue without committing? (y/N)"
        if ($response -ne 'y') {
            Write-Host "Commit your changes first with: az 0702" -ForegroundColor Yellow
            exit 0
        }
    } else {
        Write-Warning "Uncommitted changes detected. Proceeding in non-interactive mode."
    }
}

# Push current branch if needed
if ($gitStatus.Ahead -gt 0 -or -not $gitStatus.UpstreamBranch) {
    Write-Host "Pushing branch to remote..." -ForegroundColor Yellow
    Sync-GitRepository -Operation Push
}

# Analyze open issues for automatic linkage
Write-Host "Analyzing related issues..." -ForegroundColor Yellow
$issueAnalysis = & (Join-Path $PSScriptRoot "0805_Analyze-OpenIssues.ps1") -Branch $gitStatus.Branch

# Prepare PR body
if (-not $Body) {
    # Try to use template
    $templatePath = $null
    if ($Template) {
        $templatePath = Join-Path (Split-Path $PSScriptRoot -Parent) ".github/PULL_REQUEST_TEMPLATE/$Template.md"
    }

    if (-not $templatePath -or -not (Test-Path $templatePath)) {
        $templatePath = Join-Path (Split-Path $PSScriptRoot -Parent) ".github/pull_request_template.md"
    }

    if (Test-Path $templatePath) {
        $Body = Get-Content $templatePath -Raw
        Write-Host "Using PR template: $(Split-Path $templatePath -Leaf)" -ForegroundColor Gray
    } else {
        # Default template
        $Body = @"
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] My code follows the style guidelines of this project
- [ ] I have performed a self-review of my code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
"@
    }
}

# Add automatic issue references
if ($issueAnalysis -and $issueAnalysis.PRBodySection) {
    Write-Host "Found $($issueAnalysis.MatchedIssues.Count) related issues" -ForegroundColor Green
    $Body += "`n`n$($issueAnalysis.PRBodySection)"
} elseif ($Closes) {
    # Manual issue references
    $Body += "`n`n## Related Issues`n"
    $Body += $Closes | ForEach-Object { "Closes #$_" } | Join-String -Separator "`n"
}

# Auto-detect labels from branch name
if (-not $Labels) {
    $Labels = @()
    if ($gitStatus.Branch -match '^(feature|feat)/') { $Labels += 'enhancement' }
    elseif ($gitStatus.Branch -match '^fix/') { $Labels += 'bug' }
    elseif ($gitStatus.Branch -match '^docs/') { $Labels += 'documentation' }
    elseif ($gitStatus.Branch -match '^test/') { $Labels += 'testing' }
    elseif ($gitStatus.Branch -match '^refactor/') { $Labels += 'refactoring' }
}

# Create the PR
try {
    $prParams = @{
        Title = $Title
        Body = $Body
        Head = $gitStatus.Branch
        Draft = $Draft
        OpenInBrowser = $OpenInBrowser
    }

    if ($Base) {
        $prParams.Base = $Base
    }

    if ($Reviewers) {
        $prParams.Reviewers = $Reviewers
    }

    if ($Assignees) {
        $prParams.Assignees = $Assignees
    } else {
        # Auto-assign to current user
        $currentUser = gh api user --jq '.login' 2>$null
        if ($currentUser) {
            $prParams.Assignees = @($currentUser)
        }
    }

    if ($Labels) {
        $prParams.Labels = $Labels
    }

    if ($AutoMerge -and -not $Draft) {
        $prParams.AutoMerge = $true
    }
    
    $pr = New-PullRequest @prParams
    
    Write-Host "✓ Created pull request #$($pr.Number)" -ForegroundColor Green
    Write-Host "  Title: $Title" -ForegroundColor Gray
    Write-Host "  URL: $($pr.Url)" -ForegroundColor Gray
    
} catch {
    Write-Error "Failed to create pull request: $_"
    exit 1
}

# Run checks if requested
if ($RunChecks -and -not $Draft) {
    Write-Host "`nRunning checks..." -ForegroundColor Yellow

    # Run tests
    & (Join-Path $PSScriptRoot "0402_Run-UnitTests.ps1") -QuietMode

    # Run linting
    & (Join-Path $PSScriptRoot "0404_Run-PSScriptAnalyzer.ps1") -Fix:$false
    
    Write-Host "✓ Checks completed" -ForegroundColor Green
}

# Link to issue if requested
if ($LinkIssue) {
    $issueNumber = $null

    # Try to extract from branch name
    if ($gitStatus.Branch -match '/(\d+)-') {
        $issueNumber = $Matches[1]
    }

    if ($issueNumber) {
        Write-Host "Linking to issue #$issueNumber..." -ForegroundColor Yellow
        Add-GitHubIssueComment -Number $issueNumber -Body "PR #$($pr.Number) has been created to address this issue."
        Write-Host "✓ Linked to issue #$issueNumber" -ForegroundColor Green
    }
}

# Summary
Write-Host "`nPull request created successfully!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "  1. Wait for CI checks to pass"
Write-Host "  2. Request reviews if needed"
Write-Host "  3. Address any feedback"
if ($AutoMerge) {
    Write-Host "  4. PR will auto-merge when approved and checks pass" -ForegroundColor Cyan
} else {
    Write-Host "  4. Merge when ready"
}