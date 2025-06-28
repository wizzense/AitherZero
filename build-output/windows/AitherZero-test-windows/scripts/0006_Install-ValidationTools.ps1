#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter()]
    [object]$Config
)

Import-Module (Join-Path $env:PROJECT_ROOT (Join-Path "aither-core" (Join-Path "modules" "LabRunner"))) -Force
Import-Module (Join-Path $env:PROJECT_ROOT (Join-Path "aither-core" (Join-Path "modules" "Logging"))) -Force

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"

Invoke-LabStep -Config $Config -Body {
    Write-CustomLog "Running $($MyInvocation.MyCommand.Name)"

    # Install validation tools needed for the lab environment
    $tools = @(
        'PSScriptAnalyzer',
        'Pester'
    )

    foreach ($tool in $tools) {
        try {
            if (-not (Get-Module -ListAvailable -Name $tool)) {
                Write-CustomLog "Installing $tool..."
                Install-Module -Name $tool -Force -AllowClobber -Scope CurrentUser
                Write-CustomLog "Successfully installed $tool"
            } else {
                Write-CustomLog "$tool is already installed"
            }
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to install $tool : $($_.Exception.Message)"
        }
    }

    Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
