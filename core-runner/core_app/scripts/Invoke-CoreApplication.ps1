#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [object]$Config
)

Import-Module "$env:PWSH_MODULES_PATH/LabRunner/" -Force
Import-Module "$env:PROJECT_ROOT/core-runner/modules/Logging" -Force

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
