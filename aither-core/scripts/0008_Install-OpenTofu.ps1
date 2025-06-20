#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [object]$Config
)

Import-Module "$env:PWSH_MODULES_PATH/LabRunner/" -Force
Import-Module "$env:PROJECT_ROOT/core-runner/modules/Logging" -Force

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"

function Install-OpenTofu {
    [CmdletBinding()]
    param(
        [object]$Config
    )

    Invoke-LabStep -Config $Config -Body {
        Write-CustomLog "Running $($MyInvocation.MyCommand.Name)"

        if ($Config.InstallOpenTofu -eq $true) {
            $Cosign = Join-Path $Config.CosignPath 'cosign-windows-amd64.exe'
            $openTofuVersion = if ($Config.OpenTofuVersion) { $Config.OpenTofuVersion } else { 'latest' }
            Invoke-OpenTofuInstaller -CosignPath $Cosign -OpenTofuVersion $openTofuVersion        
        } else {
            Write-CustomLog 'InstallOpenTofu flag is disabled. Skipping OpenTofu installation.'
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') { Install-OpenTofu @PSBoundParameters }
Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"




