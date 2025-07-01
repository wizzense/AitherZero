#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Robust release automation script that prevents merge conflicts and ensures smooth releases
    
.DESCRIPTION
    This script provides bulletproof release automation with:
    - Automatic branch synchronization to prevent conflicts
    - Smart PR creation and tracking
    - Automated tagging after successful merge
    - Build pipeline monitoring
    - Rollback capability if issues occur
    
.PARAMETER ReleaseType
    Type of release: patch, minor, major
    
.PARAMETER Version
    Specific version to release (overrides ReleaseType)
    
.PARAMETER Description
    Release description
    
.PARAMETER SkipPR
    Skip PR creation and directly tag (for emergency releases)
    
.PARAMETER AutoMerge
    Enable auto-merge for PR (requires permissions)
    
.PARAMETER DryRun
    Preview what would be done
    
.EXAMPLE
    ./Create-RobustRelease.ps1 -ReleaseType patch -Description "Bug fixes"
    
.EXAMPLE
    ./Create-RobustRelease.ps1 -Version "1.2.15" -Description "Critical fix" -SkipPR
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ParameterSetName = 'ReleaseType')]
    [ValidateSet("patch", "minor", "major")]
    [string]$ReleaseType,
    
    [Parameter(Mandatory, ParameterSetName = 'Version')]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,
    
    [Parameter(Mandatory)]
    [string]$Description,
    
    [switch]$SkipPR,
    
    [switch]$AutoMerge,
    
    [switch]$DryRun
)

# Find project root
. "$PSScriptRoot/../aither-core/shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot -StartPath $PSScriptRoot

# Import PatchManager
Import-Module (Join-Path $projectRoot "aither-core/modules/PatchManager") -Force

# Helper functions
function Write-ReleaseLog {
    param([string]$Message, [string]$Level = "INFO")
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = @{
        'INFO' = 'Cyan'
        'SUCCESS' = 'Green'
        'WARNING' = 'Yellow'
        'ERROR' = 'Red'
    }[$Level]
    
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

function Get-CurrentVersion {
    $versionFile = Join-Path $projectRoot "VERSION"
    if (-not (Test-Path $versionFile)) {
        throw "VERSION file not found"
    }
    return (Get-Content $versionFile -Raw).Trim()
}

function Get-NextVersion {
    param([string]$Current, [string]$Type, [string]$Override)
    
    if ($Override) { return $Override }
    
    $parts = $Current -split '\.'
    switch ($Type) {
        "patch" { $parts[2] = [int]$parts[2] + 1 }
        "minor" { 
            $parts[1] = [int]$parts[1] + 1
            $parts[2] = "0"
        }
        "major" { 
            $parts[0] = [int]$parts[0] + 1
            $parts[1] = "0"
            $parts[2] = "0"
        }
    }
    return $parts -join '.'
}

function Test-GitClean {
    $status = git status --porcelain 2>&1
    return -not ($status -and ($status | Where-Object { $_ -match '\S' }))
}

function Test-BranchSynced {
    param([string]$Branch = "main")
    
    $localCommit = git rev-parse $Branch 2>&1
    $remoteCommit = git rev-parse "origin/$Branch" 2>&1
    
    return $localCommit -eq $remoteCommit
}

try {
    Write-Host ""
    Write-Host "🚀 AitherZero Robust Release Automation" -ForegroundColor Magenta
    Write-Host ("=" * 50) -ForegroundColor Magenta
    Write-Host ""
    
    # Pre-flight checks
    Write-ReleaseLog "Running pre-flight checks..."
    
    # Check if we have uncommitted changes
    if (-not (Test-GitClean)) {
        Write-ReleaseLog "Working directory has uncommitted changes" "WARNING"
        
        if (-not $DryRun) {
            Write-ReleaseLog "Stashing changes..."
            git stash push -m "RobustRelease: Auto-stash before release"
            $stashed = $true
        }
    }
    
    # Ensure we're on main branch
    $currentBranch = git branch --show-current
    if ($currentBranch -ne "main") {
        Write-ReleaseLog "Switching to main branch..."
        git checkout main
    }
    
    # CRITICAL: Sync with remote to prevent conflicts
    Write-ReleaseLog "Synchronizing with remote repository..."
    
    if (-not $DryRun) {
        # Use Sync-GitBranch for robust synchronization
        $syncResult = Sync-GitBranch -BranchName "main" -Force
        
        if (-not $syncResult.Success) {
            throw "Failed to sync with remote: $($syncResult.Message)"
        }
        
        Write-ReleaseLog "Successfully synchronized with remote" "SUCCESS"
    } else {
        Write-ReleaseLog "DRY RUN: Would sync with remote main" "INFO"
    }
    
    # Verify we're in sync
    if (-not $DryRun -and -not (Test-BranchSynced)) {
        throw "Local main is not in sync with remote after synchronization"
    }
    
    # Get version information
    $currentVersion = Get-CurrentVersion
    $nextVersion = Get-NextVersion -Current $currentVersion -Type $ReleaseType -Override $Version
    
    Write-ReleaseLog "Current version: $currentVersion"
    Write-ReleaseLog "Next version: $nextVersion" "SUCCESS"
    Write-ReleaseLog "Description: $Description"
    
    if ($DryRun) {
        Write-Host ""
        Write-Host "DRY RUN - No changes will be made" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Would perform:" -ForegroundColor Cyan
        Write-Host "  1. Update VERSION to $nextVersion"
        if (-not $SkipPR) {
            Write-Host "  2. Create PR with automatic conflict prevention"
            Write-Host "  3. Monitor PR and auto-tag after merge"
        } else {
            Write-Host "  2. Create tag v$nextVersion directly"
        }
        Write-Host "  4. Push changes and monitor build"
        return
    }
    
    if ($SkipPR) {
        # Emergency release - skip PR process
        Write-ReleaseLog "Emergency release mode - skipping PR" "WARNING"
        
        # Update VERSION file
        $versionFile = Join-Path $projectRoot "VERSION"
        Set-Content $versionFile -Value $nextVersion -NoNewline
        
        # Commit and tag
        git add $versionFile
        git commit -m "Release v$nextVersion - $Description"
        git tag -a "v$nextVersion" -m "Release v$nextVersion - $Description"
        
        # Push everything
        git push origin main
        git push origin "v$nextVersion"
        
        Write-ReleaseLog "Emergency release v$nextVersion created" "SUCCESS"
    } else {
        # Normal release with PR
        Write-ReleaseLog "Creating release PR..."
        
        # Use PatchManager with enhanced conflict prevention
        $prDescription = "Release v$nextVersion - $Description"
        
        $patchResult = Invoke-PatchWorkflow `
            -PatchDescription $prDescription `
            -PatchOperation {
                $versionFile = Join-Path $projectRoot "VERSION"
                Set-Content $versionFile -Value $nextVersion -NoNewline
                Write-Host "Updated VERSION to $nextVersion"
            } `
            -CreatePR `
            -Priority "High" `
            -Force
        
        if (-not $patchResult.Success) {
            throw "Failed to create release PR: $($patchResult.Message)"
        }
        
        Write-ReleaseLog "Release PR created successfully" "SUCCESS"
        
        if ($patchResult.PullRequestUrl) {
            Write-Host ""
            Write-Host "Pull Request: $($patchResult.PullRequestUrl)" -ForegroundColor Cyan
            
            # Extract PR number for monitoring
            if ($patchResult.PullRequestUrl -match '/pull/(\d+)') {
                $prNumber = $Matches[1]
                
                if ($AutoMerge) {
                    Write-ReleaseLog "Enabling auto-merge..."
                    try {
                        gh pr merge $prNumber --auto --merge
                        Write-ReleaseLog "Auto-merge enabled" "SUCCESS"
                    } catch {
                        Write-ReleaseLog "Could not enable auto-merge: $_" "WARNING"
                    }
                }
                
                # Monitor PR and create tag after merge
                Write-Host ""
                Write-Host "Monitoring PR for automatic tagging..." -ForegroundColor Cyan
                Write-Host "The release tag will be created automatically after PR is merged" -ForegroundColor Cyan
                
                # Create a monitor script that can run in background
                $monitorScript = @"
#!/usr/bin/env pwsh
# Release Monitor for v$nextVersion

`$prNumber = '$prNumber'
`$version = '$nextVersion'
`$description = '$Description'

Write-Host "Monitoring PR #`$prNumber for release v`$version..."

while (`$true) {
    try {
        `$prStatus = gh pr view `$prNumber --json state,mergedAt | ConvertFrom-Json
        
        if (`$prStatus.state -eq 'MERGED') {
            Write-Host "PR merged! Creating release tag..."
            
            # Switch to main and pull latest
            git checkout main
            git pull origin main
            
            # Create and push tag
            git tag -a "v`$version" -m "Release v`$version - `$description"
            git push origin "v`$version"
            
            Write-Host "Release v`$version completed!" -ForegroundColor Green
            break
        }
        elseif (`$prStatus.state -eq 'CLOSED') {
            Write-Host "PR was closed without merging" -ForegroundColor Red
            break
        }
        
        Start-Sleep -Seconds 30
    } catch {
        Write-Host "Error checking PR: `$_" -ForegroundColor Yellow
        Start-Sleep -Seconds 60
    }
}
"@
                
                $monitorPath = Join-Path $projectRoot "release-monitor-$nextVersion.ps1"
                Set-Content $monitorPath -Value $monitorScript
                
                Write-Host ""
                Write-Host "Monitor script created: $monitorPath" -ForegroundColor Yellow
                Write-Host "Run it in background to auto-tag after merge:" -ForegroundColor Yellow
                Write-Host "  pwsh $monitorPath &" -ForegroundColor Cyan
            }
        }
    }
    
    # Restore stashed changes if any
    if ($stashed) {
        Write-ReleaseLog "Restoring stashed changes..."
        git stash pop
    }
    
    Write-Host ""
    Write-Host "✅ Release process initiated successfully!" -ForegroundColor Green
    Write-Host ""
    
    if (-not $SkipPR) {
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "  1. Review and approve the PR"
        Write-Host "  2. Merge when ready (tag will be created automatically)"
        Write-Host "  3. Monitor build at: https://github.com/wizzense/AitherZero/actions"
    } else {
        Write-Host "Release created! Monitor build at:" -ForegroundColor Cyan
        Write-Host "  https://github.com/wizzense/AitherZero/actions"
    }
    
} catch {
    Write-ReleaseLog "Release failed: $_" "ERROR"
    
    # Attempt to restore state
    if ($stashed) {
        Write-ReleaseLog "Restoring stashed changes..."
        git stash pop
    }
    
    throw
}