#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Creates license storage directory structure
    
.DESCRIPTION
    Creates the directory structure for storing license files locally.
    This is a single-purpose script focused only on directory creation.
    
    Stage: License Infrastructure
    Dependencies: None
    Tags: Security, Licensing, Infrastructure, Storage
    
.PARAMETER StoragePath
    Path for license storage (default: ~/.aitherzero/licenses)
    
.PARAMETER Force
    Overwrite existing directory structure
    
.EXAMPLE
    ./0870_Create-LicenseStorage.ps1
    
.EXAMPLE
    ./0870_Create-LicenseStorage.ps1 -StoragePath "/opt/licenses"
    
.NOTES
    Author: AitherZero Team
    Version: 1.0.0
    
    Single-purpose script following AitherZero architecture principles.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$StoragePath = "~/.aitherzero/licenses",
    
    [switch]$Force
)

# Script metadata
$script:ScriptName = "Create-LicenseStorage"
$script:ScriptVersion = "1.0.0"

function Write-ScriptOutput {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $color = @{
        'Info' = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error' = 'Red'
    }[$Level]
    
    $prefix = @{
        'Info' = 'ℹ'
        'Success' = '✓'
        'Warning' = '⚠'
        'Error' = '✗'
    }[$Level]
    
    Write-Host "$prefix $Message" -ForegroundColor $color
}

# Main script logic
try {
    Write-ScriptOutput "Creating license storage directory..." -Level 'Info'
    
    # Expand path
    $licenseDir = [System.IO.Path]::GetFullPath([System.Environment]::ExpandEnvironmentVariables($StoragePath))
    
    # Check if exists
    if (Test-Path $licenseDir) {
        if ($Force) {
            Write-ScriptOutput "Directory exists, Force specified" -Level 'Warning'
        } else {
            Write-ScriptOutput "Directory already exists: $licenseDir" -Level 'Success'
            exit 0
        }
    }
    
    # Create directory
    if ($PSCmdlet.ShouldProcess($licenseDir, "Create directory")) {
        New-Item -Path $licenseDir -ItemType Directory -Force | Out-Null
        Write-ScriptOutput "Created: $licenseDir" -Level 'Success'
    }
    
    # Verify
    if (Test-Path $licenseDir) {
        Write-ScriptOutput "Verification successful" -Level 'Success'
        Write-Host "`nStorage Path: $licenseDir" -ForegroundColor Cyan
        exit 0
    } else {
        throw "Failed to create directory"
    }
    
} catch {
    Write-ScriptOutput "Failed: $($_.Exception.Message)" -Level 'Error'
    exit 1
}
