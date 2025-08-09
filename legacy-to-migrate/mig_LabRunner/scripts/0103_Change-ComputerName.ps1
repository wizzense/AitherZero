#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter()]
    [object]$Config
)

# Source Find-ProjectRoot from relative path
. (Join-Path $PSScriptRoot (Join-Path ".." (Join-Path "shared" "Find-ProjectRoot.ps1")))
$projectRoot = Find-ProjectRoot -StartPath $PSScriptRoot
Import-Module (Join-Path $env:PWSH_MODULES_PATH "LabRunner") -Force
Import-Module (Join-Path $env:PWSH_MODULES_PATH "Logging") -Force

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"

Invoke-LabStep -Config $Config -Body {
    Write-CustomLog "Running $($MyInvocation.MyCommand.Name)"

    if ($Config.SetComputerName -eq $true) {
        try {
            $CurrentName = [System.Net.Dns]::GetHostName()

            if ($Config.ComputerName -and $CurrentName -ne $Config.ComputerName) {
                Write-CustomLog "Changing computer name from '$CurrentName' to '$($Config.ComputerName)'"
                
                if ($IsWindows) {
                    Rename-Computer -NewName $Config.ComputerName -Force
                    Write-CustomLog "Computer name changed. Restart required."
                } else {
                    Write-CustomLog "Computer name change is not supported on this platform"
                }
            } else {
                Write-CustomLog "Computer name is already set to '$CurrentName'"
            }
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error changing computer name: $($_.Exception.Message)"
            throw
        }
    } else {
        Write-CustomLog "Computer name change is disabled in configuration"
    }

    Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"

