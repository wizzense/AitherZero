#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [object]$Config
)

Import-Module "$env:PWSH_MODULES_PATH/LabRunner/" -Force
Import-Module "$env:PROJECT_ROOT/core-runner/modules/Logging" -Force

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"

function Install-NpmDependencies {
    <#
    .SYNOPSIS
        Installs npm dependencies for the frontend project.

    .DESCRIPTION
        Runs `npm install` in the configured frontend directory.
        Can create the directory and a blank package.json when enabled.

    .PARAMETER Config
        Configuration object passed from runner.ps1
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Config
    )

    Write-CustomLog "Running $($MyInvocation.MyCommand.Name)"

    # Check if npm dependencies should be installed
    $nodeDeps = $Config.Node_Dependencies
    if (-not $nodeDeps) {
        Write-CustomLog 'Node_Dependencies configuration not found. Skipping npm installation.'
        return
    }

    $installNpm = $false
    $createPath = $false

    # Parse configuration
    if ($nodeDeps -is [hashtable]) {
        $installNpm = $nodeDeps.ContainsKey('InstallNpm') -and $nodeDeps.InstallNpm
        $createPath = $nodeDeps.ContainsKey('CreateNpmPath') -and $nodeDeps.CreateNpmPath
    } else {
        $installNpm = $nodeDeps.PSObject.Properties.Match('InstallNpm').Count -and $nodeDeps.InstallNpm
        $createPath = $nodeDeps.PSObject.Properties.Match('CreateNpmPath').Count -and $nodeDeps.CreateNpmPath
    }

    if (-not $installNpm) {
        Write-CustomLog 'InstallNpm flag is disabled. Skipping project dependency installation.'
        return
    }

    # Determine frontend path
    $frontendPath = $null
    if ($nodeDeps -is [hashtable]) {
        if ($nodeDeps.ContainsKey('NpmPath')) {
            $frontendPath = $nodeDeps.NpmPath
        }
    } elseif ($nodeDeps.PSObject.Properties.Match('NpmPath').Count) {
        $frontendPath = $nodeDeps.NpmPath
    }

    if (-not $frontendPath) {
        $frontendPath = Join-Path $PSScriptRoot '..' 'frontend'
    }

    # Validate path requirements
    if ([string]::IsNullOrWhiteSpace($frontendPath) -and -not $createPath) {
        throw 'Node_Dependencies.NpmPath is empty and CreateNpmPath is false.'
    }

    # Create directory if needed
    if (-not (Test-Path $frontendPath)) {
        if ($createPath) {
            Write-CustomLog "Creating missing frontend folder at: $frontendPath"
            if ($PSCmdlet.ShouldProcess($frontendPath, 'Create NpmPath')) {
                New-Item -ItemType Directory -Path $frontendPath -Force | Out-Null
            }
        } else {
            throw "Frontend folder not found at: $frontendPath"
        }
    }

    # Create package.json if needed
    if (-not (Test-Path (Join-Path $frontendPath 'package.json'))) {
        if ($createPath) {
            $packageJsonPath = Join-Path $frontendPath 'package.json'
            if ($PSCmdlet.ShouldProcess($packageJsonPath, 'Create package.json')) {
                '{}' | Set-Content -Path $packageJsonPath
            }
        } else {
            Write-CustomLog "No package.json found in $frontendPath. Skipping npm install."
            return
        }
    }

    # Run npm install
    Push-Location $frontendPath
    try {
        Write-CustomLog "Running npm install in $frontendPath ..."
        if ($PSCmdlet.ShouldProcess($frontendPath, 'Run npm install')) {
            npm install
        }
        Write-CustomLog 'npm install completed.'
    } catch {
        Write-CustomLog "npm install failed: $_" -Level 'ERROR'
        throw
    } finally {
        Pop-Location
    }
    Write-CustomLog 'Frontend dependency installation complete'
}

Invoke-LabStep -Config $Config -Body {
    Install-NpmDependencies -Config $Config
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
