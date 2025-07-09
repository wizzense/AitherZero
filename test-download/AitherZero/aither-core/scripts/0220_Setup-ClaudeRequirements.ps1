#Requires -Version 7.0

<#
.SYNOPSIS
    Sets up the Claude Requirements Gathering System for AitherZero.

.DESCRIPTION
    This script installs and configures the Claude Requirements Gathering System,
    providing an intelligent requirements gathering process for Claude Code.
    It integrates with the DevEnvironment module to set up all necessary components.

.PARAMETER ProjectRoot
    The root directory of the AitherZero project. Defaults to auto-detection.

.PARAMETER Force
    Force reinstallation even if the requirements system already exists.

.PARAMETER WhatIf
    Show what would be installed without actually installing anything.

.EXAMPLE
    ./0220_Setup-ClaudeRequirements.ps1

    Sets up the Claude Requirements System in the current project.

.NOTES
    This is a LabRunner script that can be executed through the AitherZero automation framework.
    It requires the DevEnvironment module to be available.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$ProjectRoot,

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$WhatIf
)

# Script configuration
$scriptName = "Setup-ClaudeRequirements"
$scriptVersion = "1.0.0"

# Import required modules
try {
    # Find project root if not provided
    if (-not $ProjectRoot) {
        . "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
        $ProjectRoot = Find-ProjectRoot
    }

    # Import Logging module
    Import-Module (Join-Path $ProjectRoot "aither-core/modules/Logging") -Force -ErrorAction Stop

    # Import DevEnvironment module
    Import-Module (Join-Path $ProjectRoot "aither-core/modules/DevEnvironment") -Force -ErrorAction Stop

    Write-CustomLog -Message "Starting $scriptName v$scriptVersion" -Level "INFO"
    Write-CustomLog -Message "Project Root: $ProjectRoot" -Level "INFO"

} catch {
    Write-Host "Failed to import required modules: $_" -ForegroundColor Red
    exit 1
}

# Main execution
try {
    # Check if Claude Requirements source exists
    $requirementsSource = Join-Path $ProjectRoot "claude-requirements"
    if (-not (Test-Path $requirementsSource)) {
        Write-CustomLog -Message "Claude Requirements source not found at: $requirementsSource" -Level "ERROR"
        Write-CustomLog -Message "Please ensure the claude-requirements directory exists in the project root" -Level "INFO"
        throw "Claude Requirements source directory not found"
    }

    # Test if system is already installed
    if (Test-ClaudeRequirementsSystem -ProjectRoot $ProjectRoot) {
        if (-not $Force) {
            Write-CustomLog -Message "Claude Requirements System is already installed" -Level "SUCCESS"
            Write-CustomLog -Message "Use -Force to reinstall" -Level "INFO"
            return
        }
        Write-CustomLog -Message "Force flag detected, reinstalling..." -Level "WARN"
    }

    # Install the requirements system
    Write-CustomLog -Message "Installing Claude Requirements Gathering System..." -Level "INFO"
    Install-ClaudeRequirementsSystem -ProjectRoot $ProjectRoot -Force:$Force -WhatIf:$WhatIf

    # Verify installation
    if (-not $WhatIf) {
        if (Test-ClaudeRequirementsSystem -ProjectRoot $ProjectRoot) {
            Write-CustomLog -Message "✅ Claude Requirements System installed and verified successfully!" -Level "SUCCESS"

            # Show usage instructions
            Write-CustomLog -Message "" -Level "INFO"
            Write-CustomLog -Message "=== Getting Started ===" -Level "INFO"
            Write-CustomLog -Message "1. Open Claude Code in this project" -Level "INFO"
            Write-CustomLog -Message "2. Use /requirements-start to begin gathering requirements" -Level "INFO"
            Write-CustomLog -Message "3. Example: /requirements-start add user authentication system" -Level "INFO"
            Write-CustomLog -Message "" -Level "INFO"
            Write-CustomLog -Message "For more information, see claude-requirements/README.md" -Level "INFO"

        } else {
            Write-CustomLog -Message "⚠️ Installation completed but verification failed" -Level "WARN"
            Write-CustomLog -Message "Please check the installation manually" -Level "INFO"
        }
    }

    Write-CustomLog -Message "$scriptName completed successfully" -Level "SUCCESS"

} catch {
    Write-CustomLog -Message "Failed to set up Claude Requirements System: $_" -Level "ERROR"
    Write-CustomLog -Message "Stack Trace: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
}

# Return success
exit 0
