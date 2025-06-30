<#
.SYNOPSIS
    Simplified release creation for AitherZero
.PARAMETER ReleaseType
    Type of release: patch, minor, major, hotfix
.PARAMETER Version
    Specific version to release (overrides ReleaseType)
.PARAMETER Description
    Release description
.PARAMETER FastTrack
    Skip confirmation prompts
#>
param(
    [ValidateSet("patch", "minor", "major", "hotfix")]
    [string]$ReleaseType = "patch",
    
    [string]$Version,
    
    [Parameter(Mandatory)]
    [string]$Description,
    
    [switch]$FastTrack
)

# Import PatchManager
Import-Module (Join-Path $PSScriptRoot "../aither-core/modules/PatchManager") -Force

# Get current version
$currentVersion = Get-Content (Join-Path $PSScriptRoot "../VERSION") -Raw
$parts = $currentVersion.Trim() -split '\.'

# Calculate new version
if ($Version) {
    $newVersion = $Version
} else {
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
            # For hotfix, increment patch but mark as critical
            $parts[2] = [int]$parts[2] + 1
        }
    }
    $newVersion = $parts -join '.'
}

Write-Host "Creating release: v$currentVersion → v$newVersion" -ForegroundColor Cyan
Write-Host "Description: $Description" -ForegroundColor Yellow

if (-not $FastTrack) {
    $confirm = Read-Host "Continue? (Y/N)"
    if ($confirm -ne 'Y') {
        Write-Host "Release cancelled" -ForegroundColor Red
        return
    }
}

# Create release using PatchManager
$priority = if ($ReleaseType -eq "hotfix") { "High" } else { "Medium" }

Invoke-PatchWorkflow -PatchDescription "Release v$newVersion - $Description" -PatchOperation {
    Set-Content (Join-Path $PSScriptRoot "../VERSION") -Value $newVersion -NoNewline
    Write-Host "Updated VERSION to $newVersion" -ForegroundColor Green
} -CreatePR -Priority $priority

Write-Host "`nRelease PR created!" -ForegroundColor Green
Write-Host "After merging, run:" -ForegroundColor Cyan
Write-Host "  git checkout main" -ForegroundColor White
Write-Host "  git pull" -ForegroundColor White
Write-Host "  git tag -a 'v$newVersion' -m 'Release v$newVersion - $Description'" -ForegroundColor White
Write-Host "  git push origin 'v$newVersion'" -ForegroundColor White
