#Requires -Version 7.0

<#
.SYNOPSIS
    Direct release script that updates VERSION and triggers release via PR workflow

.DESCRIPTION
    Simplifies the release process by:
    1. Creating a PR to update VERSION on main
    2. Auto-merging the PR once checks pass
    3. Letting CI trigger the release workflow automatically
    
    This avoids all the complexity of manual tagging and workflow permissions.

.PARAMETER Version
    Version to release (e.g., "0.8.3")

.PARAMETER Message
    Release message/description

.PARAMETER SkipTests
    Skip waiting for CI tests (not recommended)

.EXAMPLE
    ./Direct-Release.ps1 -Version "0.8.3" -Message "Bug fixes and improvements"

.EXAMPLE
    ./Direct-Release.ps1 -Version "1.0.0" -Message "Major release with breaking changes"

.NOTES
    This script uses PatchManager to ensure proper PR workflow
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [string]$Message,

    [Parameter(Mandatory = $false)]
    [switch]$SkipTests
)

function Write-ReleaseLog {
    param($Message, $Level = "INFO")
    $color = switch ($Level) {
        'SUCCESS' { 'Green' }
        'ERROR' { 'Red' }
        'WARN' { 'Yellow' }
        default { 'Cyan' }
    }
    Write-Host "🚀 $Message" -ForegroundColor $color
}

try {
    Write-ReleaseLog "Direct Release Script - Simple & Reliable" "SUCCESS"
    Write-ReleaseLog "Target Version: $Version"
    Write-ReleaseLog "Release Message: $Message"
    
    # Step 1: Import PatchManager
    Write-ReleaseLog "Loading PatchManager..."
    . "$PSScriptRoot/aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    Import-Module (Join-Path $projectRoot "aither-core/modules/PatchManager") -Force
    
    # Step 2: Create PR to update VERSION
    Write-ReleaseLog "Creating release PR to update VERSION to $Version..."
    
    $prResult = New-Feature -Description "Release v$Version`: $Message" -Priority "High" -Changes {
        Set-Content -Path "VERSION" -Value $Version
        Write-Host "VERSION file updated to $Version" -ForegroundColor Green
    }
    
    if (-not $prResult -or -not $prResult.Success) {
        throw "Failed to create release PR"
    }
    
    $prUrl = $prResult.Result.PullRequestUrl
    $prNumber = ($prUrl -split '/')[-1]
    
    Write-ReleaseLog "Release PR created: #$prNumber" "SUCCESS"
    Write-ReleaseLog "PR URL: $prUrl"
    
    # Step 3: Wait for CI checks to pass
    if (-not $SkipTests) {
        Write-ReleaseLog "Waiting for CI checks to pass..."
        $maxAttempts = 60  # 10 minutes max
        $attempt = 0
        
        while ($attempt -lt $maxAttempts) {
            Start-Sleep -Seconds 10
            $attempt++
            
            # Check PR status
            $prStatus = gh pr view $prNumber --json statusCheckRollup --jq '.statusCheckRollup[] | select(.name == "CI - Continuous Integration") | .status' 2>$null
            
            if ($prStatus -eq "COMPLETED") {
                $prConclusion = gh pr view $prNumber --json statusCheckRollup --jq '.statusCheckRollup[] | select(.name == "CI - Continuous Integration") | .conclusion' 2>$null
                
                if ($prConclusion -eq "SUCCESS") {
                    Write-ReleaseLog "CI checks passed!" "SUCCESS"
                    break
                } elseif ($prConclusion -eq "FAILURE") {
                    throw "CI checks failed - please fix issues before releasing"
                }
            }
            
            if ($attempt % 6 -eq 0) {
                Write-ReleaseLog "Still waiting for CI... ($([Math]::Round($attempt/6, 0)) minutes elapsed)"
            }
        }
        
        if ($attempt -ge $maxAttempts) {
            Write-ReleaseLog "CI checks timed out - you may need to check manually" "WARN"
        }
    }
    
    # Step 4: Merge the PR
    Write-ReleaseLog "Merging release PR..."
    $mergeResult = gh pr merge $prNumber --squash --auto 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-ReleaseLog "Release PR merged successfully!" "SUCCESS"
    } else {
        Write-ReleaseLog "Auto-merge enabled. PR will merge when checks pass." "WARN"
    }
    
    # Step 5: Provide status update
    Write-ReleaseLog "`nRelease Process Status:" "SUCCESS"
    Write-ReleaseLog "1. ✅ VERSION updated to $Version"
    Write-ReleaseLog "2. ✅ Release PR created (#$prNumber)"
    Write-ReleaseLog "3. ✅ CI checks initiated"
    Write-ReleaseLog "4. ✅ PR merge scheduled"
    Write-ReleaseLog "`nNext steps:"
    Write-ReleaseLog "- CI will complete and merge the PR"
    Write-ReleaseLog "- Release workflow will trigger automatically"
    Write-ReleaseLog "- Monitor progress at: https://github.com/wizzense/AitherZero/actions"
    
    Write-ReleaseLog "`nEstimated time to release: ~15 minutes" "SUCCESS"
    
} catch {
    Write-ReleaseLog "Release failed: $($_.Exception.Message)" "ERROR"
    exit 1
}

Write-ReleaseLog "Direct release process initiated successfully! 🎉" "SUCCESS"