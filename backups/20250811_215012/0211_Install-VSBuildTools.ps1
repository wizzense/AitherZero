#Requires -Version 7.0
# Stage: Development
# Dependencies: None
# Description: Install Visual Studio Build Tools

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

Write-ScriptLog "Starting Visual Studio Build Tools installation"

try {
    # Skip on non-Windows platforms
    if (-not $IsWindows) {
        Write-ScriptLog "Visual Studio Build Tools is Windows-specific. Skipping on this platform."
        exit 0
    }

    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if VS Build Tools installation is enabled
    $shouldInstall = $false
    $vsBuildConfig = @{}

    if ($config.DevelopmentTools -and $config.DevelopmentTools.VSBuildTools) {
        $vsBuildConfig = $config.DevelopmentTools.VSBuildTools
        $shouldInstall = $vsBuildConfig.Install -eq $true
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "Visual Studio Build Tools installation is not enabled in configuration"
        exit 0
    }

    # Determine installation path
    $installPath = if ($vsBuildConfig.InstallPath) {
        [System.Environment]::ExpandEnvironmentVariables($vsBuildConfig.InstallPath)
    } else {
        'C:\BuildTools'
    }

    # Check if already installed
    $vswhereExe = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $existingInstall = $false

    if (Test-Path $vswhereExe) {
        Write-ScriptLog "Checking for existing VS Build Tools installation..."
        try {
            $installations = & $vswhereExe -products Microsoft.VisualStudio.Product.BuildTools -format json | ConvertFrom-Json
            if ($installations) {
                $existingInstall = $true
                foreach ($install in $installations) {
                    Write-ScriptLog "Found: $($install.displayName) at $($install.installationPath)"
                    Write-ScriptLog "  Version: $($install.installationVersion)"
                }
            }
        } catch {
            Write-ScriptLog "Could not query existing installations" -Level 'Debug'
        }
    }

    # Alternative check - look for the installation directory
    if (-not $existingInstall -and (Test-Path $installPath)) {
        $vsDevCmd = Get-ChildItem -Path $installPath -Recurse -Filter 'VsDevCmd.bat' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($vsDevCmd) {
            Write-ScriptLog "Visual Studio Build Tools appears to be installed at: $installPath"
            $existingInstall = $true
        }
    }

    if ($existingInstall -and -not $vsBuildConfig.ForceReinstall) {
        Write-ScriptLog "Visual Studio Build Tools is already installed"
        exit 0
    }
    
    Write-ScriptLog "Installing Visual Studio Build Tools..."

    # Download URL - VS 2022 Build Tools
    $downloadUrl = 'https://aka.ms/vs/17/release/vs_BuildTools.exe'
    $tempInstaller = Join-Path $env:TEMP "vs_BuildTools_$(Get-Date -Format 'yyyyMMddHHmmss').exe"
    
    try {
        if ($PSCmdlet.ShouldProcess($downloadUrl, 'Download VS Build Tools installer')) {
            Write-ScriptLog "Downloading from: $downloadUrl"
            
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempInstaller -UseBasicParsing
            $ProgressPreference = 'Continue'
            
            Write-ScriptLog "Downloaded to: $tempInstaller"
        }
        
        # Prepare installation arguments
        $installArgs = @(
            '--quiet',
            '--wait',
            '--norestart',
            '--nocache',
            "--installPath", $installPath
        )
    
        # Add workloads based on configuration
        $workloads = @()
        
        if ($vsBuildConfig.Workloads) {
            $workloads = $vsBuildConfig.Workloads
        } else {
            # Default workloads
            $workloads = @(
                'Microsoft.VisualStudio.Workload.MSBuildTools',
                'Microsoft.VisualStudio.Workload.NetCoreBuildTools'
            )
    }
        
        foreach ($workload in $workloads) {
            $installArgs += '--add', $workload
        }
        
        # Add components if specified
        if ($vsBuildConfig.Components) {
            foreach ($component in $vsBuildConfig.Components) {
                $installArgs += '--add', $component
            }
        }
        
        # Include recommended components by default
        if ($vsBuildConfig.IncludeRecommended -ne $false) {
            $installArgs += '--includeRecommended'
        }
        
        # Run installer
        if ($PSCmdlet.ShouldProcess('VS Build Tools', "Install with workloads: $($workloads -join ', ')")) {
            Write-ScriptLog "Running installer with arguments..."
            Write-ScriptLog "Workloads: $($workloads -join ', ')" -Level 'Debug'
            
            $process = Start-Process -FilePath $tempInstaller -ArgumentList $installArgs -Wait -PassThru

            # Check exit code
            switch ($process.ExitCode) {
                0 { Write-ScriptLog "Installation completed successfully" }
                3010 { 
                    Write-ScriptLog "Installation completed successfully but requires restart" -Level 'Warning'
                    exit 3010
                }
                default { 
                    throw "Installer exited with code: $($process.ExitCode)"
                }
            }
        }
        
        # Clean up
        Remove-Item $tempInstaller -Force -ErrorAction SilentlyContinue
        
    } catch {
        # Clean up on failure
        if (Test-Path $tempInstaller) {
            Remove-Item $tempInstaller -Force -ErrorAction SilentlyContinue
        }
        throw
    }

    # Verify installation
    $vsDevCmd = Get-ChildItem -Path $installPath -Recurse -Filter 'VsDevCmd.bat' -ErrorAction SilentlyContinue | Select-Object -First 1

    if (-not $vsDevCmd) {
        Write-ScriptLog "VS Build Tools installation could not be verified" -Level 'Error'
        exit 1
    }
    
    Write-ScriptLog "VS Build Tools installed successfully"
    Write-ScriptLog "Developer command prompt available at: $($vsDevCmd.FullName)"

    # Set environment variables if configured
    if ($vsBuildConfig.SetEnvironmentVariables -eq $true) {
        try {
            [Environment]::SetEnvironmentVariable('VS_BUILDTOOLS_PATH', $installPath, 'Machine')
            Write-ScriptLog "Set VS_BUILDTOOLS_PATH environment variable"
        } catch {
            Write-ScriptLog "Could not set environment variables: $_" -Level 'Warning'
        }
    }
    
    Write-ScriptLog "Visual Studio Build Tools installation completed successfully"
    exit 0
    
} catch {
    Write-ScriptLog "Critical error during VS Build Tools installation: $_" -Level 'Error'
    Write-ScriptLog $_.ScriptStackTrace -Level 'Error'
    exit 1
}