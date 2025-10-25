#Requires -Version 7.0
# Stage: Development
# Dependencies: PackageManager
# Description: Install Visual Studio Code editor using package managers (winget priority)
# Tags: development, editor, vscode, ide

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [hashtable]$Configuration
)

# Initialize logging
$script:LoggingAvailable = $false
try {
    $loggingPath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/core/Logging.psm1"
    if (Test-Path $loggingPath) {
        Import-Module $loggingPath -Force -Global
        $script:LoggingAvailable = $true
    }
} catch {
    # Fallback to basic output
}

# Import PackageManager module
try {
    $packageManagerPath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/development/DevTools.psm1"
    if (Test-Path $packageManagerPath) {
        Import-Module $packageManagerPath -Force -Global
        $script:PackageManagerAvailable = $true
    } else {
        throw "PackageManager module not found at: $packageManagerPath"
    }
} catch {
    Write-Warning "Could not load PackageManager module: $_"
    $script:PackageManagerAvailable = $false
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

Write-ScriptLog "Starting Visual Studio Code installation using package managers"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if VSCode installation is enabled
    $shouldInstall = $false
    if ($config.InstallationOptions -and $config.InstallationOptions.VSCode) {
        $vscodeConfig = $config.InstallationOptions.VSCode
        $shouldInstall = $vscodeConfig.Install -eq $true
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "Visual Studio Code installation is not enabled in configuration"
        exit 0
    }

    # Use PackageManager if available
    if ($script:PackageManagerAvailable) {
        Write-ScriptLog "Using PackageManager module for Visual Studio Code installation"

        # Try package manager installation
        try {
            $preferredPackageManager = $vscodeConfig.PreferredPackageManager
            $installResult = Install-SoftwarePackage -SoftwareName 'vscode' -PreferredPackageManager $preferredPackageManager

            if ($installResult.Success) {
                Write-ScriptLog "Visual Studio Code installed successfully via $($installResult.PackageManager)"

                # Verify installation
                $version = Get-SoftwareVersion -SoftwareName 'vscode'
                Write-ScriptLog "Visual Studio Code version: $version"

                # Install extensions if specified
                if ($vscodeConfig.Extensions -and $vscodeConfig.Extensions.Count -gt 0) {
                    Write-ScriptLog "Installing Visual Studio Code extensions..."

                    # Wait a moment for VSCode to be available
                    Start-Sleep -Seconds 2

                    $codeCmd = if ($IsWindows) { 'code.cmd' } else { 'code' }
                    foreach ($extension in $vscodeConfig.Extensions) {
                        try {
                            Write-ScriptLog "Installing extension: $extension"
                            & $codeCmd --install-extension $extension --force

                            if ($LASTEXITCODE -ne 0) {
                                Write-ScriptLog "Failed to install extension: $extension" -Level 'Warning'
                            }
                        } catch {
                            Write-ScriptLog "Error installing extension $extension : $_" -Level 'Warning'
                        }
                    }
                }

                Write-ScriptLog "Visual Studio Code installation completed successfully"
                exit 0
            }
        } catch {
            Write-ScriptLog "Package manager installation failed: $_" -Level 'Warning'
            Write-ScriptLog "Falling back to manual installation" -Level 'Information'
        }
    }

    # Fallback to original installation logic
    Write-ScriptLog "Using legacy installation method"

    # Check if VSCode is already installed
    $codeCmd = if ($IsWindows) { 'code.cmd' } else { 'code' }

    try {
        $codeVersion = & $codeCmd --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "Visual Studio Code is already installed:"
            Write-ScriptLog $($codeVersion -join ' ') -Level 'Debug'
            exit 0
        }
    } catch {
        # Also check alternative locations on Windows
        if ($IsWindows) {
            $vscodePaths = @(
                "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
                "$env:ProgramFiles\Microsoft VS Code\Code.exe",
                "${env:ProgramFiles(x86)}\Microsoft VS Code\Code.exe"
            )

            foreach ($path in $vscodePaths) {
                if (Test-Path $path) {
                    Write-ScriptLog "Visual Studio Code found at: $path"
                    exit 0
                }
            }
        }

        Write-ScriptLog "Visual Studio Code not found, proceeding with installation"
    }

    # Install VSCode based on platform
    if ($IsWindows) {
        Write-ScriptLog "Installing Visual Studio Code for Windows..."

        # Determine system architecture
        $arch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x32' }

        # User vs System installer
        $installerType = if ($vscodeConfig.SystemInstall -eq $true) { 'system' } else { 'user' }

        $downloadUrl = "https://update.code.visualstudio.com/latest/win32-$arch-$installerType/stable"

        $tempDir = if ($config.Infrastructure -and $config.Infrastructure.Directories -and $config.Infrastructure.Directories.LocalPath) {
            [System.Environment]::ExpandEnvironmentVariables($config.Infrastructure.Directories.LocalPath)
        } else {
            $env:TEMP
        }

        $installerPath = Join-Path $tempDir 'vscode-installer.exe'

        # Download installer
        Write-ScriptLog "Downloading Visual Studio Code installer..."
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
            $ProgressPreference = 'Continue'
        } catch {
            Write-ScriptLog "Failed to download Visual Studio Code: $_" -Level 'Error'
            throw
        }

        # Install VSCode
        if ($PSCmdlet.ShouldProcess($installerPath, 'Install Visual Studio Code')) {
            Write-ScriptLog "Running Visual Studio Code installer..."

            # Build install arguments
            $installArgs = @(
                '/verysilent',
                '/suppressmsgboxes',
                '/norestart',
                '/sp-'
            )

            # Add tasks based on configuration
            $tasks = @()
            if ($vscodeConfig.AddToPath -ne $false) {
                $tasks += 'addtopath'
            }
            if ($vscodeConfig.AddContextMenuFiles -ne $false) {
                $tasks += 'addcontextmenufiles'
            }
            if ($vscodeConfig.AddContextMenuFolders -ne $false) {
                $tasks += 'addcontextmenufolders'
            }
            if ($vscodeConfig.RegisterAsEditor -ne $false) {
                $tasks += 'associatewithfiles'
            }
            if ($vscodeConfig.CreateDesktopIcon -eq $true) {
                $tasks += 'desktopicon'
            }

            if ($tasks.Count -gt 0) {
                $installArgs += "/mergetasks=$($tasks -join ',')"
            } else {
                $installArgs += '/mergetasks=!runcode'
            }

            $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow

            if ($process.ExitCode -ne 0) {
                Write-ScriptLog "Visual Studio Code installation failed with exit code: $($process.ExitCode)" -Level 'Error'
                throw "Visual Studio Code installation failed"
            }

            Write-ScriptLog "Visual Studio Code installed successfully"
        }

        # Clean up installer
        if (Test-Path $installerPath) {
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        }

    } elseif ($IsLinux) {
        Write-ScriptLog "Installing Visual Studio Code for Linux..."

        # Detect package manager and install
        if (Get-Command apt-get -ErrorAction SilentlyContinue) {
            # Debian/Ubuntu
            wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
            sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
            sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'

            sudo apt-get update
            sudo apt-get install -y code

        } elseif (Get-Command yum -ErrorAction SilentlyContinue) {
            # RHEL/CentOS/Fedora
            sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
            sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'

            sudo yum install -y code

        } elseif (Get-Command snap -ErrorAction SilentlyContinue) {
            # Snap package
            sudo snap install code --classic

        } else {
            Write-ScriptLog "Unsupported Linux distribution" -Level 'Error'
            throw "Cannot install Visual Studio Code on this Linux distribution"
        }

    } elseif ($IsMacOS) {
        Write-ScriptLog "Installing Visual Studio Code for macOS..."

        if (Get-Command brew -ErrorAction SilentlyContinue) {
            # Install using Homebrew
            brew install --cask visual-studio-code
        } else {
            # Download and install manually
            $arch = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq 'Arm64') { 'darwin-arm64' } else { 'darwin' }
            $downloadUrl = "https://update.code.visualstudio.com/latest/$arch/stable"
            $zipPath = "/tmp/vscode.zip"

            Write-ScriptLog "Downloading Visual Studio Code..."
            curl -L -o $zipPath $downloadUrl

            # Extract to Applications
            unzip -q $zipPath -d /tmp/
            sudo mv "/tmp/Visual Studio Code.app" /Applications/
            rm $zipPath

            # Add to PATH
            sudo ln -sf "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" /usr/local/bin/code
        }
    } else {
        Write-ScriptLog "Unsupported operating system" -Level 'Error'
        throw "Cannot install Visual Studio Code on this platform"
    }

    # Install extensions if specified
    if ($vscodeConfig.Extensions -and $vscodeConfig.Extensions.Count -gt 0) {
        Write-ScriptLog "Installing Visual Studio Code extensions..."

        # Wait a moment for VSCode to be available
        Start-Sleep -Seconds 2

        foreach ($extension in $vscodeConfig.Extensions) {
            try {
                Write-ScriptLog "Installing extension: $extension"
                & $codeCmd --install-extension $extension --force

                if ($LASTEXITCODE -ne 0) {
                    Write-ScriptLog "Failed to install extension: $extension" -Level 'Warning'
                }
            } catch {
                Write-ScriptLog "Error installing extension $extension : $_" -Level 'Warning'
            }
        }
    }

    # Verify installation
    try {
        $codeVersion = & $codeCmd --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "Visual Studio Code installation verified"
            Write-ScriptLog $($codeVersion -join ' ') -Level 'Debug'
        }
    } catch {
        Write-ScriptLog "Visual Studio Code installed but command not yet available in PATH" -Level 'Warning'
    }

    Write-ScriptLog "Visual Studio Code installation completed successfully"
    exit 0

} catch {
    Write-ScriptLog "Visual Studio Code installation failed: $_" -Level 'Error'
    exit 1
}
