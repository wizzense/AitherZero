#Requires -Version 7.0
# Stage: Development
# Dependencies: None
# Description: Install Sysinternals utilities suite

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [hashtable]$Configuration
)

# Initialize logging
$script:LoggingAvailable = $false
try {
    $loggingPath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/utilities/Logging.psm1"
    if (Test-Path $loggingPath) {
        Import-Module $loggingPath -Force -Global
        $script:LoggingAvailable = $true
    }
} catch {
    # Fallback to basic output
}

function Write-ScriptLog {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level
    } else {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $prefix = switch ($Level) {
            'Error' { 'ERROR' }
            'Warning' { 'WARN' }
            'Debug' { 'DEBUG' }
            default { 'INFO' }
        }
        Write-Host "[$timestamp] [$prefix] $Message"
    }
}

Write-ScriptLog "Starting Sysinternals installation"

try {
    # Skip on non-Windows platforms
    if (-not $IsWindows) {
        Write-ScriptLog "Sysinternals is Windows-specific. Skipping on this platform."
        exit 0
    }

    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if Sysinternals installation is enabled
    $shouldInstall = $false
    $sysinternalsConfig = @{}

    if ($config.DevelopmentTools -and $config.DevelopmentTools.Sysinternals) {
        $sysinternalsConfig = $config.DevelopmentTools.Sysinternals
        $shouldInstall = $sysinternalsConfig.Install -eq $true
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "Sysinternals installation is not enabled in configuration"
        exit 0
    }

    # Determine installation path
    $installPath = if ($sysinternalsConfig.InstallPath) {
        [System.Environment]::ExpandEnvironmentVariables($sysinternalsConfig.InstallPath)
    } else {
        'C:\Tools\Sysinternals'
    }

    Write-ScriptLog "Target installation path: $installPath"

    # Check if already installed
    if (Test-Path $installPath) {
        $existingFiles = Get-ChildItem -Path $installPath -Filter '*.exe' -ErrorAction SilentlyContinue
        if ($existingFiles.Count -gt 0) {
            Write-ScriptLog "Sysinternals appears to be already installed at $installPath ($($existingFiles.Count) executables found)"

            # Check for updates if configured
            if ($sysinternalsConfig.CheckForUpdates -eq $true) {
                Write-ScriptLog "Update checking for Sysinternals is configured but not implemented yet" -Level 'Debug'
            }

            # Ensure in PATH
            if ($env:PATH -notlike "*$installPath*") {
                $env:PATH = "$env:PATH;$installPath"
                Write-ScriptLog "Added Sysinternals to current session PATH"
            }

            exit 0
        }
    }

    Write-ScriptLog "Installing Sysinternals Suite..."

    # Create installation directory
    if (-not (Test-Path $installPath)) {
        if ($PSCmdlet.ShouldProcess($installPath, 'Create directory')) {
            New-Item -ItemType Directory -Path $installPath -Force | Out-Null
            Write-ScriptLog "Created directory: $installPath"
        }
    }

    # Download Sysinternals Suite
    $downloadUrl = 'https://download.sysinternals.com/files/SysinternalsSuite.zip'
    $tempZip = Join-Path $env:TEMP "SysinternalsSuite_$(Get-Date -Format 'yyyyMMddHHmmss').zip"

    try {
        if ($PSCmdlet.ShouldProcess($downloadUrl, 'Download Sysinternals Suite')) {
            Write-ScriptLog "Downloading from: $downloadUrl"

            # Download with progress
            $ProgressPreference = 'SilentlyContinue'  # Faster download
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -UseBasicParsing
            $ProgressPreference = 'Continue'

            Write-ScriptLog "Downloaded to: $tempZip"

            # Verify download
            if (-not (Test-Path $tempZip) -or (Get-Item $tempZip).Length -eq 0) {
                throw "Download failed or resulted in empty file"
            }
        }

        # Extract archive
        if ($PSCmdlet.ShouldProcess($tempZip, 'Extract archive')) {
            Write-ScriptLog "Extracting archive..."
            Expand-Archive -Path $tempZip -DestinationPath $installPath -Force
            Write-ScriptLog "Extraction completed"
        }

        # Clean up
        Remove-Item $tempZip -Force -ErrorAction SilentlyContinue

    } catch {
        # Clean up on failure
        if (Test-Path $tempZip) {
            Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
        }
        throw
    }

    # Verify installation
    $installedTools = Get-ChildItem -Path $installPath -Filter '*.exe' -ErrorAction SilentlyContinue
    if ($installedTools.Count -eq 0) {
        Write-ScriptLog "No executables found after extraction" -Level 'Error'
        exit 1
    }

    Write-ScriptLog "Successfully installed $($installedTools.Count) Sysinternals tools"

    # Verify key tools
    $keyTools = @('PsInfo.exe', 'PsExec.exe', 'Handle.exe', 'ProcMon.exe', 'ProcExp.exe')
    foreach ($tool in $keyTools) {
        $toolPath = Join-Path $installPath $tool
        if (Test-Path $toolPath) {
            Write-ScriptLog "Verified: $tool" -Level 'Debug'
        } else {
            Write-ScriptLog "Key tool not found: $tool" -Level 'Warning'
        }
    }

    # Add to system PATH if configured
    if ($sysinternalsConfig.AddToPath -eq $true) {
        try {
            $currentPath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
            if ($currentPath -notlike "*$installPath*") {
                if ($PSCmdlet.ShouldProcess('System PATH', "Add $installPath")) {
                    [Environment]::SetEnvironmentVariable('PATH', "$currentPath;$installPath", 'Machine')
                    Write-ScriptLog "Added Sysinternals to system PATH (requires restart to take effect)"
                }
            } else {
                Write-ScriptLog "Sysinternals already in system PATH"
            }
        } catch {
            Write-ScriptLog "Could not modify system PATH: $_" -Level 'Warning'
            Write-ScriptLog "You may need to manually add to PATH or run as administrator" -Level 'Warning'
        }
    }

    # Add to current session PATH
    if ($env:PATH -notlike "*$installPath*") {
        $env:PATH = "$env:PATH;$installPath"
        Write-ScriptLog "Added Sysinternals to current session PATH"
    }

    # Accept EULA if configured
    if ($sysinternalsConfig.AcceptEula -eq $true) {
        Write-ScriptLog "Configuring EULA acceptance..."
        try {
            # Set registry key to accept EULA for all Sysinternals tools
            $eulaKey = 'HKCU:\Software\Sysinternals'
            if (-not (Test-Path $eulaKey)) {
                New-Item -Path $eulaKey -Force | Out-Null
            }

            foreach ($tool in $installedTools) {
                $toolName = [System.IO.Path]::GetFileNameWithoutExtension($tool.Name)
                $toolKey = Join-Path $eulaKey $toolName
                if (-not (Test-Path $toolKey)) {
                    New-Item -Path $toolKey -Force | Out-Null
                }
                Set-ItemProperty -Path $toolKey -Name 'EulaAccepted' -Value 1 -Type DWord
            }

            Write-ScriptLog "EULA acceptance configured for all tools"
        } catch {
            Write-ScriptLog "Could not configure EULA acceptance: $_" -Level 'Warning'
        }
    }

    Write-ScriptLog "Sysinternals installation completed successfully"
    exit 0

} catch {
    Write-ScriptLog "Critical error during Sysinternals installation: $_" -Level 'Error'
    Write-ScriptLog $_.ScriptStackTrace -Level 'Error'
    exit 1
}