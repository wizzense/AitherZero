#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Super simple release script for AitherZero
.DESCRIPTION
    This is the ONE COMMAND release solution as documented in CLAUDE.md.
    It wraps PatchManager's Invoke-ReleaseWorkflow for maximum simplicity.
.PARAMETER Type
    Release type: patch (default), minor, or major
.PARAMETER Description
    Description of the release
.PARAMETER Version
    Specific version number (overrides Type)
.PARAMETER DryRun
    Preview what would happen without making changes
.EXAMPLE
    ./release.ps1
    # Creates a patch release with auto-generated description
.EXAMPLE
    ./release.ps1 -Type minor -Description "New features"
    # Creates a minor release
.EXAMPLE
    ./release.ps1 -Type major -Description "Breaking changes"
    # Creates a major release
.EXAMPLE
    ./release.ps1 -Version 1.2.3 -Description "Custom version"
    # Creates a release with specific version
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('patch', 'minor', 'major')]
    [string]$Type = 'patch',
    
    [Parameter()]
    [string]$Description,
    
    [Parameter()]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,
    
    [Parameter()]
    [switch]$DryRun
)

# Banner
Write-Host @"

    🚀 AitherZero Release Script 🚀
    ==============================
    The ONE COMMAND release solution!
    
"@ -ForegroundColor Cyan

try {
    # Find project root
    $projectRoot = $PSScriptRoot
    $patchManagerPath = Join-Path $projectRoot "aither-core/modules/PatchManager"
    
    if (-not (Test-Path $patchManagerPath)) {
        throw "PatchManager module not found at: $patchManagerPath"
    }
    
    # Import PatchManager
    Write-Host "📦 Loading PatchManager..." -ForegroundColor Yellow
    Import-Module $patchManagerPath -Force
    
    # Build parameters for Invoke-ReleaseWorkflow
    $releaseParams = @{
        ReleaseType = $Type
    }
    
    # Use Version if provided, otherwise use Type
    if ($Version) {
        $releaseParams['Version'] = $Version
        Write-Host "📌 Creating release version: $Version" -ForegroundColor Green
    } else {
        Write-Host "📌 Creating $Type release" -ForegroundColor Green
    }
    
    # Add description if provided, otherwise auto-generate
    if ($Description) {
        $releaseParams['Description'] = $Description
    } else {
        # Auto-generate description based on type
        $releaseParams['Description'] = switch ($Type) {
            'patch' { "Bug fixes and minor improvements" }
            'minor' { "New features and enhancements" }
            'major' { "Major changes and improvements" }
            default { "Release updates" }
        }
        Write-Host "📝 Auto-generated description: $($releaseParams['Description'])" -ForegroundColor Yellow
    }
    
    # Add dry run if specified
    if ($DryRun) {
        $releaseParams['DryRun'] = $true
        Write-Host "🔍 DRY RUN MODE - No changes will be made" -ForegroundColor Magenta
    }
    
    # Show what will happen
    Write-Host "`n📋 Release Configuration:" -ForegroundColor Cyan
    Write-Host "  Type: $($releaseParams['ReleaseType'])" -ForegroundColor White
    if ($Version) {
        Write-Host "  Version: $Version" -ForegroundColor White
    }
    Write-Host "  Description: $($releaseParams['Description'])" -ForegroundColor White
    Write-Host ""
    
    # Confirm unless dry run
    if (-not $DryRun) {
        $confirm = Read-Host "Proceed with release? (Y/n)"
        if ($confirm -and $confirm -ne 'Y' -and $confirm -ne 'y') {
            Write-Host "❌ Release cancelled" -ForegroundColor Yellow
            exit 0
        }
    }
    
    # Execute the release
    Write-Host "`n🎯 Starting release process..." -ForegroundColor Cyan
    Write-Host "This will:" -ForegroundColor Yellow
    Write-Host "  1. Create a PR with version bump" -ForegroundColor White
    Write-Host "  2. Wait for CI checks to pass" -ForegroundColor White
    Write-Host "  3. Auto-merge the PR" -ForegroundColor White
    Write-Host "  4. Create and push release tag" -ForegroundColor White
    Write-Host "  5. Monitor build pipeline" -ForegroundColor White
    Write-Host "  6. Report when release is published" -ForegroundColor White
    Write-Host ""
    
    # Invoke the release workflow
    $result = Invoke-ReleaseWorkflow @releaseParams
    
    # In dry run mode, Invoke-ReleaseWorkflow returns nothing
    if ($DryRun) {
        Write-Host "`n✅ Dry run completed successfully!" -ForegroundColor Green
        Write-Host "No changes were made." -ForegroundColor Yellow
    } elseif ($result -and $result.Success) {
        Write-Host "`n✅ Release completed successfully!" -ForegroundColor Green
        
        if ($result.ReleaseUrl) {
            Write-Host "🎉 Release URL: $($result.ReleaseUrl)" -ForegroundColor Cyan
        }
        
        Write-Host "`n🎊 That's it! No manual steps required!" -ForegroundColor Green
    } elseif ($result) {
        throw "Release failed: $($result.Message)"
    } else {
        # If no result object returned (shouldn't happen in non-dry-run mode)
        Write-Host "`n✅ Release process completed!" -ForegroundColor Green
    }
    
} catch {
    Write-Host "`n❌ Release failed!" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "`nFor manual release, you can also use:" -ForegroundColor Yellow
    Write-Host "  - GitHub UI: Actions → Manual Release Creator" -ForegroundColor White
    Write-Host "  - PatchManager: Import-Module ./aither-core/modules/PatchManager -Force; Invoke-ReleaseWorkflow -ReleaseType 'patch'" -ForegroundColor White
    exit 1
}