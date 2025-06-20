#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [object]$Config
)

Import-Module "$env:PWSH_MODULES_PATH/LabRunner/" -Force
Import-Module "$env:PROJECT_ROOT/core-runner/modules/Logging" -Force

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"

function Install-Poetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Config
    )

    Write-CustomLog "Running $($MyInvocation.MyCommand.Name)"

    if ($Config.InstallPoetry -eq $true) {
        if (-not (Get-Command poetry -ErrorAction SilentlyContinue)) {
            Write-CustomLog 'Installing Poetry...'

            # Download and install Poetry
            $url = 'https://install.python-poetry.org'

            try {
                if ($PSCmdlet.ShouldProcess('Poetry', 'Install package manager')) {
                    $response = Invoke-WebRequest -Uri $url -UseBasicParsing
                    $installScript = $response.Content

                    # Execute the install script
                    $args = @()
                    if ($Config.PoetryVersion) {
                        $env:POETRY_VERSION = $Config.PoetryVersion
                    }

                    Write-CustomLog 'Executing Poetry installer...'
                    Invoke-Expression $installScript
                }
                Write-CustomLog 'Poetry installation completed.'
            } catch {
                Write-CustomLog "Poetry installation failed: $_" -Level 'ERROR'
                throw
            }
        } else {
            Write-CustomLog 'Poetry is already installed.'
        }
    } else {
        Write-CustomLog 'InstallPoetry flag is disabled. Skipping installation.'
    }
}

Invoke-LabStep -Config $Config -Body {
    Install-Poetry -Config $Config
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
