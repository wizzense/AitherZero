#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [object]$Config
)

try {
    Import-Module "$env:PWSH_MODULES_PATH/LabRunner/" -Force
    Import-Module "$env:PROJECT_ROOT/core-runner/modules/Logging" -Force

    Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"
    Invoke-LabStep -Config $Config -Body {
        Write-CustomLog -Level 'INFO' -Message "Running $($MyInvocation.MyCommand.Name)"
        if ($Config.InstallGo -eq $true) {
            $GoConfig = $Config.Go
            if ($null -eq $GoConfig) {
                Write-CustomLog -Level 'WARN' -Message 'No Go configuration found. Skipping installation.'
                return
            }
            if ($GoConfig.InstallerUrl) {
                $installerUrl = $GoConfig.InstallerUrl
                if ($installerUrl -match 'go([\d\.]+)\.windows-([a-z0-9]+)\.msi') {
                    $goVersion = $matches[1]
                    $goArch = $matches[2]
                } else {
                    Write-CustomLog -Level 'ERROR' -Message 'Unable to extract Go version and architecture from InstallerUrl.'
                    return
                }
            } elseif ($GoConfig.Version) {
                $goVersion = $GoConfig.Version
                $goArch = $GoConfig.Architecture
                if (-not $goArch) { $goArch = 'amd64' }
            } else {
                Write-CustomLog -Level 'WARN' -Message 'No Go version or InstallerUrl specified. Skipping installation.'
                return
            }
            # Check if Go is already installed by looking for the 'go' command
            if (Get-Command go -ErrorAction SilentlyContinue) {
                Write-CustomLog -Level 'INFO' -Message 'Go is already installed. Skipping installation.'
                return
            }
            Write-CustomLog -Level 'INFO' -Message "Installing Go version $goVersion for architecture $goArch..."
            $ProgressPreference = 'SilentlyContinue'
            Invoke-LabDownload -Uri $installerUrl -Prefix 'GoInstaller' -Extension '.msi' -Action {
                param($installerPath)

                Write-CustomLog 'Installing Go silently...'
                Start-Process msiexec.exe -Wait -ArgumentList "/i `"$installerPath`" /qn /L*v `"$(Get-CrossPlatformTempPath)\GoInstall.log`""
                Write-CustomLog 'Go installation complete.'
            }
        } else {
            Write-CustomLog -Level 'INFO' -Message 'InstallGo flag is disabled. Skipping Go installation.'
        }
        Write-CustomLog -Level 'INFO' -Message "Completed $($MyInvocation.MyCommand.Name)"
    }
    Write-CustomLog -Level 'INFO' -Message "Completed $($MyInvocation.MyCommand.Name)"
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Go installation failed: $_"
    throw
}

