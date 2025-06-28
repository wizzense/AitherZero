#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Installs Codex CLI (OpenAI's experimental CLI) and all required dependencies.

.DESCRIPTION
    This script provides a standalone way to install Codex CLI and its dependencies
    including Node.js via nvm. It automatically detects the platform (Windows/Linux/macOS)
    and installs the appropriate components.

.PARAMETER WSLUsername
    For Windows: Username to create in WSL Ubuntu. Required for new WSL installations.

.PARAMETER SkipWSL
    For Windows: Skip WSL installation and use native Windows installation.

.PARAMETER Force
    Force reinstallation of components even if they already exist.

.PARAMETER WhatIf
    Show what would be installed without actually installing anything.

.EXAMPLE
    ./0219_Install-Codex.ps1 -WSLUsername "developer"

    Installs Codex CLI with WSL setup on Windows.

.EXAMPLE
    ./0219_Install-Codex.ps1 -SkipWSL

    Installs Codex CLI on Windows without WSL (assumes WSL already configured).

.EXAMPLE
    ./0219_Install-Codex.ps1

    Installs Codex CLI on Linux/macOS.

.NOTES
    Author: AitherZero Infrastructure Automation
    Requires: PowerShell 7.0+, Internet connection

    On Windows: Requires Administrator privileges for WSL installation
    On Linux/macOS: Can run as regular user

    Post-installation:
    1. Set up OpenAI API key: export OPENAI_API_KEY='your-api-key-here'
    2. Get API key from: https://platform.openai.com/api-keys
    3. Test with: codex --help
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$WSLUsername,

    [Parameter()]
    [switch]$SkipWSL,

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$WhatIf
)

begin {
    $ErrorActionPreference = 'Stop'

    # Import shared utilities for project root detection
    . "$PSScriptRoot/../shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot

    # Import required modules
    Import-Module (Join-Path $env:PWSH_MODULES_PATH "Logging") -Force
    Import-Module (Join-Path $projectRoot (Join-Path "aither-core" (Join-Path "modules" "DevEnvironment"))) -Force

    Write-CustomLog -Level 'INFO' -Message "=== Codex CLI Installation Script ==="
    Write-CustomLog -Level 'INFO' -Message "Script: $($MyInvocation.MyCommand.Name)"
    Write-CustomLog -Level 'INFO' -Message "Project Root: $projectRoot"

    # Platform detection
    $platformIsWindows = $PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows
    $platformIsLinux = $PSVersionTable.PSVersion.Major -ge 6 -and $IsLinux
    $platformIsMacOS = $PSVersionTable.PSVersion.Major -ge 6 -and $IsMacOS

    if (-not ($platformIsWindows -or $platformIsLinux -or $platformIsMacOS)) {
        # PowerShell 5.1 or other - assume Windows
        $platformIsWindows = $true
    }

    Write-CustomLog -Level 'INFO' -Message "Detected Platform: Windows=$platformIsWindows, Linux=$platformIsLinux, macOS=$platformIsMacOS"
}

process {
    try {
        Write-CustomLog -Level 'INFO' -Message "Starting Codex CLI installation process..."

        # Prepare parameters for the DevEnvironment function
        $installParams = @{
            Force = $Force
            WhatIf = $WhatIf
        }

        # Add Windows-specific parameters
        if ($platformIsWindows) {
            if ($SkipWSL) {
                $installParams.SkipWSL = $true
                Write-CustomLog -Level 'INFO' -Message "WSL installation will be skipped"
            } else {
                if (-not $WSLUsername) {
                    Write-CustomLog -Level 'ERROR' -Message "WSLUsername parameter is required for Windows installation with WSL"
                    Write-CustomLog -Level 'INFO' -Message "Usage: $($MyInvocation.MyCommand.Name) -WSLUsername 'your-username'"
                    Write-CustomLog -Level 'INFO' -Message "Or use -SkipWSL to skip WSL installation"
                    throw "WSLUsername parameter is required"
                }
                $installParams.WSLUsername = $WSLUsername
                Write-CustomLog -Level 'INFO' -Message "WSL will be configured with username: $WSLUsername"
            }
        }

        if ($WhatIf) {
            Write-CustomLog -Level 'INFO' -Message "WhatIf mode enabled - no actual installation will occur"
        }

        # Execute the installation
        Write-CustomLog -Level 'INFO' -Message "Calling Install-CodexCLIDependencies with parameters..."
        Install-CodexCLIDependencies @installParams

        Write-CustomLog -Level 'SUCCESS' -Message "Codex CLI installation completed successfully!"

        # Provide post-installation guidance
        Write-CustomLog -Level 'INFO' -Message ""
        Write-CustomLog -Level 'INFO' -Message "=== Next Steps ==="
        Write-CustomLog -Level 'INFO' -Message "1. Set up your OpenAI API key:"

        if ($isWindows -and -not $SkipWSL) {
            Write-CustomLog -Level 'INFO' -Message "   In WSL: echo 'export OPENAI_API_KEY=\"your-api-key-here\"' >> ~/.bashrc"
            Write-CustomLog -Level 'INFO' -Message "   Then: source ~/.bashrc"
        } else {
            Write-CustomLog -Level 'INFO' -Message "   export OPENAI_API_KEY='your-api-key-here'"
        }

        Write-CustomLog -Level 'INFO' -Message "2. Get your API key from: https://platform.openai.com/api-keys"
        Write-CustomLog -Level 'INFO' -Message "3. Test the installation:"

        if ($isWindows -and -not $SkipWSL) {
            Write-CustomLog -Level 'INFO' -Message "   wsl bash -c 'source ~/.nvm/nvm.sh && codex --help'"
        } else {
            Write-CustomLog -Level 'INFO' -Message "   bash -c 'source ~/.nvm/nvm.sh && codex --help'"
        }

        Write-CustomLog -Level 'INFO' -Message ""
        Write-CustomLog -Level 'SUCCESS' -Message "Codex CLI is ready for use!"

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Codex CLI installation failed: $($_.Exception.Message)"
        Write-CustomLog -Level 'ERROR' -Message "Stack trace: $($_.ScriptStackTrace)"

        Write-CustomLog -Level 'INFO' -Message ""
        Write-CustomLog -Level 'INFO' -Message "=== Troubleshooting ==="
        Write-CustomLog -Level 'INFO' -Message "1. Check the error message above for specific issues"
        Write-CustomLog -Level 'INFO' -Message "2. Ensure you have internet connectivity"

        if ($platformIsWindows) {
            Write-CustomLog -Level 'INFO' -Message "3. On Windows, ensure you're running as Administrator (unless using -SkipWSL)"
            Write-CustomLog -Level 'INFO' -Message "4. Check Windows version: Windows 10 2004+ or Windows 11 required for WSL2"
        }

        Write-CustomLog -Level 'INFO' -Message "5. Try running with -WhatIf to see what would be installed"
        Write-CustomLog -Level 'INFO' -Message "6. Check logs for more detailed error information"

        throw
    }
}

end {
    Write-CustomLog -Level 'INFO' -Message "Codex CLI installation script completed"
}

