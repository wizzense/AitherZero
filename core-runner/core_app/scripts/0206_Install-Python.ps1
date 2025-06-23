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
    
    if ($Config.InstallPython -eq $true) {
        if (-not (Get-Command python.exe -ErrorAction SilentlyContinue)) {
            Write-CustomLog "Installing Python..."
            $url = 'https://www.python.org/ftp/python/3.12.3/python-3.12.3-amd64.exe'
            
            Invoke-LabDownload -Uri $url -Prefix 'python-installer' -Extension '.exe' -Action {
                param($installer)
                if ($PSCmdlet.ShouldProcess($installer, 'Install Python')) {
                    Start-Process -FilePath $installer -ArgumentList '/quiet InstallAllUsers=1 PrependPath=1' -Wait
                    
                    # Refresh PATH for the current session
                    $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
                    $machinePath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
                    $env:PATH = (($userPath, $machinePath) -join ';')
                    Write-CustomLog 'PATH refreshed with new Python location.'
                }
            }
            Write-CustomLog "Python installation completed."
        } else {
            Write-CustomLog "Python is already installed."
        }
    } else {
        Write-CustomLog "InstallPython flag is disabled. Skipping installation."
    }
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
