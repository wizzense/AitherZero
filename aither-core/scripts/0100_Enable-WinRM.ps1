#Requires -Version 7.0

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [object]$Config
)

Import-Module "$env:PWSH_MODULES_PATH/LabRunner/" -Force
Import-Module "$env:PROJECT_ROOT/core-runner/modules/Logging" -Force

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"

Invoke-LabStep -Config $Config -Body {
    Write-CustomLog "Running $($MyInvocation.MyCommand.Name)"

    # Check if WinRM is already configured
    $winrmStatus = Get-Service -Name WinRM -ErrorAction SilentlyContinue

    if ($winrmStatus -and $winrmStatus.Status -eq 'Running') {
        Write-CustomLog 'WinRM is already enabled and running.'
    } else {
        Write-CustomLog 'Enabling WinRM via Enable-PSRemoting -Force'

        # WinRM QuickConfig
        Enable-PSRemoting -Force
        Write-CustomLog 'Enable-PSRemoting executed'

        # Optionally configure additional authentication methods, etc.:
        # e.g.: Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
    }
}

    Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
}

    Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
}
