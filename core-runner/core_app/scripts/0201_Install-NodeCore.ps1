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
    Write-CustomLog "Installing Node.js Core"

    $nodeDeps = if ($Config -is [hashtable]) { 
        $Config.Node_Dependencies 
    } else { 
        $Config.Node_Dependencies 
    }
    
    if (-not $nodeDeps) {
        Write-CustomLog "Config missing Node_Dependencies; skipping Node.js installation."
        return
    }

    if ($nodeDeps.InstallNode) {
        if (Get-Command node -ErrorAction SilentlyContinue) {
            Write-CustomLog "Node.js already installed. Skipping installation."
            return
        }
        
        try {
            $url = $null
            if ($nodeDeps.Node) {
                if ($nodeDeps.Node -is [hashtable]) {
                    $url = $nodeDeps.Node.InstallerUrl
                } else {
                    $url = $nodeDeps.Node.InstallerUrl
                }
            }
            
            if (-not $url) {
                # Use default Node.js LTS installer URL
                $url = 'https://nodejs.org/dist/v20.11.0/node-v20.11.0-x64.msi'
                Write-CustomLog "Using default Node.js installer URL: $url"
            }
            
            Write-CustomLog "Installing Node.js from: $url"
            
            Invoke-LabDownload -Uri $url -Prefix 'node-installer' -Extension '.msi' -Action {
                param($installer)
                
                if ($PSCmdlet.ShouldProcess($installer, 'Install Node.js')) {
                    Start-Process msiexec.exe -ArgumentList "/i `"$installer`" /quiet /norestart" -Wait -NoNewWindow
                }
            }
            
            Write-CustomLog "Node.js installation completed."
        } catch {
            Write-CustomLog "Node.js installation failed: $_" -Level 'ERROR'
            throw
        }
    } else {
        Write-CustomLog "InstallNode flag is disabled. Skipping Node.js installation."
    }
}
Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
