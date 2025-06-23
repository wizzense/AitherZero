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

    if (-not $Config.InstallSysinternals) {
        Write-CustomLog 'InstallSysinternals flag is disabled. Skipping installation.'
        return
    }

    $destDir = if ($Config.SysinternalsPath) { 
        $Config.SysinternalsPath 
    } else { 
        'C:/Sysinternals' 
    }
    
    if (-not (Test-Path $destDir)) {
        Write-CustomLog "Installing Sysinternals to $destDir"
        $url = 'https://download.sysinternals.com/files/SysinternalsSuite.zip'
        
        Invoke-LabDownload -Uri $url -Prefix 'sysinternals' -Extension '.zip' -Action {
            param($zipPath)
            
            if ($PSCmdlet.ShouldProcess($destDir, 'Create Sysinternals directory')) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            
            Write-CustomLog "Extracting to $destDir"
            if ($PSCmdlet.ShouldProcess($zipPath, 'Extract Sysinternals')) {
                Expand-Archive -Path $zipPath -DestinationPath $destDir -Force
            }
        }
        
        # Add to PATH
        $env:PATH = "$env:PATH;$destDir"
        Write-CustomLog 'Sysinternals installation completed.'
    } else {
        Write-CustomLog "Sysinternals is already installed at $destDir"
    }

    $psInfo = Join-Path $destDir 'PsInfo.exe'
    if (Test-Path $psInfo) {
        Write-CustomLog 'Verifying PsInfo.exe installation'
        Write-CustomLog "PsInfo.exe found at $psInfo"
    } else {
        Write-CustomLog 'PsInfo.exe not found after installation' -Level 'WARN'
    }
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
