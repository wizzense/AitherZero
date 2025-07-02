#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates a release tag after PR merge
.DESCRIPTION
    This script automates the release tag creation process after a PR has been merged.
    It pulls the latest main branch and creates/pushes the release tag.
.PARAMETER Version
    The version to tag (e.g., "1.4.2"). If not provided, reads from VERSION file.
.PARAMETER Message
    Custom tag message. If not provided, uses a standard format.
.EXAMPLE
    ./create-release-tag.ps1
    Creates tag using VERSION file
.EXAMPLE
    ./create-release-tag.ps1 -Version "1.4.3" -Message "Custom release notes"
    Creates tag with specific version and message
#>

[CmdletBinding()]
param(
    [string]$Version,
    [string]$Message
)

$ErrorActionPreference = 'Stop'

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    Write-Host $Message -ForegroundColor $Color
}

try {
    Write-ColorOutput "🚀 AitherZero Release Tag Creator" -Color 'Cyan'
    Write-ColorOutput "=================================" -Color 'Cyan'
    
    # Get project root
    $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    Set-Location $projectRoot
    
    # Check if we're in a git repository
    if (-not (Test-Path ".git")) {
        throw "Not in a git repository! Please run from AitherZero root."
    }
    
    # Get current branch
    $currentBranch = git branch --show-current
    Write-ColorOutput "Current branch: $currentBranch" -Color 'Yellow'
    
    # Checkout main and pull latest
    Write-ColorOutput "`nStep 1: Switching to main branch..." -Color 'Green'
    git checkout main
    
    Write-ColorOutput "Step 2: Pulling latest changes..." -Color 'Green'
    git pull origin main
    
    # Get version
    if (-not $Version) {
        $versionFile = Join-Path $projectRoot "VERSION"
        if (Test-Path $versionFile) {
            $Version = (Get-Content $versionFile -Raw).Trim()
            Write-ColorOutput "Step 3: Using version from VERSION file: $Version" -Color 'Green'
        } else {
            throw "VERSION file not found and no version specified!"
        }
    } else {
        Write-ColorOutput "Step 3: Using specified version: $Version" -Color 'Green'
    }
    
    # Check if tag already exists
    $existingTag = git tag -l "v$Version"
    if ($existingTag) {
        Write-ColorOutput "`n⚠️  Tag v$Version already exists!" -Color 'Yellow'
        $overwrite = Read-Host "Do you want to delete and recreate it? (y/N)"
        if ($overwrite -eq 'y') {
            Write-ColorOutput "Deleting existing tag..." -Color 'Yellow'
            git tag -d "v$Version"
            git push origin --delete "v$Version" 2>$null
        } else {
            Write-ColorOutput "Aborted." -Color 'Red'
            exit 1
        }
    }
    
    # Create tag message
    if (-not $Message) {
        # Try to read release notes
        $releaseNotesFile = Join-Path $projectRoot "RELEASE-NOTES-v$Version.md"
        if (Test-Path $releaseNotesFile) {
            Write-ColorOutput "Step 4: Found release notes file" -Color 'Green'
            $releaseNotes = Get-Content $releaseNotesFile -Raw
            # Extract summary from release notes
            if ($releaseNotes -match '##\s*🚀\s*(.+)') {
                $summary = $matches[1].Trim()
            } else {
                $summary = "Release v$Version"
            }
        } else {
            $summary = "Release v$Version"
        }
        
        $Message = @"
Release v$Version

$summary

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
"@
    }
    
    # Create and push tag
    Write-ColorOutput "`nStep 5: Creating tag v$Version..." -Color 'Green'
    git tag -a "v$Version" -m $Message
    
    Write-ColorOutput "Step 6: Pushing tag to origin..." -Color 'Green'
    git push origin "v$Version"
    
    Write-ColorOutput "`n✅ Success! Tag v$Version created and pushed." -Color 'Green'
    Write-ColorOutput "`nGitHub Actions will now:" -Color 'Yellow'
    Write-ColorOutput "  • Trigger the Build & Release Pipeline" -Color 'White'
    Write-ColorOutput "  • Build packages for all platforms" -Color 'White'
    Write-ColorOutput "  • Create GitHub release with artifacts" -Color 'White'
    
    Write-ColorOutput "`nMonitor the build at:" -Color 'Cyan'
    Write-ColorOutput "  https://github.com/wizzense/AitherZero/actions" -Color 'White'
    
    # Return to original branch
    if ($currentBranch -ne 'main') {
        Write-ColorOutput "`nReturning to branch: $currentBranch" -Color 'Yellow'
        git checkout $currentBranch
    }
    
} catch {
    Write-ColorOutput "`n❌ Error: $_" -Color 'Red'
    exit 1
}