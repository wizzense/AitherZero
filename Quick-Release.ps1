#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Quick script to create automated releases
.DESCRIPTION
    This script automates the entire tag creation and release process
.PARAMETER Version
    Optional specific version to release (e.g., "1.0.0", "0.12.0")
.PARAMETER Type
    Version increment type: Major, Minor, or Patch (default: Patch)
.PARAMETER NoPush
    Create tag locally but don't push to remote
.EXAMPLE
    .\Quick-Release.ps1
    # Auto-increment patch version (0.11.1 -> 0.11.2)
.EXAMPLE
    .\Quick-Release.ps1 -Type Minor
    # Increment minor version (0.11.1 -> 0.12.0)
.EXAMPLE
    .\Quick-Release.ps1 -Type Major
    # Increment major version (0.11.1 -> 1.0.0)
.EXAMPLE
    .\Quick-Release.ps1 -Version "1.0.0"
    # Create specific version (v1.0.0 GA release)
.EXAMPLE
    .\Quick-Release.ps1 -Version "2.0.0-beta.1"
    # Create pre-release version
#>

param(
    [string]$Version,
    [ValidateSet('Major', 'Minor', 'Patch')]
    [string]$Type = 'Patch',
    [switch]$NoPush
)

$ErrorActionPreference = 'Stop'

Write-Host '🚀 AitherZero Automated Release Creator' -ForegroundColor Cyan
Write-Host '=====================================' -ForegroundColor Cyan

try {
    # Import PatchManager for tracking
    if (Test-Path './aither-core/modules/PatchManager/PatchManager.psm1') {
        Import-Module './aither-core/modules/PatchManager/PatchManager.psm1' -Force
        Write-Host '✓ PatchManager loaded' -ForegroundColor Green
    }

    # Determine version
    if ([string]::IsNullOrEmpty($Version)) {
        Write-Host "Determining next version using $Type increment..." -ForegroundColor Yellow

        $latestTag = git describe --tags --abbrev=0 2>$null
        if ($latestTag) {
            $currentVersion = $latestTag -replace '^v', ''
            Write-Host "Current version: $currentVersion" -ForegroundColor Cyan

            if ($currentVersion -match '^(\d+)\.(\d+)\.(\d+)') {
                $major = [int]$matches[1]
                $minor = [int]$matches[2]
                $patch = [int]$matches[3]

                switch ($Type) {
                    'Major' {
                        $Version = "$($major + 1).0.0"
                        Write-Host "🚀 Major version increment: $currentVersion → $Version" -ForegroundColor Green
                    }
                    'Minor' {
                        $Version = "$major.$($minor + 1).0"
                        Write-Host "🔧 Minor version increment: $currentVersion → $Version" -ForegroundColor Green
                    }
                    'Patch' {
                        $Version = "$major.$minor.$($patch + 1)"
                        Write-Host "🐛 Patch version increment: $currentVersion → $Version" -ForegroundColor Green
                    }
                }
            } else {
                throw "Could not parse current version: $currentVersion"
            }
        } else {
            $Version = switch ($Type) {
                'Major' { '1.0.0' }
                'Minor' { '0.1.0' }
                'Patch' { '0.0.1' }
            }
            Write-Host "No tags found, using initial $Type version: $Version" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Using specified version: $Version" -ForegroundColor Green

        # Validate version format
        if ($Version -notmatch '^(\d+)\.(\d+)\.(\d+)(-.*)?$') {
            throw "Invalid version format: $Version. Use semantic versioning (e.g., 1.0.0, 2.1.3, 1.0.0-beta.1)"
        }
    }

    $tagName = "v$Version"
    Write-Host "Target version: $Version" -ForegroundColor Green
    Write-Host "Tag name: $tagName" -ForegroundColor Green

    # Special handling for v1.0.0 GA release
    if ($Version -eq '1.0.0') {
        Write-Host '' -ForegroundColor White
        Write-Host '🎉 CREATING v1.0.0 GA RELEASE! 🎉' -ForegroundColor Magenta
        Write-Host 'This marks the first General Availability release!' -ForegroundColor Magenta
        Write-Host '' -ForegroundColor White
    }

    # Check if tag already exists
    $existingTag = git tag -l $tagName
    if ($existingTag) {
        throw "Tag $tagName already exists!"
    }

    # Create commit message for release
    $commitMsg = "Release $tagName - automated release with latest fixes"

    # Check for uncommitted changes
    $status = git status --porcelain
    if ($status) {
        Write-Host 'Found uncommitted changes, creating commit...' -ForegroundColor Yellow
        git add .
        git commit -m $commitMsg
        Write-Host '✓ Changes committed' -ForegroundColor Green
    }

    # Create and push tag
    Write-Host "Creating tag $tagName..." -ForegroundColor Yellow
    git tag $tagName -m "Automated release $tagName"

    if (-not $NoPush) {
        Write-Host 'Pushing tag to origin...' -ForegroundColor Yellow
        git push origin $tagName

        Write-Host "✅ Tag $tagName created and pushed successfully!" -ForegroundColor Green
        Write-Host '🚀 GitHub Actions will automatically create the release' -ForegroundColor Cyan
        Write-Host "📦 Release will be available at: https://github.com/wizzense/AitherZero/releases/tag/$tagName" -ForegroundColor White
    } else {
        Write-Host "✅ Tag $tagName created locally (not pushed)" -ForegroundColor Green
        Write-Host "💡 Run 'git push origin $tagName' to trigger release" -ForegroundColor Yellow
    }

} catch {
    Write-Error "Failed to create release: $($_.Exception.Message)"
    exit 1
}
