#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Emergency script to manually trigger v1.4.0 release by creating and pushing the tag.

.DESCRIPTION
    This script manually creates and pushes the v1.4.0 release tag to trigger the GitHub Actions
    build-release.yml workflow. Use this when the automatic tag creation from VERSION file changes
    is not working.

.PARAMETER DryRun
    Show what would be done without actually executing git commands.

.PARAMETER Force
    Force push the tag even if it already exists locally or remotely.

.EXAMPLE
    ./Force-v1.4.0-Release.ps1
    Create and push the v1.4.0 tag normally.

.EXAMPLE
    ./Force-v1.4.0-Release.ps1 -DryRun
    Show what would be done without executing commands.

.EXAMPLE
    ./Force-v1.4.0-Release.ps1 -Force
    Force create and push the tag even if it exists.

.NOTES
    This script will:
    1. Read the VERSION file to get the current version (should be 1.4.0)
    2. Check if the tag already exists locally and remotely
    3. Create git tag v1.4.0 with proper release message
    4. Push the tag to origin
    5. This triggers the GitHub Actions build-release.yml workflow

    The build-release.yml workflow has these triggers:
    - push: tags: v*
    - This script leverages that trigger mechanism
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Force
)

# Set error handling
$ErrorActionPreference = 'Stop'
$VerbosePreference = if ($PSBoundParameters.ContainsKey('Verbose')) { 'Continue' } else { 'SilentlyContinue' }

# Initialize logging
function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'SUCCESS' { 'Green' }
        'WARNING' { 'Yellow' }
        'ERROR' { 'Red' }
        'DEBUG' { 'Cyan' }
        default { 'White' }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-GitCommand {
    try {
        $null = git --version 2>$null
        return $true
    } catch {
        return $false
    }
}

function Test-GitRepository {
    try {
        $null = git rev-parse --git-dir 2>$null
        return $true
    } catch {
        return $false
    }
}

function Get-ProjectVersion {
    $versionFile = Join-Path $PSScriptRoot "VERSION"
    if (-not (Test-Path $versionFile)) {
        throw "VERSION file not found at: $versionFile"
    }
    
    $version = Get-Content $versionFile -Raw
    if ([string]::IsNullOrWhiteSpace($version)) {
        throw "VERSION file is empty or contains only whitespace"
    }
    
    return $version.Trim()
}

function Test-TagExists {
    param([string]$TagName)
    
    # Check if tag exists locally
    try {
        $null = git rev-parse "refs/tags/$TagName" 2>$null
        $localExists = $true
    } catch {
        $localExists = $false
    }
    
    # Check if tag exists on remote
    try {
        git fetch origin "refs/tags/${TagName}:refs/tags/${TagName}" 2>$null
        $remoteExists = $true
    } catch {
        $remoteExists = $false
    }
    
    return @{
        Local = $localExists
        Remote = $remoteExists
    }
}

function New-ReleaseTag {
    param(
        [string]$Version,
        [string]$TagName,
        [switch]$Force,
        [switch]$DryRun
    )
    
    Write-Log "Creating release tag: $TagName" -Level 'INFO'
    
    # Get the latest commit message for the tag message
    try {
        $commitMsg = git log -1 --pretty=format:"%s" 2>$null
        if ([string]::IsNullOrWhiteSpace($commitMsg)) {
            $commitMsg = "Release v$Version"
        }
    } catch {
        $commitMsg = "Release v$Version"
        Write-Log "Could not get latest commit message, using default" -Level 'WARNING'
    }
    
    $tagMessage = "Release v$Version`n`n$commitMsg`n`nManually triggered release tag creation to initiate build pipeline."
    
    # Create the tag
    $createArgs = @('tag', '-a', $TagName, '-m', $tagMessage)
    if ($Force) {
        $createArgs += '--force'
    }
    
    if ($DryRun) {
        Write-Log "DRY RUN: Would execute: git $($createArgs -join ' ')" -Level 'DEBUG'
    } else {
        try {
            & git @createArgs
            Write-Log "Successfully created tag: $TagName" -Level 'SUCCESS'
        } catch {
            throw "Failed to create tag: $_"
        }
    }
}

function Push-ReleaseTag {
    param(
        [string]$TagName,
        [switch]$Force,
        [switch]$DryRun
    )
    
    Write-Log "Pushing tag to origin: $TagName" -Level 'INFO'
    
    $pushArgs = @('push', 'origin', $TagName)
    if ($Force) {
        $pushArgs += '--force'
    }
    
    if ($DryRun) {
        Write-Log "DRY RUN: Would execute: git $($pushArgs -join ' ')" -Level 'DEBUG'
    } else {
        try {
            & git @pushArgs
            Write-Log "Successfully pushed tag: $TagName" -Level 'SUCCESS'
        } catch {
            throw "Failed to push tag: $_"
        }
    }
}

# Main execution
try {
    Write-Log "🚀 Emergency Release Script - Force v1.4.0 Release" -Level 'INFO'
    Write-Log "=========================================" -Level 'INFO'
    
    if ($DryRun) {
        Write-Log "RUNNING IN DRY RUN MODE - No actual changes will be made" -Level 'WARNING'
    }
    
    # Verify prerequisites
    Write-Log "Checking prerequisites..." -Level 'INFO'
    
    if (-not (Test-GitCommand)) {
        throw "Git command not found. Please install Git and ensure it's in PATH."
    }
    Write-Log "✓ Git command available" -Level 'SUCCESS'
    
    if (-not (Test-GitRepository)) {
        throw "Not in a Git repository. Please run this script from the project root."
    }
    Write-Log "✓ Git repository detected" -Level 'SUCCESS'
    
    # Read version from VERSION file
    Write-Log "Reading version from VERSION file..." -Level 'INFO'
    $version = Get-ProjectVersion
    $tagName = "v$version"
    
    Write-Log "Found version: $version" -Level 'SUCCESS'
    Write-Log "Tag to create: $tagName" -Level 'SUCCESS'
    
    # Verify this is version 1.4.0
    if ($version -ne '1.4.0') {
        if ($Force) {
            Write-Log "VERSION file contains '$version' but proceeding due to -Force flag" -Level 'WARNING'
        } else {
            throw "Expected version 1.4.0 but found '$version'. Use -Force to override."
        }
    }
    
    # Check if tag already exists
    Write-Log "Checking if tag already exists..." -Level 'INFO'
    $tagExists = Test-TagExists -TagName $tagName
    
    if ($tagExists.Local) {
        Write-Log "Tag $tagName already exists locally" -Level 'WARNING'
        if (-not $Force) {
            throw "Tag $tagName already exists locally. Use -Force to recreate."
        }
    }
    
    if ($tagExists.Remote) {
        Write-Log "Tag $tagName already exists on remote" -Level 'WARNING'
        if (-not $Force) {
            throw "Tag $tagName already exists on remote. Use -Force to overwrite."
        }
    }
    
    if (-not $tagExists.Local -and -not $tagExists.Remote) {
        Write-Log "✓ Tag does not exist - safe to create" -Level 'SUCCESS'
    }
    
    # Fetch latest changes
    Write-Log "Fetching latest changes from origin..." -Level 'INFO'
    if (-not $DryRun) {
        try {
            git fetch origin
            Write-Log "✓ Fetched latest changes" -Level 'SUCCESS'
        } catch {
            Write-Log "Warning: Could not fetch from origin: $_" -Level 'WARNING'
        }
    } else {
        Write-Log "DRY RUN: Would execute: git fetch origin" -Level 'DEBUG'
    }
    
    # Create the tag
    Write-Log "Creating release tag..." -Level 'INFO'
    New-ReleaseTag -Version $version -TagName $tagName -Force:$Force -DryRun:$DryRun
    
    # Push the tag
    Write-Log "Pushing tag to trigger GitHub Actions..." -Level 'INFO'
    Push-ReleaseTag -TagName $tagName -Force:$Force -DryRun:$DryRun
    
    # Success summary
    Write-Log "=========================================" -Level 'INFO'
    Write-Log "🎉 Emergency release tag creation completed!" -Level 'SUCCESS'
    Write-Log "Tag: $tagName" -Level 'SUCCESS'
    Write-Log "Version: $version" -Level 'SUCCESS'
    
    if (-not $DryRun) {
        Write-Log "" -Level 'INFO'
        Write-Log "Next steps:" -Level 'INFO'
        Write-Log "1. Check GitHub Actions: https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]//' | sed 's/.git$//')/actions" -Level 'INFO'
        Write-Log "2. Monitor the 'Build & Release Pipeline' workflow" -Level 'INFO'
        Write-Log "3. The workflow should be triggered by the tag push: $tagName" -Level 'INFO'
        Write-Log "4. Release artifacts will be built for all platforms and profiles" -Level 'INFO'
        Write-Log "5. GitHub release will be created automatically upon successful build" -Level 'INFO'
    } else {
        Write-Log "" -Level 'INFO'
        Write-Log "This was a DRY RUN - no actual changes were made." -Level 'WARNING'
        Write-Log "Remove -DryRun flag to execute the commands." -Level 'INFO'
    }
    
} catch {
    Write-Log "❌ Emergency release failed: $($_.Exception.Message)" -Level 'ERROR'
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level 'DEBUG'
    exit 1
}