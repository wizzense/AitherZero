# SetupWizard Backward Compatibility Shim
# This module provides backward compatibility for the deprecated SetupWizard module
# All functionality has been moved to the new unified UserExperience module

# Find the new UserExperience module
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot
$userExperiencePath = Join-Path $projectRoot "aither-core/modules/UserExperience"

# Import the new unified module if available
$script:UserExperienceLoaded = $false
if (Test-Path $userExperiencePath) {
    try {
        Import-Module $userExperiencePath -Force -ErrorAction Stop
        $script:UserExperienceLoaded = $true
        Write-Warning "[DEPRECATED] SetupWizard module is deprecated. Functions are forwarded to UserExperience. Please update your scripts to use 'Import-Module UserExperience' instead."
    } catch {
        Write-Error "Failed to load SetupManager module: $_"
    }
} else {
    # Fallback to original module if new one doesn't exist yet
    $originalModulePath = Join-Path $projectRoot "aither-core/modules/SetupWizard"
    if (Test-Path $originalModulePath) {
        try {
            Import-Module $originalModulePath -Force -ErrorAction Stop
            $script:UserExperienceLoaded = $true
            Write-Warning "[COMPATIBILITY] Using legacy SetupWizard module. Please migrate to UserExperience when available."
        } catch {
            Write-Error "Failed to load legacy SetupWizard module: $_"
        }
    }
}

# Deprecation warning function
function Show-DeprecationWarning {
    param(
        [string]$FunctionName,
        [string]$NewFunction = $null,
        [string]$NewModule = "UserExperience"
    )
    
    $migrationMessage = if ($NewFunction) {
        "Use '$NewFunction' from the '$NewModule' module instead."
    } else {
        "Use the equivalent function from the '$NewModule' module instead."
    }
    
    Write-Warning "[DEPRECATED] $FunctionName is deprecated and will be removed in a future version. $migrationMessage"
    Write-Host "Migration Guide: https://github.com/AitherLabs/AitherZero/docs/migration/setup-wizard.md" -ForegroundColor Yellow
}

function Start-IntelligentSetup {
    <#
    .SYNOPSIS
        [DEPRECATED] Starts the intelligent setup wizard
    .DESCRIPTION
        This function is deprecated. Use Start-IntelligentSetup from UserExperience instead.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('minimal', 'developer', 'full', 'interactive')]
        [string]$InstallationProfile = 'interactive',
        [switch]$MinimalSetup,
        [switch]$SkipOptional,
        [switch]$ForceReinstall,
        [hashtable]$CustomSettings = @{}
    )
    
    Show-DeprecationWarning -FunctionName "Start-IntelligentSetup" -NewFunction "Start-IntelligentSetup"
    
    if ($script:UserExperienceLoaded) {
        if (Get-Command Start-IntelligentSetup -ErrorAction SilentlyContinue) {
            return Start-IntelligentSetup @PSBoundParameters
        }
    }
    
    throw "UserExperience module not available. Please ensure the module is installed."
}

function Generate-QuickStartGuide {
    <#
    .SYNOPSIS
        [DEPRECATED] Generates a quick start guide
    .DESCRIPTION
        This function is deprecated. Use Generate-QuickStartGuide from UserExperience instead.
    #>
    [CmdletBinding()]
    param(
        [string]$OutputPath,
        [string]$Platform,
        [hashtable]$SetupState = @{},
        [ValidateSet('markdown', 'html', 'text')]
        [string]$Format = 'markdown'
    )
    
    Show-DeprecationWarning -FunctionName "Generate-QuickStartGuide" -NewFunction "Generate-QuickStartGuide"
    
    if ($script:UserExperienceLoaded) {
        if (Get-Command Generate-QuickStartGuide -ErrorAction SilentlyContinue) {
            return Generate-QuickStartGuide @PSBoundParameters
        }
    }
    
    throw "UserExperience module not available. Please ensure the module is installed."
}

function Edit-Configuration {
    <#
    .SYNOPSIS
        [DEPRECATED] Interactive configuration editor
    .DESCRIPTION
        This function is deprecated. Use Edit-Configuration from UserExperience instead.
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigPath,
        [switch]$CreateIfMissing,
        [switch]$UseConfigurationCore
    )
    
    Show-DeprecationWarning -FunctionName "Edit-Configuration" -NewFunction "Edit-Configuration"
    
    if ($script:UserExperienceLoaded) {
        if (Get-Command Edit-Configuration -ErrorAction SilentlyContinue) {
            return Edit-Configuration @PSBoundParameters
        }
    }
    
    throw "UserExperience module not available. Please ensure the module is installed."
}

function Review-Configuration {
    <#
    .SYNOPSIS
        [DEPRECATED] Review configuration settings
    .DESCRIPTION
        This function is deprecated. Use Review-Configuration from UserExperience instead.
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigPath,
        [switch]$ShowDetails,
        [switch]$ValidateOnly
    )
    
    Show-DeprecationWarning -FunctionName "Review-Configuration" -NewFunction "Review-Configuration"
    
    if ($script:UserExperienceLoaded) {
        if (Get-Command Review-Configuration -ErrorAction SilentlyContinue) {
            return Review-Configuration @PSBoundParameters
        }
    }
    
    throw "UserExperience module not available. Please ensure the module is installed."
}

# Module initialization message
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║                    DEPRECATION NOTICE                       ║" -ForegroundColor Yellow
Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Yellow
Write-Host "║ SetupWizard module has been DEPRECATED                      ║" -ForegroundColor Red
Write-Host "║ This compatibility shim forwards calls to UserExperience    ║" -ForegroundColor Yellow
Write-Host "║                                                              ║" -ForegroundColor Yellow
Write-Host "║ Migration required:                                          ║" -ForegroundColor Cyan
Write-Host "║   Old: Import-Module SetupWizard                             ║" -ForegroundColor Gray
Write-Host "║   New: Import-Module UserExperience                          ║" -ForegroundColor Green
Write-Host "║                                                              ║" -ForegroundColor Yellow
Write-Host "║ Migration Guide:                                             ║" -ForegroundColor Cyan
Write-Host "║ https://github.com/AitherLabs/AitherZero/docs/migration/     ║" -ForegroundColor Blue
Write-Host "║   setup-wizard.md                                           ║" -ForegroundColor Blue
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""

# Export all functions for backward compatibility
Export-ModuleMember -Function @(
    'Start-IntelligentSetup',
    'Generate-QuickStartGuide',
    'Edit-Configuration',
    'Review-Configuration'
)