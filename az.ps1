#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Lightweight wrapper script for executing AitherZero automation scripts

.DESCRIPTION
    The 'az' wrapper provides quick access to numbered automation scripts (0000-9999).
    This standalone script works without requiring the full AitherZero module to be loaded.
    
    In containers, this script can be called directly:
        ./az.ps1 0402
    
    When the AitherZero module is loaded, the 'az' alias is also available:
        az 0402

.PARAMETER ScriptNumber
    The automation script number to execute (0000-9999)
    Script numbers can be 3 or 4 digits

.PARAMETER Arguments
    Additional arguments to pass to the script

.EXAMPLE
    ./az.ps1 0402
    Run unit tests (script 0402)

.EXAMPLE
    ./az.ps1 0404
    Run PSScriptAnalyzer (script 0404)

.EXAMPLE
    ./az.ps1 0510 -ShowAll
    Generate project report with all details (script 0510)

.EXAMPLE
    ./az.ps1 0854 -Action Shell -PRNumber 1677
    Open interactive shell in PR container

.NOTES
    Script Name: az.ps1
    Purpose: Standalone wrapper for AitherZero automation scripts
    Location: Project root (works in containers at /opt/aitherzero/az.ps1)
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidatePattern('^\d{3,4}$')]
    [string]$ScriptNumber,
    
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Determine AitherZero root directory
$aitherZeroRoot = if ($env:AITHERZERO_ROOT) {
    $env:AITHERZERO_ROOT
} elseif ($PSScriptRoot) {
    $PSScriptRoot
} else {
    Get-Location
}

# Locate the automation script
$scriptPath = Join-Path $aitherZeroRoot "automation-scripts"

if (-not (Test-Path $scriptPath)) {
    Write-Error "Automation scripts directory not found: $scriptPath"
    exit 1
}

# Find matching script (handles both 3 and 4 digit patterns)
$scripts = @(Get-ChildItem -Path $scriptPath -Filter "${ScriptNumber}*.ps1" -ErrorAction SilentlyContinue)

if ($scripts.Count -eq 0) {
    Write-Error "No script found matching pattern: ${ScriptNumber}*.ps1 in $scriptPath"
    Write-Host "`nAvailable scripts:" -ForegroundColor Yellow
    Get-ChildItem -Path $scriptPath -Filter "*.ps1" | Select-Object -First 10 | ForEach-Object {
        Write-Host "  $($_.Name)" -ForegroundColor Gray
    }
    exit 1
}

if ($scripts.Count -gt 1) {
    Write-Error "Multiple scripts found matching pattern: ${ScriptNumber}*.ps1"
    Write-Host "`nMatching scripts:" -ForegroundColor Yellow
    $scripts | ForEach-Object {
        Write-Host "  $($_.Name)" -ForegroundColor Gray
    }
    exit 1
}

# Execute the script
$scriptFile = $scripts[0].FullName

Write-Verbose "Executing: $scriptFile"
Write-Verbose "Arguments: $($Arguments -join ' ')"

try {
    if ($null -ne $Arguments -and $Arguments.Count -gt 0) {
        # Convert arguments array to actual parameters
        # This properly handles switches and parameter values
        $invokeCommand = "& `$scriptFile $($Arguments -join ' ')"
        Invoke-Expression $invokeCommand
    } else {
        # Execute without arguments
        & $scriptFile
    }
    
    # Preserve exit code
    exit $LASTEXITCODE
} catch {
    Write-Error "Failed to execute script: $_"
    exit 1
}
