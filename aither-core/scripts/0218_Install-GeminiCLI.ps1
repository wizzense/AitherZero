#Requires -Version 7.0

<#
.SYNOPSIS
    Runnable script to install Gemini CLI dependencies using DevEnvironment module.

.DESCRIPTION
    This script provides a simple entry point to install all Gemini CLI dependencies
    using the DevEnvironment module's Install-GeminiCLIDependencies function.
    
    Supports both Windows (with WSL) and Linux installations.

.PARAMETER WSLUsername
    Username for WSL Ubuntu installation on Windows.

.PARAMETER SkipWSL
    Skip WSL installation on Windows (assumes already installed).

.PARAMETER SkipNodeInstall
    Skip Node.js installation (assumes already installed).

.PARAMETER Force
    Force reinstallation even if components exist.

.PARAMETER WhatIf
    Preview what would be installed without making changes.

.EXAMPLE
    ./0218_Install-GeminiCLI.ps1 -WSLUsername "developer"
    
.EXAMPLE
    ./0218_Install-GeminiCLI.ps1 -SkipWSL -SkipNodeInstall

.EXAMPLE
    ./0218_Install-GeminiCLI.ps1 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$WSLUsername,
    
    [Parameter()]
    [switch]$SkipWSL,
    
    [Parameter()]
    [switch]$SkipNodeInstall,
    
    [Parameter()]
    [switch]$Force
)

begin {
    # Use shared utility for project root detection
    . "$PSScriptRoot/../shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    
    # Import DevEnvironment module
    $devEnvModulePath = Join-Path $projectRoot "aither-core/modules/DevEnvironment"
    Import-Module $devEnvModulePath -Force
    
    Write-Host "🧠 Gemini CLI Dependencies Installation" -ForegroundColor Cyan
    Write-Host "Using DevEnvironment module for installation..." -ForegroundColor Yellow
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
        
        if ($SkipNodeInstall) {
            $installParams['SkipNodeInstall'] = $true
        }
        
        if ($Force) {
            $installParams['Force'] = $true
        }
        
        if ($WhatIf) {
            $installParams['WhatIf'] = $true
        }
        
        # Call the DevEnvironment module function
        Install-GeminiCLIDependencies @installParams
        
        if (-not $WhatIf) {
            Write-Host "" -ForegroundColor Green
            Write-Host "✅ Gemini CLI dependencies installation completed!" -ForegroundColor Green
            Write-Host "" -ForegroundColor Green
            Write-Host "Next steps:" -ForegroundColor Cyan
            Write-Host "1. Open a new terminal/shell session" -ForegroundColor White
            Write-Host "2. Run: gemini" -ForegroundColor White
            Write-Host "3. Authenticate with your Google account when prompted" -ForegroundColor White
            Write-Host "4. Optional: Set GEMINI_API_KEY environment variable for API access" -ForegroundColor White
            Write-Host "5. Visit https://aistudio.google.com to generate an API key if needed" -ForegroundColor White
        }
        
    } catch {
        Write-Error "Failed to install Gemini CLI dependencies: $($_.Exception.Message)"
        throw
    }
}
