#Requires -Version 7.0
# Stage: Development
# Dependencies: None
# Description: Install AWS CLI for cloud management

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

Write-ScriptLog "Starting AWS CLI installation"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if AWS CLI installation is enabled
    $shouldInstall = $false
    $awsCliConfig = @{}

    if ($config.CloudTools -and $config.CloudTools.AWSCLI) {
        $awsCliConfig = $config.CloudTools.AWSCLI
        $shouldInstall = $awsCliConfig.Install -eq $true
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "AWS CLI installation is not enabled in configuration"
        exit 0
    }

    # Platform-specific installation
    if ($IsWindows) {
        # Check if AWS CLI is already installed
        $awsCmd = Get-Command aws -ErrorAction SilentlyContinue
        if (-not $awsCmd) {
            $awsCmd = Get-Command aws.exe -ErrorAction SilentlyContinue
        }

        if ($awsCmd) {
            Write-ScriptLog "AWS CLI is already installed at: $($awsCmd.Source)"

            # Get version
            try {
                $version = & aws --version 2>&1
                Write-ScriptLog "Current version: $version"
            } catch {
                Write-ScriptLog "Could not determine version" -Level 'Debug'
            }

            exit 0
        }

        Write-ScriptLog "Installing AWS CLI v2 for Windows..."

        # Download URL for AWS CLI v2
        $downloadUrl = 'https://awscli.amazonaws.com/AWSCLIV2.msi'
        $tempInstaller = Join-Path $env:TEMP "AWSCLIV2_$(Get-Date -Format 'yyyyMMddHHmmss').msi"

        try {
            if ($PSCmdlet.ShouldProcess($downloadUrl, 'Download AWS CLI installer')) {
                Write-ScriptLog "Downloading from: $downloadUrl"

                $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri $downloadUrl -OutFile $tempInstaller -UseBasicParsing
                $ProgressPreference = 'Continue'

                Write-ScriptLog "Downloaded to: $tempInstaller"
            }

            # Run MSI installer
            if ($PSCmdlet.ShouldProcess('AWS CLI', 'Install')) {
                Write-ScriptLog "Running installer..."

                $msiArgs = @(
                    '/i', "`"$tempInstaller`"",
                    '/quiet',
                    '/norestart'
                )

                $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList $msiArgs -Wait -PassThru

                if ($process.ExitCode -ne 0) {
                    throw "MSI installer exited with code: $($process.ExitCode)"
                }

                Write-ScriptLog "Installation completed"
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

    } elseif ($IsLinux) {
        # Linux installation
        Write-ScriptLog "Installing AWS CLI v2 for Linux..."

        # Check if already installed
        if (Get-Command aws -ErrorAction SilentlyContinue) {
            Write-ScriptLog "AWS CLI is already installed"

            try {
                $version = & aws --version 2>&1
                Write-ScriptLog "Current version: $version"
            } catch {
                Write-ScriptLog "Could not determine version" -Level 'Debug'
            }

            exit 0
        }

        # Download and install AWS CLI v2
        if ($PSCmdlet.ShouldProcess('AWS CLI v2', 'Download and install')) {
            $tempDir = Join-Path $env:TEMP "awscli_$(Get-Date -Format 'yyyyMMddHHmmss')"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

            try {
                $downloadUrl = 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip'
                $zipPath = Join-Path $tempDir 'awscliv2.zip'

                Write-ScriptLog "Downloading AWS CLI v2..."
                Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing

                Write-ScriptLog "Extracting..."
                & unzip -q $zipPath -d $tempDir

                Write-ScriptLog "Installing..."
                & sudo "$tempDir/aws/install"

                # Clean up
                Remove-Item $tempDir -Recurse -Force
            } catch {
                if (Test-Path $tempDir) {
                    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                }
                throw
            }
        }

    } elseif ($IsMacOS) {
        # macOS installation
        Write-ScriptLog "Installing AWS CLI for macOS..."

        # Check if already installed
        if (Get-Command aws -ErrorAction SilentlyContinue) {
            Write-ScriptLog "AWS CLI is already installed"
            exit 0
        }

        # Install using Homebrew
        if (Get-Command brew -ErrorAction SilentlyContinue) {
            if ($PSCmdlet.ShouldProcess('awscli', 'Install via Homebrew')) {
                & brew install awscli
            }
        } else {
            # Install using pkg installer
            $downloadUrl = 'https://awscli.amazonaws.com/AWSCLIV2.pkg'
            $tempInstaller = Join-Path $env:TMPDIR "AWSCLIV2_$(Get-Date -Format 'yyyyMMddHHmmss').pkg"

            try {
                Write-ScriptLog "Downloading installer..."
                Invoke-WebRequest -Uri $downloadUrl -OutFile $tempInstaller -UseBasicParsing

                Write-ScriptLog "Running installer..."
                & sudo installer -pkg $tempInstaller -target /

                Remove-Item $tempInstaller -Force
            } catch {
                if (Test-Path $tempInstaller) {
                    Remove-Item $tempInstaller -Force -ErrorAction SilentlyContinue
                }
                throw
            }
        }
    }

    # Verify installation
    $awsCmd = Get-Command aws -ErrorAction SilentlyContinue
    if (-not $awsCmd) {
        Write-ScriptLog "AWS CLI command not found after installation" -Level 'Error'
        exit 1
    }

    Write-ScriptLog "AWS CLI installed successfully"

    # Test AWS CLI
    try {
        $version = & aws --version 2>&1
        Write-ScriptLog "Installed version: $version"
    } catch {
        Write-ScriptLog "AWS CLI installed but may not be functioning correctly" -Level 'Warning'
    }

    # Configure if settings provided
    if ($awsCliConfig.DefaultSettings) {
        Write-ScriptLog "Configuring AWS CLI defaults..."

        foreach ($setting in $awsCliConfig.DefaultSettings.GetEnumerator()) {
            if ($PSCmdlet.ShouldProcess("aws configure set $($setting.Key)", 'Configure')) {
                & aws configure set $setting.Key $setting.Value 2>&1 | ForEach-Object { Write-ScriptLog $_ -Level 'Debug' }
            }
        }
    }

    Write-ScriptLog "AWS CLI installation completed successfully"
    exit 0

} catch {
    Write-ScriptLog "Critical error during AWS CLI installation: $_" -Level 'Error'
    Write-ScriptLog $_.ScriptStackTrace -Level 'Error'
    exit 1
}