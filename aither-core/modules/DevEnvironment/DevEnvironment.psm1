#Requires -Version 7.0

<#
.SYNOPSIS
    DevEnvironment module for OpenTofu Lab Automation

.DESCRIPTION
    Provides functions for setting up and managing the development environment,
    including Git hooks, development tools, and workspace configuration.

.NOTES
    This module integrates development environment setup into the core project workflow.
#>

# Initialize standardized logging fallback
$fallbackPath = Join-Path (Split-Path $PSScriptRoot -Parent) "shared/Initialize-LoggingFallback.ps1"
if (Test-Path $fallbackPath) {
    . $fallbackPath
    Initialize-LoggingFallback -ModuleName "DevEnvironment"
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

# Import public functions
$Public = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue)

# Dot source the files
foreach ($import in @($Public + $Private)) {
    try {
        . $import.FullName
        Write-Verbose "Imported function: $($import.BaseName)"
    }
    catch {
        Write-Error "Failed to import function $($import.FullName): $($_.Exception.Message)"
    }
}

# Export only the public functions
if ($Public.Count -gt 0) {
    $functionNames = $Public.BaseName
    Export-ModuleMember -Function $functionNames
    Write-Verbose "Exported DevEnvironment functions: $($functionNames -join ', ')"
} else {
    Write-Warning "No public functions found to export in $PSScriptRoot\Public\"
}
