#Requires -Version 7.0

<#
.SYNOPSIS
    Runnable script to install Claude Code dependencies using DevEnvironment module.

.DESCRIPTION
    This script provides a simple entry point to install all Claude Code dependencies
    using the DevEnvironment module's Install-ClaudeCodeDependencies function.

    Supports both Windows (with WSL) and Linux installations.

.PARAMETER WSLUsername
    Username for WSL Ubuntu installation on Windows.

.PARAMETER SkipWSL
    Skip WSL installation on Windows (assumes already installed).

.PARAMETER Force
    Force reinstallation even if components exist.

.PARAMETER WhatIf
    Preview what would be installed without making changes.

.EXAMPLE
    ./0217_Install-ClaudeCode.ps1 -WSLUsername "developer"

.EXAMPLE
    ./0217_Install-ClaudeCode.ps1 -SkipWSL

.EXAMPLE
    ./0217_Install-ClaudeCode.ps1 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$WSLUsername,

    [Parameter()]
    [switch]$SkipWSL,

    [Parameter()]
    [switch]$Force
)

begin {
    # Use shared utility for project root detection
    . "$PSScriptRoot/../shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot

    # Load utilities domain with consolidated AI tools functions
    . (Join-Path $projectRoot "aither-core/domains/utilities/Utilities.ps1")

    Write-Host "Claude Code Dependencies Installation" -ForegroundColor Cyan
    Write-Host "Using consolidated utilities domain for installation..." -ForegroundColor Yellow
}

process {
    try {
        # Build parameters for the function call
        $installParams = @{
            NodeVersion = 'lts'
        }

        if ($WSLUsername) {
            $installParams['WSLUsername'] = $WSLUsername
        }

        if ($SkipWSL) {
            $installParams['SkipWSL'] = $true
        }

        if ($Force) {
            $installParams['Force'] = $true
        }

        if ($WhatIf) {
            $installParams['WhatIf'] = $true
        }

        # Call the DevEnvironment module function
        Install-ClaudeCodeDependencies @installParams

        if (-not $WhatIf) {
            Write-Host "" -ForegroundColor Green
            Write-Host "✅ Claude Code dependencies installation completed!" -ForegroundColor Green
            Write-Host "" -ForegroundColor Green
            Write-Host "Next steps:" -ForegroundColor Cyan
            Write-Host "1. Open a new terminal/shell session" -ForegroundColor White
            Write-Host "2. Verify installation: claude-code --version" -ForegroundColor White
            Write-Host "3. Start using Claude Code for development!" -ForegroundColor White
        }

    } catch {
        Write-Error "Failed to install Claude Code dependencies: $($_.Exception.Message)"
        throw
    }
}
