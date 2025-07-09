#Requires -Version 7.0

<#
.SYNOPSIS
    Generalized secure credential management module for enterprise-wide use.

.DESCRIPTION
    This module provides comprehensive credential management capabilities for the entire
    AitherZero infrastructure automation project. It supports multiple credential types,
    secure storage, and integration with remote connection systems.

.NOTES
    - Cross-platform compatible (Windows, Linux, macOS)
    - Integrates with project logging system
    - Supports multiple credential backends
    - Enterprise-grade security features
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

Write-CustomLog -Level 'INFO' -Message "SecureCredentials module loaded successfully"
