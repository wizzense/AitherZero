#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter()]
    [object]$Config
)

Import-Module "$env:PWSH_MODULES_PATH/LabRunner" -Force
Import-Module "$env:PWSH_MODULES_PATH/Logging" -Force

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"

Invoke-LabStep -Config $Config -Body {
    Write-CustomLog "Running $($MyInvocation.MyCommand.Name)"

    # Initialize OpenTofu in the infrastructure directory
    $infraPath = if ($Config.InfraRepoPath) { $Config.InfraRepoPath } else { 'C:/Temp/base-infra' }
    $tofuPath = Join-Path $infraPath "opentofu"
    
    if (-not (Test-Path $tofuPath)) {
        Write-CustomLog "OpenTofu directory not found at $tofuPath"
        return
    }

    Push-Location $tofuPath
    try {
        Write-CustomLog "Initializing OpenTofu..."
        & tofu init
        if ($LASTEXITCODE -eq 0) {
            Write-CustomLog "OpenTofu initialized successfully"
        } else {
            Write-CustomLog -Level 'ERROR' -Message "Failed to initialize OpenTofu"
        }
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Error initializing OpenTofu: $($_.Exception.Message)"
    } finally {
        Pop-Location
    }

    Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
