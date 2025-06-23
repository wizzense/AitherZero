#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [object]$Config
)

Import-Module "$env:PWSH_MODULES_PATH/LabRunner/" -Force
Import-Module "$env:PROJECT_ROOT/core-runner/modules/Logging" -Force

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"

function Get-WacRegistryInstallation {
    [CmdletBinding()
    param(
        [Parameter(Mandatory)]
        [string]$RegistryPath
    )
    
    $items = Get-ChildItem $RegistryPath -ErrorAction SilentlyContinue
    foreach ($item in $items) {
        $itemProps = Get-ItemProperty $item.PSPath -ErrorAction SilentlyContinue
        if ($itemProps.PSObject.Properties['DisplayName'] -and $itemProps.DisplayName -like "*Windows Admin Center*") {
            return $itemProps
        }
    }
    return $null
}

Invoke-LabStep -Config $Config -Body {
    Write-CustomLog "Running $($MyInvocation.MyCommand.Name)"
    
    if ($Config.InstallWAC -eq $true) {
        $WacConfig = $Config.WindowsAdminCenter
        if (-not $WacConfig) {
            Write-CustomLog 'No Windows Admin Center configuration found. Skipping installation.'
            return
        }
        
        $installPort = if ($WacConfig.InstallPort) { $WacConfig.InstallPort } else { 443 }

        # Check both standard and Wow6432Node uninstall registry keys for WAC installation
        $wacInstalled = Get-WacRegistryInstallation -RegistryPath "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
        if (-not $wacInstalled) {
            $wacInstalled = Get-WacRegistryInstallation -RegistryPath "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        }

        if ($wacInstalled) {
            Write-CustomLog "Windows Admin Center is already installed. Skipping installation."
            return
        }

        # Check if the desired installation port is already in use
        $portInUse = Get-NetTCPConnection -LocalPort $installPort -ErrorAction SilentlyContinue
        if ($portInUse) {
            Write-CustomLog "Port $installPort is already in use. Assuming Windows Admin Center is running. Skipping installation."
            return
        }

        Write-CustomLog "Installing Windows Admin Center..."
        
        $url = if ($WacConfig.InstallerUrl) { 
            $WacConfig.InstallerUrl 
        } else { 
            'https://aka.ms/WACDownload' 
        }
        
        Invoke-LabDownload -Uri $url -Prefix 'wac-installer' -Extension '.msi' -Action {
            param($installerPath)
            
            Write-CustomLog "Installing WAC silently on port $installPort"
            if ($PSCmdlet.ShouldProcess($installerPath, 'Install Windows Admin Center')) {
                $logPath = Join-Path (Get-CrossPlatformTempPath) 'WacInstall.log'
                Start-Process msiexec.exe -Wait -ArgumentList "/i `"$installerPath`" /qn /L*v `"$logPath`" SME_PORT=$installPort ACCEPT_EULA=1"
            }
            Write-CustomLog "WAC installation complete."
        }
    } else {
        Write-CustomLog 'InstallWAC flag is disabled. Skipping installation.'
    }
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"

