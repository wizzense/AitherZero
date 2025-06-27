#Requires -Version 7.0

<#
.SYNOPSIS
    One-command setup for OpenTofu Lab Automation environment

.DESCRIPTION
    Quickly sets up the development environment with all required modules and environment variables.
    This is a simplified version that focuses on the essentials.

.EXAMPLE
    .\Quick-Setup.ps1

.EXAMPLE
    .\Quick-Setup.ps1 -ImportAllModules
#>

[CmdletBinding()]
param(
    # No parameters needed - logic handled by Preload-Modules.ps1
)

# Import shared utilities and logging
try {
    . "$PSScriptRoot/../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    Import-Module "$projectRoot/aither-core/modules/Logging" -Force -ErrorAction SilentlyContinue
} catch {
    # Mock Write-CustomLog if Logging module is not available
    function Write-CustomLog {
        param([string]$Message, [string]$Level = "INFO")
        Write-Verbose "[$Level] $Message"
    }
}

Write-CustomLog -Level 'INFO' -Message "Setting up OpenTofu Lab Automation environment..."

# Set environment variables
$env:PROJECT_ROOT = (Get-Location).Path
$env:PWSH_MODULES_PATH = "$env:PROJECT_ROOT/aither-core/modules"

Write-CustomLog -Level 'SUCCESS' -Message "Environment variables configured"
Write-CustomLog -Level 'INFO' -Message "  PROJECT_ROOT: $env:PROJECT_ROOT"
Write-CustomLog -Level 'INFO' -Message "  PWSH_MODULES_PATH: $env:PWSH_MODULES_PATH"

# Import essential modules (logic handled by Preload-Modules.ps1)
Write-CustomLog -Level 'INFO' -Message "Importing modules..."

# Use the Preload-Modules script for consistent setup
& "$env:PROJECT_ROOT/core-runner/Preload-Modules.ps1"

Write-CustomLog -Level 'SUCCESS' -Message "Setup complete! You can now use:"
Write-CustomLog -Level 'INFO' -Message "  Import-Module PatchManager -Force"
Write-CustomLog -Level 'INFO' -Message "  Import-Module BackupManager -Force"
Write-CustomLog -Level 'INFO' -Message "  Or any other module without explicit paths!"
