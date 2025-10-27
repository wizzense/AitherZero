#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Global launcher for AitherZero - callable from anywhere as 'aitherzero'
.DESCRIPTION
    This script acts as a global entry point for AitherZero, forwarding commands
    to the actual installation while handling environment setup.
.EXAMPLE
    aitherzero
    # Starts interactive mode
.EXAMPLE
    aitherzero -Mode Orchestrate -Sequence "0000-0099"
    # Runs orchestration sequence
#>

[CmdletBinding()]
param()

# Function to find AitherZero installation
function Find-AitherZeroInstallation {
    # Check environment variable first
    if ($env:AITHERZERO_ROOT -and (Test-Path "$env:AITHERZERO_ROOT/Start-AitherZero.ps1")) {
        return $env:AITHERZERO_ROOT
    }

    # Check common installation locations
    $possiblePaths = @()
    
    # Add user home paths
    $possiblePaths += Join-Path $HOME "AitherZero"
    $possiblePaths += Join-Path $HOME ".aitherzero"
    
    # Add platform-specific paths
    if ($IsLinux -or $IsMacOS) {
        $possiblePaths += "/opt/aitherzero"
    }
    
    if ($IsWindows) {
        $possiblePaths += "C:\Program Files\AitherZero"
        if ($env:LocalAppData) {
            $possiblePaths += Join-Path $env:LocalAppData "AitherZero"
        }
    }

    foreach ($path in $possiblePaths) {
        if ((Test-Path $path) -and (Test-Path (Join-Path $path "Start-AitherZero.ps1"))) {
            return $path
        }
    }

    # Check if we're in an AitherZero directory
    $currentPath = Get-Location
    if (Test-Path (Join-Path $currentPath "Start-AitherZero.ps1")) {
        return $currentPath.Path
    }

    # Walk up directory tree looking for AitherZero installation
    $checkPath = $currentPath
    while ($checkPath.Parent) {
        if (Test-Path (Join-Path $checkPath "Start-AitherZero.ps1")) {
            return $checkPath.Path
        }
        $checkPath = $checkPath.Parent
    }

    return $null
}

# Main execution
try {
    # Find AitherZero installation
    $aitherRoot = Find-AitherZeroInstallation

    if (-not $aitherRoot) {
        Write-Error @"
AitherZero installation not found!

Please ensure AitherZero is installed and either:
1. Set the AITHERZERO_ROOT environment variable to the installation path
2. Install AitherZero to one of the default locations:
   - ~/AitherZero (recommended)
   - ~/.aitherzero
   - /opt/aitherzero (Linux/macOS)
   - C:\Program Files\AitherZero (Windows)

To install AitherZero:
    iwr -useb https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1 | iex
"@
        exit 1
    }

    # Set environment variable if not set
    if (-not $env:AITHERZERO_ROOT) {
        $env:AITHERZERO_ROOT = $aitherRoot
    }

    # Build the path to Start-AitherZero.ps1
    $startScript = Join-Path $aitherRoot "Start-AitherZero.ps1"

    if (-not (Test-Path $startScript)) {
        Write-Error "Start-AitherZero.ps1 not found at: $startScript"
        exit 1
    }

    # Forward all arguments to Start-AitherZero.ps1
    # Use PowerShell's built-in argument passing with $args
    if ($args.Count -gt 0) {
        & $startScript @args
    } else {
        & $startScript
    }

    exit $LASTEXITCODE
} catch {
    Write-Error "Failed to launch AitherZero: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
}
