#Requires -Version 7.0

<#
.SYNOPSIS
    Enterprise-grade ISO download, management, and organization module.

.DESCRIPTION
    This module provides comprehensive ISO file management capabilities for the entire
    AitherZero infrastructure automation project. It supports downloading from multiple
    sources, integrity verification, metadata management, and repository organization.

.NOTES
    - Cross-platform compatible (Windows, Linux, macOS)
    - Integrates with project logging system
    - Supports multiple download sources (Microsoft, Linux distributions, custom URLs)
    - Enterprise-grade validation and integrity checking
#>

# Write-CustomLog is guaranteed to be available from AitherCore orchestration
# No explicit Logging import needed - trust the orchestration system

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

# Export only public functions
Export-ModuleMember -Function $PublicFunctions

Write-CustomLog -Level 'INFO' -Message "ISOManager module loaded successfully"
