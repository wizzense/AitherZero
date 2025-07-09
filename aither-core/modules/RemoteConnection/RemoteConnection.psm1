#Requires -Version 7.0

<#
.SYNOPSIS
    Generalized remote connection management module for enterprise-wide use.

.DESCRIPTION
    This module provides comprehensive remote connection capabilities for the entire
    AitherZero infrastructure automation project. It supports multiple connection types,
    secure authentication, and integration with credential management systems.

.NOTES
    - Cross-platform compatible (Windows, Linux, macOS)
    - Integrates with SecureCredentials module
    - Supports SSH, WinRM, VMware, Hyper-V, Docker, Kubernetes
    - Enterprise-grade connection management
#>

# Initialize standardized logging fallback
$fallbackPath = Join-Path (Split-Path $PSScriptRoot -Parent) "shared/Initialize-LoggingFallback.ps1"
if (Test-Path $fallbackPath) {
    . $fallbackPath
    Initialize-LoggingFallback -ModuleName "RemoteConnection"
} else {
    # Basic fallback if shared utility isn't available
    if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
        function Write-CustomLog {
            param([string]$Message, [string]$Level = "INFO")
            $color = switch ($Level) { 'SUCCESS' { 'Green' }; 'ERROR' { 'Red' }; 'WARNING' { 'Yellow' }; 'INFO' { 'Cyan' }; default { 'White' } }
            Write-Host "[$Level] $Message" -ForegroundColor $color
        }
    }
}

# Try to import full Logging module if available
try {
    Import-Module (Join-Path $PSScriptRoot '../Logging/Logging.psm1') -Force -ErrorAction SilentlyContinue
} catch {
    # Fall back to our standardized logging fallback
}

# Import SecureCredentials if not already loaded
if (-not (Get-Module SecureCredentials -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $PSScriptRoot '../SecureCredentials/SecureCredentials.psm1') -Force
}

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

Write-CustomLog -Level 'INFO' -Message "RemoteConnection module loaded successfully"
