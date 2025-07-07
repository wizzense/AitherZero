# ISOCustomizer Backward Compatibility Shim
# This module provides backward compatibility for the deprecated ISOCustomizer module
# All functionality has been moved to the new unified ISOManagement module

# Find the new ISOManagement module
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot
$isoManagementPath = Join-Path $projectRoot "aither-core/modules/ISOManagement"

# Import the new unified module if available
$script:ISOManagementLoaded = $false
if (Test-Path $isoManagementPath) {
    try {
        Import-Module $isoManagementPath -Force -ErrorAction Stop
        $script:ISOManagementLoaded = $true
        Write-Warning "[DEPRECATED] ISOCustomizer module is deprecated. Functions are forwarded to ISOManagement. Please update your scripts to use 'Import-Module ISOManagement' instead."
    } catch {
        Write-Error "Failed to load ISOManagement module: $_"
    }
} else {
    # Fallback to original module if new one doesn't exist yet
    $originalModulePath = Join-Path $projectRoot "aither-core/modules/ISOCustomizer"
    if (Test-Path $originalModulePath) {
        try {
            Import-Module $originalModulePath -Force -ErrorAction Stop
            $script:ISOManagementLoaded = $true
            Write-Warning "[COMPATIBILITY] Using legacy ISOCustomizer module. Please migrate to ISOManagement when available."
        } catch {
            Write-Error "Failed to load legacy ISOCustomizer module: $_"
        }
    }
}

# Deprecation warning function
function Show-DeprecationWarning {
    param(
        [string]$FunctionName,
        [string]$NewFunction = $null,
        [string]$NewModule = "ISOManagement"
    )
    
    $migrationMessage = if ($NewFunction) {
        "Use '$NewFunction' from the '$NewModule' module instead."
    } else {
        "Use the equivalent function from the '$NewModule' module instead."
    }
    
    Write-Warning "[DEPRECATED] $FunctionName is deprecated and will be removed in a future version. $migrationMessage"
    Write-Host "Migration Guide: https://github.com/AitherLabs/AitherZero/docs/migration/iso-customizer.md" -ForegroundColor Yellow
}

function New-CustomISO {
    <#
    .SYNOPSIS
        [DEPRECATED] Create a custom ISO image
    .DESCRIPTION
        This function is deprecated. Use New-CustomISO from ISOManagement instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,
        [Parameter(Mandatory)]
        [string]$OutputPath,
        [string]$AutounattendPath,
        [hashtable]$CustomFiles = @{},
        [string]$VolumeLabel,
        [switch]$Force
    )
    
    Show-DeprecationWarning -FunctionName "New-CustomISO" -NewFunction "New-CustomISO"
    
    if ($script:ISOManagementLoaded) {
        if (Get-Command New-CustomISO -ErrorAction SilentlyContinue) {
            return New-CustomISO @PSBoundParameters
        }
    }
    
    throw "ISOManagement module not available. Please ensure the module is installed."
}

function New-CustomISOWithProgress {
    <#
    .SYNOPSIS
        [DEPRECATED] Create a custom ISO image with progress tracking
    .DESCRIPTION
        This function is deprecated. Use New-CustomISOWithProgress from ISOManagement instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,
        [Parameter(Mandatory)]
        [string]$OutputPath,
        [string]$AutounattendPath,
        [hashtable]$CustomFiles = @{},
        [string]$VolumeLabel,
        [switch]$Force
    )
    
    Show-DeprecationWarning -FunctionName "New-CustomISOWithProgress" -NewFunction "New-CustomISOWithProgress"
    
    if ($script:ISOManagementLoaded) {
        if (Get-Command New-CustomISOWithProgress -ErrorAction SilentlyContinue) {
            return New-CustomISOWithProgress @PSBoundParameters
        }
    }
    
    throw "ISOManagement module not available. Please ensure the module is installed."
}

function New-AutounattendFile {
    <#
    .SYNOPSIS
        [DEPRECATED] Create an autounattend.xml file
    .DESCRIPTION
        This function is deprecated. Use New-AutounattendFile from ISOManagement instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OutputPath,
        [string]$ComputerName,
        [string]$AdminPassword,
        [string]$ProductKey,
        [hashtable]$Settings = @{}
    )
    
    Show-DeprecationWarning -FunctionName "New-AutounattendFile" -NewFunction "New-AutounattendFile"
    
    if ($script:ISOManagementLoaded) {
        if (Get-Command New-AutounattendFile -ErrorAction SilentlyContinue) {
            return New-AutounattendFile @PSBoundParameters
        }
    }
    
    throw "ISOManagement module not available. Please ensure the module is installed."
}

function New-AdvancedAutounattendFile {
    <#
    .SYNOPSIS
        [DEPRECATED] Create an advanced autounattend.xml file
    .DESCRIPTION
        This function is deprecated. Use New-AdvancedAutounattendFile from ISOManagement instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OutputPath,
        [Parameter(Mandatory)]
        [hashtable]$Configuration,
        [string]$Template = 'default'
    )
    
    Show-DeprecationWarning -FunctionName "New-AdvancedAutounattendFile" -NewFunction "New-AdvancedAutounattendFile"
    
    if ($script:ISOManagementLoaded) {
        if (Get-Command New-AdvancedAutounattendFile -ErrorAction SilentlyContinue) {
            return New-AdvancedAutounattendFile @PSBoundParameters
        }
    }
    
    throw "ISOManagement module not available. Please ensure the module is installed."
}

function Test-ISOIntegrity {
    <#
    .SYNOPSIS
        [DEPRECATED] Test ISO file integrity
    .DESCRIPTION
        This function is deprecated. Use Test-ISOIntegrity from ISOManagement instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$ExpectedHash,
        [ValidateSet('MD5', 'SHA1', 'SHA256', 'SHA512')]
        [string]$HashAlgorithm = 'SHA256'
    )
    
    Show-DeprecationWarning -FunctionName "Test-ISOIntegrity" -NewFunction "Test-ISOIntegrity"
    
    if ($script:ISOManagementLoaded) {
        if (Get-Command Test-ISOIntegrity -ErrorAction SilentlyContinue) {
            return Test-ISOIntegrity @PSBoundParameters
        }
    }
    
    throw "ISOManagement module not available. Please ensure the module is installed."
}

function Get-AutounattendTemplate {
    <#
    .SYNOPSIS
        [DEPRECATED] Get autounattend template
    .DESCRIPTION
        This function is deprecated. Use Get-AutounattendTemplate from ISOManagement instead.
    #>
    [CmdletBinding()]
    param(
        [string]$TemplateName = 'default',
        [switch]$ListAvailable
    )
    
    Show-DeprecationWarning -FunctionName "Get-AutounattendTemplate" -NewFunction "Get-AutounattendTemplate"
    
    if ($script:ISOManagementLoaded) {
        if (Get-Command Get-AutounattendTemplate -ErrorAction SilentlyContinue) {
            return Get-AutounattendTemplate @PSBoundParameters
        }
    }
    
    throw "ISOManagement module not available. Please ensure the module is installed."
}

function Get-BootstrapTemplate {
    <#
    .SYNOPSIS
        [DEPRECATED] Get bootstrap template
    .DESCRIPTION
        This function is deprecated. Use Get-BootstrapTemplate from ISOManagement instead.
    #>
    [CmdletBinding()]
    param(
        [string]$TemplateName = 'default',
        [switch]$ListAvailable
    )
    
    Show-DeprecationWarning -FunctionName "Get-BootstrapTemplate" -NewFunction "Get-BootstrapTemplate"
    
    if ($script:ISOManagementLoaded) {
        if (Get-Command Get-BootstrapTemplate -ErrorAction SilentlyContinue) {
            return Get-BootstrapTemplate @PSBoundParameters
        }
    }
    
    throw "ISOManagement module not available. Please ensure the module is installed."
}

function Get-KickstartTemplate {
    <#
    .SYNOPSIS
        [DEPRECATED] Get kickstart template
    .DESCRIPTION
        This function is deprecated. Use Get-KickstartTemplate from ISOManagement instead.
    #>
    [CmdletBinding()]
    param(
        [string]$TemplateName = 'default',
        [switch]$ListAvailable
    )
    
    Show-DeprecationWarning -FunctionName "Get-KickstartTemplate" -NewFunction "Get-KickstartTemplate"
    
    if ($script:ISOManagementLoaded) {
        if (Get-Command Get-KickstartTemplate -ErrorAction SilentlyContinue) {
            return Get-KickstartTemplate @PSBoundParameters
        }
    }
    
    throw "ISOManagement module not available. Please ensure the module is installed."
}

# Module initialization message
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║                    DEPRECATION NOTICE                       ║" -ForegroundColor Yellow
Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Yellow
Write-Host "║ ISOCustomizer module has been DEPRECATED                    ║" -ForegroundColor Red
Write-Host "║ This compatibility shim forwards calls to ISOManagement     ║" -ForegroundColor Yellow
Write-Host "║                                                              ║" -ForegroundColor Yellow
Write-Host "║ Migration required:                                          ║" -ForegroundColor Cyan
Write-Host "║   Old: Import-Module ISOCustomizer                           ║" -ForegroundColor Gray
Write-Host "║   New: Import-Module ISOManagement                           ║" -ForegroundColor Green
Write-Host "║                                                              ║" -ForegroundColor Yellow
Write-Host "║ Migration Guide:                                             ║" -ForegroundColor Cyan
Write-Host "║ https://github.com/AitherLabs/AitherZero/docs/migration/     ║" -ForegroundColor Blue
Write-Host "║   iso-customizer.md                                         ║" -ForegroundColor Blue
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""

# Export all functions for backward compatibility
Export-ModuleMember -Function @(
    'New-CustomISO',
    'New-CustomISOWithProgress',
    'New-AutounattendFile',
    'New-AdvancedAutounattendFile',
    'Test-ISOIntegrity',
    'Get-AutounattendTemplate',
    'Get-BootstrapTemplate',
    'Get-KickstartTemplate'
)