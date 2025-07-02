#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates emergency patch release v1.4.1 with critical fixes for AitherZero startup issues

.DESCRIPTION
    This script commits all the critical fixes for AitherZero v1.4.0 startup issues:
    - Fixed module dependency issues (Logging version/GUID mismatches)
    - Fixed PSCustomObject to Hashtable conversion in aither-core.ps1
    - Made ActiveDirectory dependency optional in SecurityAutomation
    - Fixed LicenseManager dependency in StartupExperience
    
    Creates version 1.4.1 as emergency patch release.

.PARAMETER DryRun
    Preview what would be done without making changes

.EXAMPLE
    ./Create-EmergencyPatch-v1.4.1.ps1
    Create the emergency patch release

.EXAMPLE
    ./Create-EmergencyPatch-v1.4.1.ps1 -DryRun
    Preview the emergency patch release
#>

[CmdletBinding()]
param(
    [switch]$DryRun
)

# Set error handling
$ErrorActionPreference = 'Stop'

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )
    
    $color = switch ($Level) {
        'SUCCESS' { 'Green' }
        'WARNING' { 'Yellow' }
        'ERROR' { 'Red' }
        default { 'White' }
    }
    
    Write-Host "[$Level] $Message" -ForegroundColor $color
}

try {
    Write-Log "🩹 Creating Emergency Patch Release v1.4.1" -Level 'INFO'
    Write-Log "=========================================" -Level 'INFO'
    
    if ($DryRun) {
        Write-Log "RUNNING IN DRY RUN MODE - No actual changes will be made" -Level 'WARNING'
    }
    
    # Step 1: Import PatchManager v3.0
    Write-Log "Step 1: Loading PatchManager v3.0..." -Level 'INFO'
    
    $patchManagerPath = Join-Path $PSScriptRoot "aither-core/modules/PatchManager"
    if (-not (Test-Path $patchManagerPath)) {
        throw "PatchManager module not found at: $patchManagerPath"
    }
    
    Import-Module $patchManagerPath -Force
    Write-Log "✅ PatchManager v3.0 loaded" -Level 'SUCCESS'
    
    # Step 2: Use New-Feature to create the patch with all fixes
    Write-Log "Step 2: Creating comprehensive patch for critical startup fixes..." -Level 'INFO'
    
    $patchDescription = "Emergency patch v1.4.1: Fix critical startup issues from v1.4.0"
    
    $changes = {
        Write-Log "All critical fixes have been applied:" -Level 'INFO'
        Write-Log "  ✅ Fixed Logging module dependencies (ConfigurationCore, ModuleCommunication, ProgressTracking)" -Level 'SUCCESS'
        Write-Log "  ✅ Fixed LicenseManager dependency in StartupExperience" -Level 'SUCCESS'
        Write-Log "  ✅ Fixed PSCustomObject to Hashtable conversion in aither-core.ps1" -Level 'SUCCESS'
        Write-Log "  ✅ Made ActiveDirectory dependency optional in SecurityAutomation" -Level 'SUCCESS'
        Write-Log "  ✅ Module loading order ensures Logging loads first" -Level 'SUCCESS'
        Write-Log ""
        Write-Log "These fixes resolve the major startup failures reported in v1.4.0" -Level 'INFO'
    }
    
    if ($DryRun) {
        Write-Log "DRY RUN: Would create patch with PatchManager v3.0" -Level 'INFO'
        & $changes
    } else {
        Write-Log "Creating patch using PatchManager v3.0..." -Level 'INFO'
        
        # Use New-Feature since this is a significant set of fixes
        $result = New-Feature -Description $patchDescription -Changes $changes
        
        if ($result.Success) {
            Write-Log "✅ Patch created successfully with PatchManager v3.0" -Level 'SUCCESS'
            Write-Log "Mode: $($result.Mode)" -Level 'INFO'
            Write-Log "Duration: $($result.Duration.TotalSeconds) seconds" -Level 'INFO'
        } else {
            throw "Patch creation failed: $($result.Error)"
        }
    }
    
    # Step 3: Update VERSION file for v1.4.1
    Write-Log "Step 3: Updating VERSION file to 1.4.1..." -Level 'INFO'
    
    $versionFile = Join-Path $PSScriptRoot "VERSION"
    if (-not $DryRun) {
        Set-Content -Path $versionFile -Value "1.4.1" -NoNewline
        Write-Log "✅ VERSION updated to 1.4.1" -Level 'SUCCESS'
    } else {
        Write-Log "DRY RUN: Would update VERSION file to 1.4.1" -Level 'INFO'
    }
    
    # Step 4: Create final patch for version update
    Write-Log "Step 4: Creating patch for version update..." -Level 'INFO'
    
    $versionPatchDescription = "Update VERSION to 1.4.1 for emergency patch release"
    
    if ($DryRun) {
        Write-Log "DRY RUN: Would create version update patch" -Level 'INFO'
    } else {
        $versionResult = New-QuickFix -Description $versionPatchDescription -Changes {
            Write-Log "VERSION file updated to trigger v1.4.1 release" -Level 'INFO'
        }
        
        if ($versionResult.Success) {
            Write-Log "✅ Version update patch created" -Level 'SUCCESS'
        } else {
            throw "Version update patch failed: $($versionResult.Error)"
        }
    }
    
    Write-Log "=========================================" -Level 'INFO'
    Write-Log "🎉 Emergency Patch v1.4.1 Creation Complete!" -Level 'SUCCESS'
    Write-Log "" -Level 'INFO'
    Write-Log "Summary of Fixes Applied:" -Level 'INFO'
    Write-Log "• Fixed module dependency resolution (Logging v2.0.0 GUID)" -Level 'SUCCESS'
    Write-Log "• Fixed configuration type conversion (PSCustomObject → Hashtable)" -Level 'SUCCESS'
    Write-Log "• Made ActiveDirectory optional (no longer required)" -Level 'SUCCESS'
    Write-Log "• Fixed LicenseManager dependency in StartupExperience" -Level 'SUCCESS'
    Write-Log "• Preserved module loading order (Logging first)" -Level 'SUCCESS'
    Write-Log "" -Level 'INFO'
    
    if (-not $DryRun) {
        Write-Log "Next Steps:" -Level 'INFO'
        Write-Log "1. The VERSION change to 1.4.1 will trigger build pipeline" -Level 'INFO'
        Write-Log "2. Monitor GitHub Actions for build completion" -Level 'INFO'
        Write-Log "3. Test the new release packages for startup fixes" -Level 'INFO'
        Write-Log "4. v1.4.1 should resolve all critical startup failures" -Level 'INFO'
        Write-Log "" -Level 'INFO'
        Write-Log "Build Pipeline URL: https://github.com/[your-repo]/actions" -Level 'INFO'
        Write-Log "Release URL: https://github.com/[your-repo]/releases" -Level 'INFO'
    } else {
        Write-Log "This was a DRY RUN - no actual changes were made." -Level 'WARNING'
        Write-Log "Remove -DryRun flag to execute the emergency patch creation." -Level 'INFO'
    }
    
} catch {
    Write-Log "❌ Emergency patch creation failed: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}