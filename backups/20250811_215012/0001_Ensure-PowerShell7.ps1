#Requires -Version 5.1
# Stage: Prepare
# Dependencies: None
# Description: Ensure PowerShell 7 is installed and restart if needed

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [hashtable]$Configuration
)

# Basic logging function (before we have access to centralized logging)
function Write-ScriptLog {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $prefix = switch ($Level) {
        'Error' { 'ERROR' }
        'Warning' { 'WARN' }
        'Debug' { 'DEBUG' }
        default { 'INFO' }
    }
    Write-Host "[$timestamp] [$prefix] $Message"
}

Write-ScriptLog "Checking PowerShell version"

# Check if we're already running PowerShell 7+
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-ScriptLog "Already running PowerShell $($PSVersionTable.PSVersion)"
    exit 0
}

Write-ScriptLog "Current PowerShell version: $($PSVersionTable.PSVersion)"
Write-ScriptLog "PowerShell 7 is required"

try {
    # Check if pwsh is already installed
    $pwshPath = $null

    if ($IsWindows -or [System.Environment]::OSVersion.Platform -eq 'Win32NT') {
        # Windows
        $pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
        
        if (-not $pwshPath) {
            Write-ScriptLog "Installing PowerShell 7 for Windows..."

            # Download and install
            $installerUrl = 'https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/PowerShell-7.4.6-win-x64.msi'
            $installerPath = Join-Path $env:TEMP 'PowerShell-7.msi'
            
            Write-ScriptLog "Downloading PowerShell 7 installer..."
            Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
            
            Write-ScriptLog "Running PowerShell 7 installer..."
            $installArgs = @('/i', $installerPath, '/quiet', 'ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1', 'ENABLE_PSREMOTING=1', 'REGISTER_MANIFEST=1')
            
            $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList $installArgs -Wait -PassThru -NoNewWindow

            if ($process.ExitCode -ne 0) {
                throw "PowerShell 7 installation failed with exit code: $($process.ExitCode)"
            }

            # Clean up
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

            # Find pwsh after installation
            $pwshPath = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
            if (-not (Test-Path $pwshPath)) {
                $pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
            }
        }
        
    } else {
        # Linux/macOS - this script shouldn't normally run there as bootstrap.sh handles it
        Write-ScriptLog "Non-Windows platform detected. PowerShell 7 should be installed by bootstrap.sh" -Level 'Warning'
        exit 1
    }

    if ($pwshPath -and (Test-Path $pwshPath)) {
        Write-ScriptLog "PowerShell 7 is installed at: $pwshPath"
        Write-ScriptLog "IMPORTANT: This script needs to be re-run with PowerShell 7"
        
        # Signal to the automation engine that we need to restart with pwsh
        Write-Host "RESTART_WITH_PWSH"
        exit 200  # Special exit code to indicate restart needed
    } else {
        throw "PowerShell 7 installation completed but pwsh not found"
    }
    
} catch {
    Write-ScriptLog "Failed to install PowerShell 7: $_" -Level 'Error'
    exit 1
}