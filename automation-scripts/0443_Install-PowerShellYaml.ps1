#Requires -Version 7.0

<#
.SYNOPSIS
    Installs the powershell-yaml module for YAML parsing capabilities
.DESCRIPTION
    Installs the powershell-yaml module which provides:
    - ConvertFrom-Yaml and ConvertTo-Yaml cmdlets
    - Full YAML 1.2 specification support
    - Required for complete GitHub Actions workflow validation
    - Enables YAML configuration file parsing
.PARAMETER Force
    Force installation even if module exists
.PARAMETER Scope
    Installation scope (CurrentUser or AllUsers)
.PARAMETER CI
    Running in CI environment
.PARAMETER WhatIf
    Preview what would be installed without executing
.EXAMPLE
    ./0443_Install-PowerShellYaml.ps1
.EXAMPLE
    ./0443_Install-PowerShellYaml.ps1 -Force -Scope AllUsers
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Force,

    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope = 'CurrentUser',

    [switch]$CI,

    [string]$MinimumVersion = '0.4.7'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import required modules
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:LoggingModule = Join-Path $script:ProjectRoot "domains/core/Logging.psm1"
if (Test-Path $script:LoggingModule) {
    Import-Module $script:LoggingModule -Force -ErrorAction SilentlyContinue
}

# Logging helper
function Write-InstallLog {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level -Source "PowerShellYamlInstall"
    } else {
        $color = switch ($Level) {
            'Error' { 'Red' }
            'Warning' { 'Yellow' }
            'Success' { 'Green' }
            'Information' { 'White' }
            'Debug' { 'Gray' }
            default { 'White' }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
}

function Test-PowerShellYamlInstalled {
    <#
    .SYNOPSIS
        Check if powershell-yaml module is installed
    #>

    try {
        $module = Get-Module -ListAvailable -Name powershell-yaml -ErrorAction SilentlyContinue
        if ($module) {
            $currentVersion = $module.Version | Sort-Object -Descending | Select-Object -First 1
            Write-InstallLog "Found powershell-yaml version: $currentVersion" -Level Debug

            # Check if version meets minimum requirement
            if ($currentVersion -ge [version]$MinimumVersion) {
                return $true
            } else {
                Write-InstallLog "Installed version $currentVersion is below minimum required version $MinimumVersion" -Level Warning
                return $false
            }
        }
        return $false
    } catch {
        return $false
    }
}

function Install-PowerShellYamlModule {
    <#
    .SYNOPSIS
        Install powershell-yaml module from PowerShell Gallery
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-InstallLog "Installing powershell-yaml module..." -Level Information

    try {
        # Check if we have PowerShellGet
        if (-not (Get-Module -ListAvailable -Name PowerShellGet)) {
            throw "PowerShellGet module is required but not installed"
        }

        # Set repository as trusted temporarily in CI
        $repoTrusted = $false
        if ($CI) {
            $psGallery = Get-PSRepository -Name PSGallery
            if ($psGallery.InstallationPolicy -ne 'Trusted') {
                if ($PSCmdlet.ShouldProcess("PSGallery", "Set as Trusted")) {
                    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
                    $repoTrusted = $true
                }
            }
        }

        try {
            # Install parameters
            $installParams = @{
                Name = 'powershell-yaml'
                MinimumVersion = $MinimumVersion
                Scope = $Scope
                Force = $Force
                AllowClobber = $true
                ErrorAction = 'Stop'
            }

            # Add -AcceptLicense if available (PS 7+)
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                $installParams['AcceptLicense'] = $true
            }

            # Skip publisher check in CI
            if ($CI) {
                $installParams['SkipPublisherCheck'] = $true
            }

            if ($PSCmdlet.ShouldProcess("powershell-yaml", "Install module")) {
                Install-Module @installParams
                Write-InstallLog "powershell-yaml module installed successfully" -Level Information
            }
        }
        finally {
            # Restore repository trust setting
            if ($repoTrusted) {
                Set-PSRepository -Name PSGallery -InstallationPolicy Untrusted
            }
        }

        # Verify installation
        if (Test-PowerShellYamlInstalled) {
            # Import the module to verify it works
            Import-Module powershell-yaml -ErrorAction Stop

            # Test basic functionality
            $testYaml = "test: value"
            $parsed = ConvertFrom-Yaml $testYaml
            if ($parsed.test -eq 'value') {
                Write-InstallLog "Module verification successful" -Level Information
                return $true
            } else {
                throw "Module installed but verification failed"
            }
        } else {
            throw "Module installation verification failed"
        }
    }
    catch {
        Write-InstallLog "Failed to install powershell-yaml: $_" -Level Error
        throw
    }
}

# Main execution
try {
    Write-InstallLog "Checking for powershell-yaml module..." -Level Information

    $isInstalled = Test-PowerShellYamlInstalled

    if ($isInstalled -and -not $Force) {
        Write-InstallLog "powershell-yaml module is already installed with required version" -Level Information

        # Import module to make it available
        Import-Module powershell-yaml -ErrorAction SilentlyContinue

        if ($CI) {
            exit 0
        }
        return $true
    }

    if ($WhatIfPreference) {
        if ($isInstalled) {
            Write-InstallLog "What if: Would update powershell-yaml module to version $MinimumVersion or higher" -Level Information
        } else {
            Write-InstallLog "What if: Would install powershell-yaml module version $MinimumVersion or higher" -Level Information
        }
        Write-InstallLog "What if: Installation scope would be: $Scope" -Level Information
        return
    }

    # Install or update the module
    if ($PSCmdlet.ShouldProcess("powershell-yaml", "Install or update module")) {
        $result = Install-PowerShellYamlModule

        if ($result) {
            Write-InstallLog "powershell-yaml module ready for use" -Level Information

            # Show usage examples
            if (-not $CI) {
                Write-Host ""
                Write-Host "Usage examples:" -ForegroundColor Cyan
                Write-Host "  ConvertFrom-Yaml 'key: value'"
                Write-Host "  Get-Content file.yml | ConvertFrom-Yaml"
                Write-Host "  @{key='value'} | ConvertTo-Yaml"
            }

            if ($CI) {
                exit 0
            }
            return $true
        }
    }
}
catch {
    Write-InstallLog "Installation failed: $_" -Level Error
    if ($CI) {
        exit 1
    }
    throw
}
