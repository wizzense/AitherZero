#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [object]$Config
)

Import-Module "$env:PWSH_MODULES_PATH/LabRunner/" -Force
Import-Module "$env:PROJECT_ROOT/core-runner/modules/Logging" -Force

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"

function Install-GlobalPackage {
    <#
    .SYNOPSIS
        Installs a global npm package

    .PARAMETER Package
        The npm package name to install
    #>    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Package
    )

    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-CustomLog "Installing npm package: $Package..."
        if ($PSCmdlet.ShouldProcess($Package, 'Install npm package')) {
            npm install -g $Package
        }
    } else {
        Write-CustomLog 'npm is not available. Node.js may not have installed correctly.' -Level 'ERROR'
        throw 'npm command not found'
    }
}

Invoke-LabStep -Config $Config -Body {
    Write-CustomLog "Running $($MyInvocation.MyCommand.Name)"

    $nodeDeps = $Config.Node_Dependencies
    if (-not $nodeDeps) {
        Write-CustomLog 'Node_Dependencies configuration not found. Skipping global package installation.'
        return
    }

    $packages = @()

    # Parse configuration for packages to install
    if ($nodeDeps -is [hashtable]) {
        if ($nodeDeps.ContainsKey('InstallYarn') -and $nodeDeps.InstallYarn) {
            $packages += 'yarn'
        }
        if ($nodeDeps.ContainsKey('InstallVite') -and $nodeDeps.InstallVite) {
            $packages += 'vite'
        }
        if ($nodeDeps.ContainsKey('InstallNodemon') -and $nodeDeps.InstallNodemon) {
            $packages += 'nodemon'
        }
    } else {
        if ($nodeDeps.PSObject.Properties.Match('InstallYarn').Count -and $nodeDeps.InstallYarn) {
            $packages += 'yarn'
        }
        if ($nodeDeps.PSObject.Properties.Match('InstallVite').Count -and $nodeDeps.InstallVite) {
            $packages += 'vite'
        }
        if ($nodeDeps.PSObject.Properties.Match('InstallNodemon').Count -and $nodeDeps.InstallNodemon) {
            $packages += 'nodemon'
        }
    }

    if (-not $packages) {
        Write-CustomLog 'No global npm packages specified for installation.'
        return
    }

    Write-CustomLog "Installing global npm packages: $($packages -join ', ')"

    foreach ($package in $packages) {
        try {
            Install-GlobalPackage -Package $package
            Write-CustomLog "Successfully installed $package"
        } catch {
            Write-CustomLog "Failed to install $package: $_" -Level 'ERROR'
        }
    }
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
