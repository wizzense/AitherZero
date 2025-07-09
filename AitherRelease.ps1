#Requires -Version 7.0

<#
.SYNOPSIS
    THE ONE AND ONLY release script for AitherZero. Simple. Painless. Works every time.

.DESCRIPTION
    This script handles the ENTIRE release process automatically:
    1. Creates a PR to update VERSION (respects branch protection)
    2. Waits for CI to pass
    3. Auto-merges the PR
    4. Monitors release workflow
    5. Reports when release is published
    
    No more confusion. No more multiple scripts. Just this one.

.PARAMETER Version
    Version to release (e.g., 1.2.3)

.PARAMETER Type
    Auto-increment type: patch, minor, or major

.PARAMETER Message
    Release message/description

.PARAMETER DryRun
    Preview what would happen without making changes

.EXAMPLE
    ./AitherRelease.ps1 -Version 1.0.0 -Message "Major release with new features"

.EXAMPLE
    ./AitherRelease.ps1 -Type patch -Message "Bug fixes and improvements"

.EXAMPLE
    ./AitherRelease.ps1 -Type minor -Message "New feature: AI integration" -DryRun
#>

param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Explicit')]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,

    [Parameter(Mandatory = $true, ParameterSetName = 'Auto')]
    [ValidateSet('patch', 'minor', 'major')]
    [string]$Type,

    [Parameter(Mandatory = $true)]
    [string]$Message,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# Emoji helpers for beautiful output
$emoji = @{
    rocket = '🚀'
    check = '✅'
    wait = '⏳'
    error = '❌'
    party = '🎉'
    pr = '📝'
    merge = '🔀'
    package = '📦'
    link = '🔗'
}

function Write-ReleaseStatus {
    param(
        [string]$Message,
        [string]$Icon = 'rocket',
        [string]$Color = 'Cyan'
    )
    Write-Host "$($emoji[$Icon]) $Message" -ForegroundColor $Color
}

# Import PatchManager
Write-ReleaseStatus "AitherZero Release Assistant" -Color Magenta
Write-Host ("=" * 40) -ForegroundColor Magenta
Write-Host ""

# Get version if auto-incrementing
if ($Type) {
    $versionFile = Join-Path $PSScriptRoot "VERSION"
    $currentVersion = if (Test-Path $versionFile) { 
        (Get-Content $versionFile -Raw).Trim() 
    } else { 
        "0.0.0" 
    }
    
    $parts = $currentVersion -split '\.'
    switch ($Type) {
        'patch' { $parts[2] = [int]$parts[2] + 1 }
        'minor' { 
            $parts[1] = [int]$parts[1] + 1
            $parts[2] = "0"
        }
        'major' { 
            $parts[0] = [int]$parts[0] + 1
            $parts[1] = "0"
            $parts[2] = "0"
        }
    }
    $Version = $parts -join '.'
    Write-ReleaseStatus "Auto-incrementing: $currentVersion → $Version" -Icon 'check'
}

Write-Host "Version: " -NoNewline -ForegroundColor White
Write-Host $Version -ForegroundColor Green
Write-Host "Message: " -NoNewline -ForegroundColor White
Write-Host $Message -ForegroundColor Green
Write-Host ""

if ($DryRun) {
    Write-ReleaseStatus "DRY RUN MODE - No changes will be made" -Icon 'wait' -Color Yellow
    Write-Host ""
}

try {
    # Import PatchManager
    Write-ReleaseStatus "Loading release automation..." -Icon 'wait'
    . "$PSScriptRoot/aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    Import-Module (Join-Path $projectRoot "aither-core/modules/PatchManager") -Force

    # Check if we have the New-Release function (future enhancement)
    if (Get-Command New-Release -ErrorAction SilentlyContinue) {
        # Use the dedicated release function
        if ($DryRun) {
            Write-ReleaseStatus "Would create release PR for v$Version" -Icon 'pr' -Color Yellow
            Write-ReleaseStatus "Would wait for CI checks to pass" -Icon 'wait' -Color Yellow
            Write-ReleaseStatus "Would auto-merge PR when ready" -Icon 'merge' -Color Yellow
            Write-ReleaseStatus "Would monitor release workflow" -Icon 'package' -Color Yellow
            exit 0
        }

        $result = New-Release -Version $Version -Message $Message
    }
    else {
        # Fall back to using New-Feature with release-specific handling
        Write-ReleaseStatus "Creating release PR..." -Icon 'pr'
        
        if ($DryRun) {
            Write-ReleaseStatus "Would create PR to update VERSION to $Version" -Icon 'pr' -Color Yellow
            Write-ReleaseStatus "Would enable auto-merge on the PR" -Icon 'merge' -Color Yellow
            Write-ReleaseStatus "Would wait for CI and merge" -Icon 'wait' -Color Yellow
            Write-ReleaseStatus "Would monitor release workflow" -Icon 'package' -Color Yellow
            exit 0
        }

        # Create the release PR
        $prResult = New-Feature -Description "Release v$Version`: $Message" -Priority "High" -Changes {
            $versionFile = Join-Path $PSScriptRoot "VERSION"
            Set-Content -Path $versionFile -Value $Version -NoNewline
            Write-Host "Updated VERSION file to $Version" -ForegroundColor Green
        }

        if (-not $prResult -or -not $prResult.Success) {
            throw "Failed to create release PR"
        }

        $prUrl = $prResult.Result.PullRequestUrl
        $prNumber = ($prUrl -split '/')[-1]
        
        Write-ReleaseStatus "Created release PR #$prNumber" -Icon 'check'
        Write-ReleaseStatus "PR URL: $prUrl" -Icon 'link' -Color Blue
    }

    # Enable auto-merge
    Write-ReleaseStatus "Enabling auto-merge..." -Icon 'merge'
    $mergeResult = gh pr merge $prNumber --auto --squash 2>&1
    if ($LASTEXITCODE -ne 0 -and $mergeResult -notmatch "already enabled") {
        Write-Warning "Auto-merge may not be enabled: $mergeResult"
    }

    # Monitor CI status
    Write-ReleaseStatus "Waiting for CI checks..." -Icon 'wait'
    $maxWaitMinutes = 10
    $checkInterval = 15
    $attempts = ($maxWaitMinutes * 60) / $checkInterval
    
    for ($i = 0; $i -lt $attempts; $i++) {
        $prStatus = gh pr view $prNumber --json state,mergeable,mergeStateStatus,statusCheckRollup 2>$null | ConvertFrom-Json
        
        if ($prStatus.state -eq "MERGED") {
            Write-ReleaseStatus "PR merged successfully!" -Icon 'check'
            break
        }
        
        if ($prStatus.state -eq "CLOSED") {
            throw "PR was closed without merging"
        }
        
        # Check CI status
        $ciChecks = $prStatus.statusCheckRollup | Where-Object { $_.name -like "*CI*" -and $_.conclusion }
        if ($ciChecks) {
            $failed = $ciChecks | Where-Object { $_.conclusion -eq "FAILURE" }
            if ($failed) {
                throw "CI checks failed. Please fix issues and try again."
            }
        }
        
        if ($i % 4 -eq 0) {
            Write-Host "  Still waiting... ($(($i * $checkInterval) / 60) minutes elapsed)" -ForegroundColor Gray
        }
        
        Start-Sleep -Seconds $checkInterval
    }

    if ($prStatus.state -ne "MERGED") {
        Write-Warning "PR hasn't merged yet. It may merge automatically when checks pass."
        Write-ReleaseStatus "Monitor at: $prUrl" -Icon 'link' -Color Yellow
    }

    # Monitor release workflow
    Write-ReleaseStatus "Waiting for release workflow to start..." -Icon 'wait'
    Start-Sleep -Seconds 30  # Give workflow time to trigger
    
    # Check for release workflow
    $releaseRun = gh run list --workflow=release.yml --limit=1 --json status,conclusion,databaseId,createdAt | 
                  ConvertFrom-Json | 
                  Where-Object { [DateTime]$_.createdAt -gt (Get-Date).AddMinutes(-5) }
    
    if ($releaseRun) {
        Write-ReleaseStatus "Release workflow started!" -Icon 'package'
        $runId = $releaseRun.databaseId
        
        # Monitor release workflow
        Write-ReleaseStatus "Building release packages..." -Icon 'wait'
        gh run watch $runId --exit-status > $null 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-ReleaseStatus "Release workflow completed successfully!" -Icon 'check'
        } else {
            Write-Warning "Release workflow may have issues. Check: https://github.com/wizzense/AitherZero/actions/runs/$runId"
        }
    }

    # Check if release was created
    Start-Sleep -Seconds 10
    $latestRelease = gh release list --limit=1 --json tagName,publishedAt | ConvertFrom-Json
    if ($latestRelease.tagName -eq "v$Version") {
        Write-ReleaseStatus "Release v$Version published!" -Icon 'party' -Color Green
        Write-ReleaseStatus "View at: https://github.com/wizzense/AitherZero/releases/tag/v$Version" -Icon 'link' -Color Blue
    } else {
        Write-ReleaseStatus "Release creation pending. Monitor at: https://github.com/wizzense/AitherZero/actions" -Icon 'wait' -Color Yellow
    }

    Write-Host ""
    Write-ReleaseStatus "Release process completed!" -Icon 'party' -Color Green

} catch {
    Write-ReleaseStatus "Release failed: $($_.Exception.Message)" -Icon 'error' -Color Red
    exit 1
}