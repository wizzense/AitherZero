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

# Import the centralized Logging module
$loggingImported = $false

# Check if Logging module is already available
if (Get-Module -Name 'Logging' -ErrorAction SilentlyContinue) {
    $loggingImported = $true
    Write-Verbose "Logging module already available"
} else {
    $loggingPaths = @(
        'Logging',  # Try module name first (if in PSModulePath)
        (Join-Path (Split-Path $PSScriptRoot -Parent) "Logging"),  # Relative to modules directory
        (Join-Path $env:PWSH_MODULES_PATH "Logging"),  # Environment path
        (Join-Path $env:PROJECT_ROOT "core-runner/modules/Logging")  # Full project path
    )

    foreach ($loggingPath in $loggingPaths) {
        if ($loggingImported) { break }

        try {
            if ($loggingPath -eq 'Logging') {
                Import-Module 'Logging' -Global -ErrorAction Stop
            } elseif (Test-Path $loggingPath) {
                Import-Module $loggingPath -Global -ErrorAction Stop
            } else {
                continue
            }
            Write-Verbose "Successfully imported Logging module from: $loggingPath"
            $loggingImported = $true
        } catch {
            Write-Verbose "Failed to import Logging from $loggingPath : $_"
        }
    }
}

if (-not $loggingImported) {
    Write-Warning "Could not import Logging module from any of the attempted paths"
    # Fallback logging function
    function Write-CustomLog {
        param($Message, $Level = "INFO")
        $color = switch ($Level) {
            "SUCCESS" { "Green" }
            "WARN" { "Yellow" }
            "ERROR" { "Red" }
            default { "White" }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
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
