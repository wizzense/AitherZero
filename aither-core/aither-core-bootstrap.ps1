# AitherZero Bootstrap Script
# Compatible with PowerShell 5.1+ - Installs PowerShell 7 and hands off to main core
# NO #Requires statement - this script must run on any PowerShell version

<#
.SYNOPSIS
    Bootstrap script for AitherZero that ensures PowerShell 7+ compatibility

.DESCRIPTION
    This script runs on PowerShell 5.1+ and handles automatic installation of PowerShell 7
    when needed, then hands off execution to the main aither-core.ps1 script.

    Key features:
    - Detects PowerShell version and installs PowerShell 7 if needed
    - Supports multiple installation methods (winget, chocolatey, direct download)
    - Preserves all command-line arguments during handoff
    - Provides clear user feedback about the process

.PARAMETER Quiet
    Run in quiet mode with minimal output

.PARAMETER Verbosity
    Set verbosity level: silent, normal, detailed

.PARAMETER ConfigFile
    Path to configuration file (defaults to default-config.json)

.PARAMETER Auto
    Run in automatic mode without prompts

.PARAMETER Scripts
    Specific scripts to run

.PARAMETER Force
    Force operations even if validations fail

.PARAMETER NonInteractive
    Run in non-interactive mode, suppress prompts and user input

.PARAMETER Help
    Show help information

.EXAMPLE
    .\aither-core-bootstrap.ps1
    Basic execution - will install PowerShell 7 if needed

.EXAMPLE
    .\aither-core-bootstrap.ps1 -Auto -Verbosity detailed
    Automated mode with detailed logging
#>

[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Default')]
param(
    [Parameter(ParameterSetName = 'Quiet')]
    [switch]$Quiet,

    [Parameter(ParameterSetName = 'Default')]
    [ValidateSet('silent', 'normal', 'detailed')]
    [string]$Verbosity = 'normal',

    [string]$ConfigFile,
    [switch]$Auto,
    [string]$Scripts,
    [switch]$Force,
    [switch]$NonInteractive,
    [switch]$Help
)

# Set up environment for compatibility
$ErrorActionPreference = 'Stop'

# Compatibility check for PowerShell version
$psVersion = $PSVersionTable.PSVersion.Major
$psVersionFull = $PSVersionTable.PSVersion

function Write-BootstrapLog {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )

    $color = switch ($Level) {
        'Info'    { 'Cyan' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
        'Success' { 'Green' }
    }

    $prefix = switch ($Level) {
        'Info'    { 'ℹ️' }
        'Warning' { '⚠️' }
        'Error'   { '❌' }
        'Success' { '✅' }
    }

    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Test-PowerShell7Available {
    try {
        $pwshPath = Get-Command pwsh -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Install-PowerShell7 {
    Write-BootstrapLog "PowerShell $psVersionFull detected. Installing PowerShell 7 for optimal compatibility..." -Level 'Info'
    Write-BootstrapLog "This is a one-time setup process." -Level 'Info'
    Write-Host ""

    # Check if we're on Windows
    $isWindows = [System.Environment]::OSVersion.Platform -eq 'Win32NT' -or $PSVersionTable.PSVersion.Major -le 5

    if (-not $isWindows) {
        Write-BootstrapLog "Non-Windows platform detected. Please install PowerShell 7 manually:" -Level 'Warning'
        Write-Host "  Linux: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-linux"
        Write-Host "  macOS: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-macos"
        throw "PowerShell 7 installation not supported on this platform via bootstrap"
    }

    $installSuccess = $false

    # Method 1: Try winget (Windows 10 1709+ and Windows 11)
    try {
        $wingetAvailable = Get-Command winget -ErrorAction Stop
        Write-BootstrapLog "Attempting installation via winget..." -Level 'Info'

        $wingetResult = & winget install --id Microsoft.Powershell --source winget --silent --accept-package-agreements --accept-source-agreements

        if ($LASTEXITCODE -eq 0) {
            $installSuccess = $true
            Write-BootstrapLog "PowerShell 7 installed successfully via winget!" -Level 'Success'
        }
    } catch {
        Write-BootstrapLog "winget not available, trying alternative methods..." -Level 'Warning'
    }

    # Method 2: Try chocolatey if winget failed
    if (-not $installSuccess) {
        try {
            $chocoAvailable = Get-Command choco -ErrorAction Stop
            Write-BootstrapLog "Attempting installation via chocolatey..." -Level 'Info'

            $chocoResult = & choco install powershell-core -y

            if ($LASTEXITCODE -eq 0) {
                $installSuccess = $true
                Write-BootstrapLog "PowerShell 7 installed successfully via chocolatey!" -Level 'Success'
            }
        } catch {
            Write-BootstrapLog "chocolatey not available, trying direct download..." -Level 'Warning'
        }
    }

    # Method 3: Direct download and install
    if (-not $installSuccess) {
        Write-BootstrapLog "Attempting direct download installation..." -Level 'Info'

        try {
            # Download latest PowerShell 7 installer (using a stable version for compatibility)
            $downloadUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/PowerShell-7.4.6-win-x64.msi"
            $tempPath = [System.IO.Path]::GetTempPath()
            $installerPath = Join-Path $tempPath "PowerShell-7-latest.msi"

            Write-BootstrapLog "Downloading PowerShell 7 installer..." -Level 'Info'

            # Use .NET WebClient for PowerShell 5.1 compatibility
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($downloadUrl, $installerPath)

            Write-BootstrapLog "Installing PowerShell 7..." -Level 'Info'

            # Install silently
            $installArgs = @(
                "/i", $installerPath,
                "/quiet",
                "/norestart",
                "ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1",
                "ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1",
                "ENABLE_PSREMOTING=1",
                "REGISTER_MANIFEST=1"
            )

            $process = Start-Process msiexec.exe -ArgumentList $installArgs -Wait -PassThru

            if ($process.ExitCode -eq 0) {
                $installSuccess = $true
                Write-BootstrapLog "PowerShell 7 installed successfully via direct download!" -Level 'Success'

                # Clean up installer
                Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
            } else {
                throw "Installation failed with exit code: $($process.ExitCode)"
            }
        } catch {
            Write-BootstrapLog "Direct installation failed: $($_.Exception.Message)" -Level 'Error'
        }
    }

    if (-not $installSuccess) {
        Write-BootstrapLog "Automatic PowerShell 7 installation failed." -Level 'Error'
        Write-Host ""
        Write-Host "Please install PowerShell 7 manually:"
        Write-Host "  1. Download from: https://github.com/PowerShell/PowerShell/releases/latest"
        Write-Host "  2. Or use winget: winget install Microsoft.PowerShell"
        Write-Host "  3. Or use chocolatey: choco install powershell-core"
        Write-Host ""
        Write-Host "After installation, restart your terminal and run AitherZero again."
        throw "PowerShell 7 installation required for full functionality"
    }

    Write-Host ""
    Write-BootstrapLog "PowerShell 7 installation complete!" -Level 'Success'
    Write-BootstrapLog "You may need to restart your terminal for the changes to take effect." -Level 'Info'
    Write-Host ""

    return $installSuccess
}

function Invoke-CoreApplicationHandoff {
    param(
        [hashtable]$OriginalParameters
    )

    # Build path to main core script
    $coreScriptPath = Join-Path $PSScriptRoot "aither-core.ps1"

    if (-not (Test-Path $coreScriptPath)) {
        throw "Main core script not found at: $coreScriptPath"
    }

    # Check if PowerShell 7 is available after installation
    $pwsh7Available = Test-PowerShell7Available

    if ($pwsh7Available) {
        Write-BootstrapLog "Handing off to PowerShell 7 for optimal execution..." -Level 'Info'

        # Build command line arguments for PowerShell 7
        $pwshArgs = @('-ExecutionPolicy', 'Bypass', '-File', $coreScriptPath)

        # Add original parameters
        foreach ($key in $OriginalParameters.Keys) {
            if ($OriginalParameters[$key] -eq $true) {
                # Switch parameter
                $pwshArgs += "-$key"
            } else {
                # Value parameter
                $pwshArgs += "-$key"
                $pwshArgs += $OriginalParameters[$key]
            }
        }

        Write-BootstrapLog "Executing: pwsh $($pwshArgs -join ' ')" -Level 'Info'
        Write-Host ""

        # Execute with PowerShell 7
        & pwsh $pwshArgs
        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0 -and $null -ne $exitCode) {
            throw "Core application exited with code: $exitCode"
        }
    } else {
        Write-BootstrapLog "PowerShell 7 not detected. Attempting to run with current PowerShell version..." -Level 'Warning'
        Write-BootstrapLog "Some features may be limited." -Level 'Warning'
        Write-Host ""

        # Fallback to current PowerShell version
        & $coreScriptPath @OriginalParameters
        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0 -and $null -ne $exitCode) {
            throw "Core application exited with code: $exitCode"
        }
    }
}

# Main execution logic
try {
    # Handle help request immediately
    if ($Help) {
        Write-Host "AitherZero Bootstrap" -ForegroundColor Green
        Write-Host ""
        Write-Host "This bootstrap script ensures PowerShell 7+ compatibility and hands off to the main application."
        Write-Host ""
        Write-Host "Usage:" -ForegroundColor Cyan
        Write-Host "  aither-core-bootstrap.ps1 [options]"
        Write-Host ""
        Write-Host "The bootstrap will:"
        Write-Host "  1. Check your PowerShell version"
        Write-Host "  2. Install PowerShell 7 if needed (one-time setup)"
        Write-Host "  3. Hand off execution to the main core with full functionality"
        Write-Host ""
        Write-Host "All parameters are passed through to the main application."
        Write-Host "Use 'aither-core.ps1 -Help' after bootstrap for full parameter documentation."
        Write-Host ""
        return
    }

    Write-BootstrapLog "AitherZero Bootstrap v1.0 - Ensuring PowerShell 7+ Compatibility" -Level 'Info'
    Write-Host ""

    # Store original parameters for handoff
    $originalParams = @{}
    if ($PSBoundParameters.ContainsKey('Quiet')) { $originalParams['Quiet'] = $true }
    if ($PSBoundParameters.ContainsKey('Verbosity')) { $originalParams['Verbosity'] = $Verbosity }
    if ($PSBoundParameters.ContainsKey('ConfigFile')) { $originalParams['ConfigFile'] = $ConfigFile }
    if ($PSBoundParameters.ContainsKey('Auto')) { $originalParams['Auto'] = $true }
    if ($PSBoundParameters.ContainsKey('Scripts')) { $originalParams['Scripts'] = $Scripts }
    if ($PSBoundParameters.ContainsKey('Force')) { $originalParams['Force'] = $true }
    if ($PSBoundParameters.ContainsKey('NonInteractive')) { $originalParams['NonInteractive'] = $true }

    # Check PowerShell version
    if ($psVersion -ge 7) {
        Write-BootstrapLog "PowerShell $psVersionFull detected - Full compatibility available!" -Level 'Success'
        Write-Host ""

        # Hand off directly to main core script
        Invoke-CoreApplicationHandoff -OriginalParameters $originalParams
    } else {
        Write-BootstrapLog "PowerShell $psVersionFull detected - Enhanced features require PowerShell 7+" -Level 'Warning'
        Write-Host ""

        # Check if PowerShell 7 is already installed but not being used
        if (Test-PowerShell7Available) {
            Write-BootstrapLog "PowerShell 7 is available but not currently being used." -Level 'Info'
            Write-BootstrapLog "Switching to PowerShell 7 for optimal experience..." -Level 'Info'
            Write-Host ""

            # Hand off to PowerShell 7
            Invoke-CoreApplicationHandoff -OriginalParameters $originalParams
        } else {
            # Need to install PowerShell 7
            if (-not $Auto -and -not $NonInteractive) {
                Write-Host "AitherZero works best with PowerShell 7.0+ for full functionality." -ForegroundColor Yellow
                Write-Host "Would you like to automatically install PowerShell 7? (y/N): " -NoNewline -ForegroundColor Cyan
                $response = Read-Host

                if ($response -notmatch '^[Yy]') {
                    Write-BootstrapLog "Continuing with PowerShell $psVersionFull - some features may be limited." -Level 'Warning'
                    Write-Host ""

                    # Try to run with current version
                    Invoke-CoreApplicationHandoff -OriginalParameters $originalParams
                    return
                }
            }

            # Install PowerShell 7
            $installSuccess = Install-PowerShell7

            if ($installSuccess) {
                # Hand off to PowerShell 7
                Invoke-CoreApplicationHandoff -OriginalParameters $originalParams
            } else {
                throw "PowerShell 7 installation failed"
            }
        }
    }

} catch {
    Write-BootstrapLog "Bootstrap failed: $($_.Exception.Message)" -Level 'Error'
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Run as Administrator if installation failed"
    Write-Host "  2. Check internet connection for downloads"
    Write-Host "  3. Install PowerShell 7 manually: https://github.com/PowerShell/PowerShell/releases"
    Write-Host "  4. Restart terminal after manual installation"
    Write-Host ""
    exit 1
}
