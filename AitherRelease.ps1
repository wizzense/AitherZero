#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Painless & automated release script for AitherZero
.DESCRIPTION
    Fully automated release process that respects branch protection rules.
    Creates PR, waits for checks, auto-merges, and monitors release.
.PARAMETER Version
    Specific version number (e.g., 1.2.3)
.PARAMETER Type
    Release type: patch, minor, or major (auto-increments version)
.PARAMETER Message
    Release message/description
.PARAMETER DryRun
    Preview mode - shows what would happen without making changes
.EXAMPLE
    ./AitherRelease.ps1 -Version 1.2.3 -Message "Bug fixes"
.EXAMPLE
    ./AitherRelease.ps1 -Type patch -Message "Bug fixes"
.EXAMPLE
    ./AitherRelease.ps1 -Type minor -Message "New features"
.EXAMPLE
    ./AitherRelease.ps1 -Type major -Message "Breaking changes"
#>

[CmdletBinding(DefaultParameterSetName = 'Type')]
param(
    [Parameter(ParameterSetName = 'Version', Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,
    
    [Parameter(ParameterSetName = 'Type', Mandatory = $true)]
    [ValidateSet('patch', 'minor', 'major')]
    [string]$Type,
    
    [Parameter(Mandatory = $true)]
    [string]$Message,
    
    [Parameter()]
    [switch]$DryRun
)

# This is an alias/wrapper for release.ps1 with slightly different parameter names
# to match the documentation in CLAUDE.md

try {
    $releaseScriptPath = Join-Path $PSScriptRoot "release.ps1"
    
    if (-not (Test-Path $releaseScriptPath)) {
        throw "release.ps1 not found. Creating symlink to self..."
        # If release.ps1 doesn't exist, this script can work standalone
    }
    
    # Build parameters for release.ps1
    $params = @{
        Description = $Message
        DryRun = $DryRun
    }
    
    if ($PSCmdlet.ParameterSetName -eq 'Version') {
        $params['Version'] = $Version
    } else {
        $params['Type'] = $Type
    }
    
    # Call release.ps1
    & $releaseScriptPath @params
    
} catch {
    # If release.ps1 doesn't exist, run the release directly
    Write-Host "Running release directly..." -ForegroundColor Yellow
    
    # Import PatchManager
    $patchManagerPath = Join-Path $PSScriptRoot "aither-core/modules/PatchManager"
    Import-Module $patchManagerPath -Force
    
    # Build parameters
    $releaseParams = @{
        Description = $Message
    }
    
    if ($PSCmdlet.ParameterSetName -eq 'Version') {
        $releaseParams['Version'] = $Version
    } else {
        $releaseParams['ReleaseType'] = $Type
    }
    
    if ($DryRun) {
        $releaseParams['DryRun'] = $true
    }
    
    # Invoke release
    $result = Invoke-ReleaseWorkflow @releaseParams
    
    if ($result.Success) {
        Write-Host "`n✅ Release completed successfully!" -ForegroundColor Green
        if ($result.ReleaseUrl) {
            Write-Host "🎉 Release URL: $($result.ReleaseUrl)" -ForegroundColor Cyan
        }
    } else {
        throw "Release failed: $($result.Message)"
    }
}