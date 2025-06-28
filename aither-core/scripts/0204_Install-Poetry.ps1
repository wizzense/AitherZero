#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [object]$Config
)

# Source Find-ProjectRoot from relative path
. (Join-Path $PSScriptRoot (Join-Path ".." (Join-Path "shared" "Find-ProjectRoot.ps1")))
$projectRoot = Find-ProjectRoot -StartPath $PSScriptRoot
Import-Module (Join-Path $projectRoot (Join-Path "aither-core" (Join-Path "modules" "LabRunner"))) -Force
Import-Module (Join-Path $projectRoot (Join-Path "aither-core" (Join-Path "modules" "Logging"))) -Force

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
