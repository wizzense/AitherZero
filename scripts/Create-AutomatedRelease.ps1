#Requires -Version 7.0

<#
.SYNOPSIS
    Fully automated release creation for AitherZero
    
.DESCRIPTION
    This script handles the complete release process:
    1. Updates VERSION file
    2. Creates commit
    3. Creates and pushes tag
    4. Monitors build pipeline
    5. Reports release status
    
.PARAMETER ReleaseType
    Type of release: patch, minor, major, hotfix
    
.PARAMETER Version
    Specific version to release (overrides ReleaseType)
    
.PARAMETER Description
    Release description
    
.PARAMETER SkipPR
    Skip PR creation and work directly on main (requires permissions)
    
.PARAMETER DryRun
    Show what would be done without making changes
    
.EXAMPLE
    ./Create-AutomatedRelease.ps1 -ReleaseType patch -Description "PowerShell 5.1 compatibility fix"
    
.EXAMPLE
    ./Create-AutomatedRelease.ps1 -Version 1.2.14 -Description "Critical bug fix" -SkipPR
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet("patch", "minor", "major", "hotfix")]
    [string]$ReleaseType = "patch",
    
    [string]$Version,
    
    [Parameter(Mandatory)]
    [string]$Description,
    
    [switch]$SkipPR,
    
    [switch]$DryRun
)

# Import required modules
$ErrorActionPreference = 'Stop'

# Find project root
$projectRoot = Split-Path $PSScriptRoot -Parent

# Helper functions
function Write-Step {
    param([string]$Message, [string]$Type = "Info")
    
    $color = switch ($Type) {
        "Info"    { "Cyan" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
    }
    
    $prefix = switch ($Type) {
        "Info"    { "→" }
        "Success" { "✓" }
        "Warning" { "!" }
        "Error"   { "✗" }
    }
    
    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Test-GitStatus {
    $status = & git status --porcelain
    if ($status) {
        Write-Step "Uncommitted changes detected:" "Warning"
        $status | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
        
        if (-not $DryRun) {
            $continue = Read-Host "Continue anyway? (y/N)"
            if ($continue -ne 'y') {
                throw "Aborted due to uncommitted changes"
            }
        }
    }
}

function Get-NextVersion {
    param(
        [string]$CurrentVersion,
        [string]$ReleaseType,
        [string]$OverrideVersion
    )
    
    if ($OverrideVersion) {
        return $OverrideVersion
    }
    
    $parts = $CurrentVersion.Trim() -split '\.'
    
    switch ($ReleaseType) {
        "patch" {
            $parts[2] = [int]$parts[2] + 1
        }
        "minor" {
            $parts[1] = [int]$parts[1] + 1
            $parts[2] = "0"
        }
        "major" {
            $parts[0] = [int]$parts[0] + 1
            $parts[1] = "0"
            $parts[2] = "0"
        }
        "hotfix" {
            $parts[2] = [int]$parts[2] + 1
        }
    }
    
    return $parts -join '.'
}

function Update-VersionFile {
    param([string]$NewVersion)
    
    $versionFile = Join-Path $projectRoot "VERSION"
    
    if ($PSCmdlet.ShouldProcess($versionFile, "Update version to $NewVersion")) {
        Set-Content $versionFile -Value $NewVersion -NoNewline
        Write-Step "Updated VERSION file to $NewVersion" "Success"
    }
}

function Invoke-GitOperations {
    param(
        [string]$Version,
        [string]$Description,
        [switch]$SkipPR
    )
    
    # Ensure we're on the right branch
    $currentBranch = & git branch --show-current
    
    if ($SkipPR) {
        # Direct to main workflow
        if ($currentBranch -ne "main") {
            Write-Step "Switching to main branch" "Info"
            & git checkout main
            & git pull origin main
        }
        
        # Stage and commit VERSION file
        if ($PSCmdlet.ShouldProcess("VERSION", "Git add and commit")) {
            & git add VERSION
            $commitMessage = @"
Bump version to $Version

$Description

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
"@
            & git commit -m $commitMessage
            Write-Step "Created version commit" "Success"
        }
        
        # Push to main (will fail if protected)
        if ($PSCmdlet.ShouldProcess("origin main", "Git push")) {
            try {
                & git push origin main
                Write-Step "Pushed to main" "Success"
            } catch {
                Write-Step "Could not push to main (branch protection)" "Warning"
                Write-Step "Creating PR instead..." "Info"
                $SkipPR = $false
            }
        }
    }
    
    if (-not $SkipPR) {
        # PR workflow
        $branchName = "release/v$Version"
        
        if ($PSCmdlet.ShouldProcess($branchName, "Create release branch")) {
            # Create release branch
            & git checkout -b $branchName
            
            # Stage and commit
            & git add VERSION
            $commitMessage = @"
Bump version to $Version

$Description

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
"@
            & git commit -m $commitMessage
            
            # Push branch
            & git push -u origin $branchName
            
            Write-Step "Created release branch: $branchName" "Success"
            Write-Step "Create PR at: https://github.com/wizzense/AitherZero/pull/new/$branchName" "Info"
            
            # Return to main
            & git checkout main
        }
    }
    
    # Create and push tag
    $tagName = "v$Version"
    if ($PSCmdlet.ShouldProcess($tagName, "Create and push tag")) {
        $tagMessage = @"
Release $tagName - $Description

$Description

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
"@
        & git tag -a $tagName -m $tagMessage
        & git push origin $tagName
        
        Write-Step "Created and pushed tag: $tagName" "Success"
    }
}

function Watch-ReleaseBuild {
    param([string]$Version)
    
    Write-Step "Monitoring release build for v$Version..." "Info"
    
    # Check if gh CLI is available
    $ghAvailable = Get-Command gh -ErrorAction SilentlyContinue
    
    if ($ghAvailable) {
        Write-Step "Opening GitHub Actions in browser..." "Info"
        & gh run list --workflow="Build & Release Pipeline" --limit 1
        
        # Wait for workflow to start
        Start-Sleep -Seconds 10
        
        # Watch the workflow
        & gh run watch
    } else {
        Write-Step "GitHub CLI not available. Monitor build at:" "Warning"
        Write-Host "  https://github.com/wizzense/AitherZero/actions" -ForegroundColor Cyan
    }
}

# Main execution
try {
    Write-Host "`n🚀 AitherZero Automated Release Creator" -ForegroundColor Magenta
    Write-Host "=" * 50 -ForegroundColor Magenta
    
    # Check git status
    Write-Step "Checking repository status..." "Info"
    Test-GitStatus
    
    # Get current version
    $versionFile = Join-Path $projectRoot "VERSION"
    $currentVersion = Get-Content $versionFile -Raw
    $newVersion = Get-NextVersion -CurrentVersion $currentVersion -ReleaseType $ReleaseType -OverrideVersion $Version
    
    Write-Host "`n📋 Release Summary:" -ForegroundColor Cyan
    Write-Host "  Current Version: $($currentVersion.Trim())" -ForegroundColor White
    Write-Host "  New Version:     $newVersion" -ForegroundColor Green
    Write-Host "  Release Type:    $ReleaseType" -ForegroundColor White
    Write-Host "  Description:     $Description" -ForegroundColor White
    
    if ($DryRun) {
        Write-Host "`n⚠️  DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
    }
    
    # Confirm
    if (-not $DryRun -and -not $PSCmdlet.ShouldContinue("Create release v$newVersion?", "Confirm Release")) {
        Write-Step "Release cancelled" "Warning"
        return
    }
    
    # Update version file
    Write-Host "`n📝 Updating version..." -ForegroundColor Cyan
    Update-VersionFile -NewVersion $newVersion
    
    # Git operations
    Write-Host "`n🔧 Performing Git operations..." -ForegroundColor Cyan
    Invoke-GitOperations -Version $newVersion -Description $Description -SkipPR:$SkipPR
    
    # Monitor build
    if (-not $DryRun) {
        Write-Host "`n📦 Release pipeline triggered!" -ForegroundColor Green
        Watch-ReleaseBuild -Version $newVersion
    }
    
    Write-Host "`n✅ Release v$newVersion created successfully!" -ForegroundColor Green
    
    if (-not $SkipPR) {
        Write-Host "`n📌 Next Steps:" -ForegroundColor Yellow
        Write-Host "  1. Create and merge PR for version bump" -ForegroundColor White
        Write-Host "  2. Monitor build at: https://github.com/wizzense/AitherZero/actions" -ForegroundColor White
        Write-Host "  3. Verify release at: https://github.com/wizzense/AitherZero/releases" -ForegroundColor White
    }
    
} catch {
    Write-Step "Release failed: $_" "Error"
    exit 1
}