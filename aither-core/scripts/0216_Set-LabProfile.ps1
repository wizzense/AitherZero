#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [object]$Config
)

Import-Module "$env:PWSH_MODULES_PATH/LabRunner/" -Force
Import-Module "$env:PROJECT_ROOT/core-runner/modules/Logging" -Force

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"

function Set-LabProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Config
    )

    Write-CustomLog "Running $($MyInvocation.MyCommand.Name)"

    if ($Config.SetupLabProfile -eq $true) {
        $profilePath = $PROFILE.CurrentUserAllHosts
        $profileDir = Split-Path $profilePath

        if (-not (Test-Path $profileDir)) {
            if ($PSCmdlet.ShouldProcess($profileDir, 'Create profile directory')) {
                New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
            }
        }

        $repoRoot = Resolve-Path -Path (Join-Path $PSScriptRoot '..')
        $content = @"
# OpenTofu Lab Automation profile
`$env:PATH = "$repoRoot;`$env:PATH"
`$env:PSModulePath = "$repoRoot/core-runner/modules;`$env:PSModulePath"
"@

        if ($PSCmdlet.ShouldProcess($profilePath, 'Create PowerShell profile')) {
            Set-Content -Path $profilePath -Value $content
            Write-CustomLog "PowerShell profile created at $profilePath"
        }
    } else {
        Write-CustomLog "SetupLabProfile flag is disabled. Skipping profile setup."
    }
}

Invoke-LabStep -Config $Config -Body {
    Set-LabProfile -Config $Config
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
