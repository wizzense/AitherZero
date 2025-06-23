#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter()]
    [object]$Config
)

Import-Module "$env:PROJECT_ROOT/aither-core/modules/LabRunner" -Force
Import-Module "$env:PROJECT_ROOT/aither-core/modules/Logging" -Force

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"

Invoke-LabStep -Config $Config -Body {
    Write-CustomLog "Running $($MyInvocation.MyCommand.Name)"

    $dirs = @()
    if ($Config.Directories -and $Config.Directories.HyperVPath) {
        $dirs += $Config.Directories.HyperVPath
    }
    if ($Config.Directories -and $Config.Directories.HyperVDisks) {
        $dirs += $Config.Directories.HyperVDisks
    }
    if ($Config.Directories -and $Config.Directories.HyperVIsos) {
        $dirs += $Config.Directories.HyperVIsos
    }

    foreach ($dir in $dirs) {
        $expandedDir = [System.Environment]::ExpandEnvironmentVariables($dir)
        if (-not (Test-Path $expandedDir)) {
            Write-CustomLog "Creating directory: $expandedDir"
            New-Item -ItemType Directory -Path $expandedDir -Force | Out-Null
        } else {
            Write-CustomLog "Directory already exists: $expandedDir"
        }
    }

    Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
