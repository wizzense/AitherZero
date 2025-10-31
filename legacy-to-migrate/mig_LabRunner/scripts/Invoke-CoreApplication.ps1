#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [object]$Config
)

# Source Find-ProjectRoot from relative path
. (Join-Path $PSScriptRoot (Join-Path ".." (Join-Path "shared" "Find-ProjectRoot.ps1")))
$projectRoot = Find-ProjectRoot -StartPath $PSScriptRoot
Import-Module (Join-Path $env:PWSH_MODULES_PATH "LabRunner") -Force
Import-Module (Join-Path $env:PWSH_MODULES_PATH "Logging") -Force

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"

# Load configuration
if (-not (Test-Path $ConfigPath)) {
    Write-CustomLog "Configuration file not found at $ConfigPath" -Level 'ERROR'
    throw "Configuration file not found at $ConfigPath"
}

try {
    $config = Get-Content $ConfigPath | ConvertFrom-Json

    Write-CustomLog "Starting core application: $($config.ApplicationName)"

    # Example operation
    Invoke-LabStep -Config $config -Body {
        Write-CustomLog 'Core application operation started.' -Level 'INFO'
        # Add core application logic here
        Write-CustomLog 'Core application operation completed successfully.' -Level 'INFO'
    }
} catch {
    Write-CustomLog "Core application operation failed: $($_.Exception.Message)" -Level 'ERROR'
    throw
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"

