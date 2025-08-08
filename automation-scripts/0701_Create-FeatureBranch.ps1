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

[CmdletBinding()]
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
    
    [switch]$Push
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
if (-not $status.Clean) {
    Write-Warning "You have uncommitted changes. Please commit or stash them first."
    Write-Host "Changed files:" -ForegroundColor Yellow
    $status.Modified + $status.Staged | ForEach-Object { Write-Host "  $($_.Path)" }
    
    $response = Read-Host "Continue anyway? (y/N)"
    if ($response -ne 'y') {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 0
    }
}

# Default to checkout unless explicitly disabled
if ($PSBoundParameters.ContainsKey('Checkout')) {
    $doCheckout = $Checkout
} else {
    $doCheckout = $true
}

# Create the branch
try {
    $result = New-GitBranch -Name $branchName -Checkout:$doCheckout -Push:$Push
    Write-Host "✓ Created branch: $branchName" -ForegroundColor Green
} catch {
    Write-Error "Failed to create branch: $_"
    exit 1
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
        $issue = New-GitHubIssue -Title $issueTitle -Body $issueBody -Labels $defaultLabels
        $issueNumber = $issue.Number
        Write-Host "✓ Created issue #$issueNumber" -ForegroundColor Green
        Write-Host "  URL: $($issue.Url)" -ForegroundColor Gray
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
    
    $readmeContent | Set-Content $readmePath

    # Stage and commit
    git add $readmePath
    
    $commitMessage = "${Type}: Initial commit for $Name"
    if ($issueNumber) {
        $commitMessage += "`n`nRefs #$issueNumber"
    }
    
    Invoke-GitCommit -Message $commitMessage -Type $Type -Scope "init"
    Write-Host "✓ Created initial commit" -ForegroundColor Green

    if ($Push) {
        Sync-GitRepository -Operation Push
        Write-Host "✓ Pushed branch to remote" -ForegroundColor Green
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