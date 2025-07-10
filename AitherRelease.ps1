#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    AitherZero Release Automation Script - THE ONE AND ONLY RELEASE COMMAND

.DESCRIPTION
    This is the unified release automation script for AitherZero. It provides a simple, 
    painless interface for creating releases with full automation:
    
    1. Creates a PR to update VERSION (respects branch protection)
    2. Waits for CI checks to pass
    3. Auto-merges the PR
    4. Monitors release workflow
    5. Reports when release is published
    
    No manual steps, no confusion, works every time!

.PARAMETER Version
    The version number for the release (e.g., "1.2.3")

.PARAMETER Message
    The release message/description

.PARAMETER Type
    Auto-increment version type: patch, minor, major

.PARAMETER DryRun
    Preview what would happen without making changes

.EXAMPLE
    ./AitherRelease.ps1 -Version "1.2.3" -Message "Bug fixes"
    # Creates release v1.2.3 with description

.EXAMPLE
    ./AitherRelease.ps1 -Type patch -Message "Bug fixes"
    # Auto-increments patch version (1.2.3 -> 1.2.4)

.EXAMPLE
    ./AitherRelease.ps1 -Type minor -Message "New features"
    # Auto-increments minor version (1.2.3 -> 1.3.0)

.EXAMPLE
    ./AitherRelease.ps1 -Type major -Message "Breaking changes"
    # Auto-increments major version (1.2.3 -> 2.0.0)

.EXAMPLE
    ./AitherRelease.ps1 -Version "1.2.3" -Message "Test release" -DryRun
    # Preview mode - shows what would happen

.NOTES
    This script is part of AitherZero's automated release system.
    It uses PatchManager for all Git operations and GitHub API integration.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, ParameterSetName = "Version")]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,

    [Parameter(Mandatory = $false, ParameterSetName = "Type")]
    [ValidateSet('patch', 'minor', 'major')]
    [string]$Type,

    [Parameter(Mandatory = $true)]
    [string]$Message,

    [switch]$DryRun
)

# Error handling
$ErrorActionPreference = 'Stop'

# Get project root
$projectRoot = $PSScriptRoot
if (-not $projectRoot) {
    $projectRoot = Get-Location
}

# Banner
function Show-ReleaseBanner {
    Write-Host ""
    Write-Host "    ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "    ║              AitherZero Release Automation                   ║" -ForegroundColor Magenta
    Write-Host "    ║                PAINLESS & AUTOMATED                          ║" -ForegroundColor Magenta
    Write-Host "    ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host ""
}

# Version calculation
function Get-NextVersion {
    param(
        [string]$CurrentVersion,
        [string]$Type
    )
    
    if (-not $CurrentVersion -or $CurrentVersion -eq "0.0.0") {
        $CurrentVersion = "0.1.0"
    }
    
    $parts = $CurrentVersion.Split('.')
    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    $patch = [int]$parts[2]
    
    switch ($Type) {
        'patch' { $patch++ }
        'minor' { $minor++; $patch = 0 }
        'major' { $major++; $minor = 0; $patch = 0 }
    }
    
    return "$major.$minor.$patch"
}

# Main execution
try {
    Show-ReleaseBanner
    
    # Import PatchManager
    $patchManagerPath = Join-Path $projectRoot "aither-core/modules/PatchManager"
    if (-not (Test-Path $patchManagerPath)) {
        throw "PatchManager module not found at: $patchManagerPath"
    }
    
    Write-Host "📦 Loading PatchManager..." -ForegroundColor Yellow
    Import-Module $patchManagerPath -Force
    
    # Determine version
    $targetVersion = $Version
    if ($Type) {
        $versionFile = Join-Path $projectRoot "VERSION"
        $currentVersion = if (Test-Path $versionFile) { 
            (Get-Content $versionFile -Raw).Trim() 
        } else { 
            "0.0.0" 
        }
        $targetVersion = Get-NextVersion -CurrentVersion $currentVersion -Type $Type
        Write-Host "📊 Auto-incrementing version: $currentVersion → $targetVersion" -ForegroundColor Cyan
    }
    
    if (-not $targetVersion) {
        throw "Version must be specified with -Version or -Type parameter"
    }
    
    # Validate version format
    if ($targetVersion -notmatch '^\d+\.\d+\.\d+$') {
        throw "Invalid version format: $targetVersion. Use semantic versioning (e.g., 1.2.3)"
    }
    
    Write-Host "🚀 Initiating release process..." -ForegroundColor Green
    Write-Host "   Version: $targetVersion" -ForegroundColor White
    Write-Host "   Message: $Message" -ForegroundColor White
    
    if ($DryRun) {
        Write-Host "   Mode: DRY RUN (preview only)" -ForegroundColor Yellow
    } else {
        Write-Host "   Mode: LIVE (will create release)" -ForegroundColor Green
    }
    
    Write-Host ""
    
    # Execute release
    if ($DryRun) {
        Write-Host "🔍 DRY RUN MODE - What would happen:" -ForegroundColor Yellow
        Write-Host "   1. Create release branch: release/v$targetVersion" -ForegroundColor White
        Write-Host "   2. Update VERSION file to: $targetVersion" -ForegroundColor White
        Write-Host "   3. Commit changes with message: $Message" -ForegroundColor White
        Write-Host "   4. Push branch and create PR" -ForegroundColor White
        Write-Host "   5. Enable auto-merge on PR" -ForegroundColor White
        Write-Host "   6. Monitor CI and release workflow" -ForegroundColor White
        Write-Host ""
        Write-Host "✅ DRY RUN COMPLETED - No changes made" -ForegroundColor Green
    } else {
        $releaseResult = New-Release -Version $targetVersion -Message $Message
        
        if ($releaseResult.Success) {
            Write-Host ""
            Write-Host "🎉 RELEASE INITIATED SUCCESSFULLY!" -ForegroundColor Green
            Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
            Write-Host ""
            Write-Host "📋 What happens next (fully automated):" -ForegroundColor Cyan
            Write-Host "   1. ✅ Release PR created" -ForegroundColor Green
            Write-Host "   2. ⏳ CI checks will run" -ForegroundColor Yellow
            Write-Host "   3. 🤖 PR will auto-merge when checks pass" -ForegroundColor Yellow
            Write-Host "   4. 🏗️  Release workflow will build packages" -ForegroundColor Yellow
            Write-Host "   5. 📦 GitHub release will be published" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "🔗 Track progress at:" -ForegroundColor Cyan
            Write-Host "   PR: $($releaseResult.PullRequestUrl)" -ForegroundColor Blue
            Write-Host "   Actions: https://github.com/$(gh repo view --json owner,name -q '.owner.login + \"/\" + .name')/actions" -ForegroundColor Blue
            Write-Host ""
            Write-Host "⏱️  Estimated completion: 5-10 minutes" -ForegroundColor Gray
            Write-Host ""
            Write-Host "💡 Tip: Use 'gh run watch' to monitor the release workflow" -ForegroundColor Gray
        } else {
            throw "Release failed: $($releaseResult.Message)"
        }
    }
    
} catch {
    Write-Host ""
    Write-Host "❌ RELEASE FAILED" -ForegroundColor Red
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 Common solutions:" -ForegroundColor Yellow
    Write-Host "   • Ensure you're on the main branch" -ForegroundColor White
    Write-Host "   • Check that the version doesn't already exist" -ForegroundColor White
    Write-Host "   • Verify GitHub CLI is authenticated (gh auth status)" -ForegroundColor White
    Write-Host "   • Ensure no uncommitted changes exist" -ForegroundColor White
    Write-Host ""
    exit 1
}