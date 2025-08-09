#Requires -Version 7.0

<#
.SYNOPSIS
    Enterprise-grade ISO customization and autounattend file generation module.

.DESCRIPTION
    This module provides comprehensive ISO customization capabilities for the entire
    AitherZero infrastructure automation project. It supports mounting and modifying
    Windows ISOs, generating autounattend files from configurations, injecting scripts
    and drivers, and creating bootable custom ISOs for automated deployments.

.NOTES
    - Cross-platform compatible (Windows primarily, with some Linux support)
    - Integrates with project logging and configuration systems
    - Supports Windows ADK/DISM operations
    - Enterprise-grade deployment automation
#>

# Import required modules
Import-Module (Join-Path $PSScriptRoot '../Logging/Logging.psm1') -Force

# Import all public functions
$PublicFunctions = @()
if (Test-Path (Join-Path $PSScriptRoot 'Public')) {
    Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public/*.ps1') | ForEach-Object {
        . $_.FullName
        $PublicFunctions += $_.BaseName
    }
}

# Import all private functions
if (Test-Path (Join-Path $PSScriptRoot 'Private')) {
    Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private/*.ps1') | ForEach-Object {
        . $_.FullName
    }
}

# Export public functions and specific template helpers
$TemplateHelpers = @('Get-AutounattendTemplate', 'Get-BootstrapTemplate', 'Get-KickstartTemplate')
Export-ModuleMember -Function ($PublicFunctions + $TemplateHelpers)

Write-CustomLog -Level 'INFO' -Message "ISOCustomizer module loaded successfully"