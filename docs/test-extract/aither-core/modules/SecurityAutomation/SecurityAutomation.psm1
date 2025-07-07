#Requires -Version 7.0

<#
.SYNOPSIS
    Enterprise PowerShell security automation module for AitherZero.

.DESCRIPTION
    This module provides comprehensive security automation capabilities including:
    - Active Directory security management and assessment
    - Certificate Services automation and PKI management
    - Windows endpoint hardening and compliance
    - Network security configuration (Firewall, IPsec, DNS)
    - Remote administration security (PowerShell Remoting, JEA, WinRM)

.NOTES
    - Requires PowerShell 7.0+
    - Cross-platform compatible where applicable
    - Integrates with AitherZero logging and error handling
    - Adapted from enterprise security best practices
#>

# Import required modules
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot
Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force

# Import all public functions
$PublicFunctions = @()
$PublicDirectories = @('ActiveDirectory', 'CertificateServices', 'EndpointHardening', 'NetworkSecurity', 'RemoteAdministration')

foreach ($Directory in $PublicDirectories) {
    $PublicPath = Join-Path $PSScriptRoot "Public/$Directory"
    if (Test-Path $PublicPath) {
        Get-ChildItem -Path "$PublicPath/*.ps1" | ForEach-Object {
            . $_.FullName
            $PublicFunctions += $_.BaseName
        }
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

Write-CustomLog -Level 'INFO' -Message "SecurityAutomation module loaded successfully with $($PublicFunctions.Count) functions"