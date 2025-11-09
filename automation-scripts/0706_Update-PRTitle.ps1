#Requires -Version 7.0

<#
.SYNOPSIS
    Update pull request title with branch information
.DESCRIPTION
    Automatically updates PR titles to include source and target branch information
    in the format [source→target] to help visualize the merge direction.
    Supports ring branching strategy (dev, devstaging, main, etc.)
.PARAMETER PRNumber
    Pull request number to update
.PARAMETER Format
    Format for branch information: Arrow or Brackets
.PARAMETER DryRun
    Show what would be done without making changes
.EXAMPLE
    ./0706_Update-PRTitle.ps1 -PRNumber 123
    Updates PR #123 title with branch information
.EXAMPLE
    ./0706_Update-PRTitle.ps1 -PRNumber 123 -Format Brackets
    Updates PR #123 using [target←source] format
.NOTES
    Stage: Development
    Category: GitHub
    Dependencies: gh CLI
    Tags: pr, automation, branch, git
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [int]$PRNumber,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Arrow', 'Brackets')]
    [string]$Format = 'Arrow',

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "🔄 PR Title Updater" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan
Write-Host ""

# Function to check if gh CLI is available
function Test-GitHubCLI {
    try {
        $null = gh --version 2>&1
        return $true
    }
    catch {
        return $false
    }
}

# Function to get PR information
function Get-PRInfo {
    param([int]$Number)
    
    try {
        $prJson = gh pr view $Number --json number,title,baseRefName,headRefName 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get PR info: $prJson"
        }
        return $prJson | ConvertFrom-Json
    }
    catch {
        throw "Error getting PR #${Number}: $_"
    }
}

# Function to format branch info
function Format-BranchInfo {
    param(
        [string]$Source,
        [string]$Target,
        [string]$Format
    )
    
    switch ($Format) {
        'Arrow' {
            return "[${Source}→${Target}]"
        }
        'Brackets' {
            return "(${Target}←${Source})"
        }
        default {
            return "[${Source}→${Target}]"
        }
    }
}

# Function to update PR title
function Update-PRTitle {
    param(
        [int]$Number,
        [string]$NewTitle,
        [switch]$DryRun
    )
    
    if ($DryRun) {
        Write-Host "🔍 [DRY RUN] Would update PR #${Number} title to:" -ForegroundColor Yellow
        Write-Host "   $NewTitle" -ForegroundColor White
        return $true
    }
    
    try {
        $result = gh pr edit $Number --title $NewTitle 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to update PR title: $result"
        }
        return $true
    }
    catch {
        throw "Error updating PR #${Number}: $_"
    }
}

# Function to check if title already has branch info
function Test-HasBranchInfo {
    param([string]$Title)
    
    # Check for patterns: [xxx→yyy], (yyy←xxx), [xxx->yyy], (yyy<-xxx)
    return ($Title -match '^\[.+?[→->].+?\]' -or $Title -match '^\(.+?[←<-].+?\)')
}

# Function to remove existing branch info from title
function Remove-BranchInfo {
    param([string]$Title)
    
    # Remove patterns: [xxx→yyy], (yyy←xxx), [xxx->yyy], (yyy<-xxx) from start of title
    $cleanTitle = $Title -replace '^\[.+?[→->].+?\]\s*', ''
    $cleanTitle = $cleanTitle -replace '^\(.+?[←<-].+?\)\s*', ''
    return $cleanTitle.Trim()
}

# Main script logic
try {
    # Check for gh CLI
    if (-not (Test-GitHubCLI)) {
        Write-Error "GitHub CLI (gh) is not available. Please install it first."
        exit 1
    }

    # Check if we're authenticated
    try {
        $null = gh auth status 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Not authenticated with GitHub CLI. Run 'gh auth login' first."
            exit 1
        }
    }
    catch {
        Write-Error "Not authenticated with GitHub CLI. Run 'gh auth login' first."
        exit 1
    }

    # If no PR number provided, try to get current PR
    if (-not $PRNumber) {
        Write-Host "📍 No PR number provided, attempting to detect current PR..." -ForegroundColor Yellow
        
        # Check if we're in a git repository
        $gitBranch = git rev-parse --abbrev-ref HEAD 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Not in a git repository. Please provide -PRNumber parameter."
            exit 1
        }
        
        # Try to find PR for current branch
        $prList = gh pr list --head $gitBranch --json number --limit 1 2>&1
        if ($LASTEXITCODE -eq 0 -and $prList) {
            $prData = $prList | ConvertFrom-Json
            if ($prData -and $prData.Count -gt 0) {
                $PRNumber = $prData[0].number
                Write-Host "✓ Found PR #$PRNumber for branch '$gitBranch'" -ForegroundColor Green
            }
            else {
                Write-Error "No open PR found for branch '$gitBranch'. Please provide -PRNumber parameter."
                exit 1
            }
        }
        else {
            Write-Error "Could not detect PR for current branch. Please provide -PRNumber parameter."
            exit 1
        }
    }

    # Get PR information
    Write-Host "📥 Fetching PR #$PRNumber information..." -ForegroundColor Cyan
    $pr = Get-PRInfo -Number $PRNumber
    
    Write-Host "   Title: $($pr.title)" -ForegroundColor Gray
    Write-Host "   Base: $($pr.baseRefName)" -ForegroundColor Gray
    Write-Host "   Head: $($pr.headRefName)" -ForegroundColor Gray
    Write-Host ""

    # Check if title already has branch info
    $hasInfo = Test-HasBranchInfo -Title $pr.title
    
    # Remove any existing branch info
    $cleanTitle = Remove-BranchInfo -Title $pr.title
    
    # Format branch info
    $branchInfo = Format-BranchInfo -Source $pr.headRefName -Target $pr.baseRefName -Format $Format
    
    # Create new title
    $newTitle = "$branchInfo $cleanTitle"
    
    # Check if update is needed
    if ($pr.title -eq $newTitle) {
        Write-Host "✓ PR title already has correct branch information" -ForegroundColor Green
        Write-Host "   $newTitle" -ForegroundColor White
        exit 0
    }
    
    # Update PR title
    Write-Host "📝 Updating PR title..." -ForegroundColor Cyan
    
    if ($hasInfo) {
        Write-Host "   Replacing existing branch info" -ForegroundColor Yellow
    }
    else {
        Write-Host "   Adding branch info" -ForegroundColor Yellow
    }
    
    $updated = Update-PRTitle -Number $PRNumber -NewTitle $newTitle -DryRun:$DryRun
    
    if ($updated -and -not $DryRun) {
        Write-Host ""
        Write-Host "✓ Successfully updated PR #$PRNumber" -ForegroundColor Green
        Write-Host "   Old: $($pr.title)" -ForegroundColor Gray
        Write-Host "   New: $newTitle" -ForegroundColor White
    }
    
    exit 0
}
catch {
    Write-Host ""
    Write-Host "❌ Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    exit 1
}
