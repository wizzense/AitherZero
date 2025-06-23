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

    if ($config.SetComputerName -eq $true) {

        try {
            $CurrentName = [System.Net.Dns]::GetHostName()
        } catch {
            Write-CustomLog "Error retrieving or changing computer name: $_"
            exit 1
        }

        if ($null -ne $Config.ComputerName -and $Config.ComputerName -match "^\S+$") {
            if ($CurrentName -ne $Config.ComputerName) {
                Write-CustomLog "Changing Computer Name from $CurrentName to $($Config.ComputerName)..."
                try {
                    Rename-Computer -NewName $Config.ComputerName -Force -ErrorAction Stop
                    Write-CustomLog "Computer name changed successfully. A reboot is usually required."
                    # Uncomment to reboot automatically
                    # Restart-Computer -Force
                } catch {
                    Write-CustomLog "Failed to change computer name: $_"
                }
            } else {
                Write-CustomLog "Computer name is already set to $($Config.ComputerName). Skipping rename."
            }
        } else {
            Write-CustomLog "No valid ComputerName specified in config. Skipping rename."
        }
    } else {
        Write-CustomLog "SetComputerName is false. Skipping rename."
    }
}
Write-CustomLog "Completed $MyInvocation.MyCommand"
