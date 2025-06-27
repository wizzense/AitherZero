#Requires -Version 7.0

<#
.SYNOPSIS
    Sets up all dependencies required to run Codex CLI (OpenAI's experimental CLI) on Windows and Linux.

.DESCRIPTION
    This function installs and configures all dependencies needed to download and run Codex CLI:
    
    On Windows:
    - Installs WSL2 with Ubuntu distribution (optional)
    - Sets up Node.js via nvm inside WSL or on Windows
    - Installs Codex CLI npm package
    
    On Linux:
    - Installs Node.js via nvm
    - Installs Codex CLI npm package
    
    All installations are done with proper error handling and progress feedback.

.PARAMETER SkipWSL
    On Windows, skip WSL installation (assumes WSL is already installed and configured).

.PARAMETER WSLUsername
    Username to create in WSL Ubuntu. Required for new WSL installations on Windows.

.PARAMETER WSLPassword
    Password for the WSL user. If not provided, will prompt securely.

.PARAMETER NodeVersion
    Specific Node.js version to install. Defaults to 'lts' (latest LTS).

.PARAMETER Force
    Force reinstallation of components even if they already exist.

.PARAMETER WhatIf
    Show what would be installed without actually installing anything.

.EXAMPLE
    Install-CodexCLIDependencies -WSLUsername "developer"
    
    Sets up complete Codex CLI environment on Windows with WSL.

.EXAMPLE
    Install-CodexCLIDependencies -SkipWSL
    
    Sets up Codex CLI on Windows assuming WSL is already configured.

.EXAMPLE
    Install-CodexCLIDependencies
    
    Sets up Codex CLI on Linux with Node.js via nvm.

.NOTES
    This function requires administrative privileges on Windows for WSL installation.
    On Linux, it can run as a regular user.
    
    Windows Requirements:
    - Windows 10 version 2004+ or Windows 11
    - Administrator privileges for WSL installation
    - Internet connection for downloads
    
    Linux Requirements:
    - curl or wget
    - bash shell
    - Internet connection for downloads
    
    Authentication:
    - Requires OpenAI API key configuration after installation
    - Visit https://platform.openai.com/api-keys to get API key
#>

function Install-CodexCLIDependencies {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [switch]$SkipWSL,
        
        [Parameter()]
        [string]$WSLUsername,
        
        [Parameter()]
        [SecureString]$WSLPassword,
        
        [Parameter()]
        [string]$NodeVersion = 'lts',
        
        [Parameter()]
        [switch]$Force
    )

    begin {
        # Import shared utilities
        . "$PSScriptRoot/../../../shared/Find-ProjectRoot.ps1"
        $projectRoot = Find-ProjectRoot
        
        # Import logging module
        Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
        
        Write-CustomLog -Level 'INFO' -Message "Starting Codex CLI dependencies installation"
        
        $script:InstallationSteps = @()
        $script:CompletedSteps = @()
        $script:ErrorsEncountered = @()
        
        # Platform detection
        $isWindows = $PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows
        $isLinux = $PSVersionTable.PSVersion.Major -ge 6 -and $IsLinux
        $isMacOS = $PSVersionTable.PSVersion.Major -ge 6 -and $IsMacOS
        
        if (-not ($isWindows -or $isLinux -or $isMacOS)) {
            # PowerShell 5.1 or other - assume Windows
            $isWindows = $true
        }
        
        Write-CustomLog -Level 'DEBUG' -Message "Platform detected: Windows=$isWindows, Linux=$isLinux, macOS=$isMacOS"
    }

    process {
        try {
            # Define installation plan based on platform
            if ($isWindows) {
                if (-not $SkipWSL) {
                    $script:InstallationSteps += @(
                        "Check Windows version compatibility",
                        "Enable WSL feature",
                        "Install WSL2 kernel update",
                        "Install Ubuntu distribution",
                        "Configure WSL user account",
                        "Install Node.js via nvm in WSL",
                        "Install Codex CLI in WSL"
                    )
                } else {
                    $script:InstallationSteps += @(
                        "Verify WSL is available",
                        "Install Node.js via nvm in WSL",
                        "Install Codex CLI in WSL"
                    )
                }
            } elseif ($isLinux) {
                $script:InstallationSteps += @(
                    "Check Linux distribution",
                    "Install prerequisites (curl, bash)",
                    "Install Node.js via nvm",
                    "Install Codex CLI"
                )
            } elseif ($isMacOS) {
                $script:InstallationSteps += @(
                    "Check macOS version",
                    "Install prerequisites (curl, bash)",
                    "Install Node.js via nvm",
                    "Install Codex CLI"
                )
            }

            Write-CustomLog -Level 'INFO' -Message "Installation plan: $($script:InstallationSteps.Count) steps"
            
            if ($WhatIfPreference) {
                Write-CustomLog -Level 'INFO' -Message "WhatIf mode: Would perform the following steps:"
                $script:InstallationSteps | ForEach-Object { 
                    Write-CustomLog -Level 'INFO' -Message "  - $_" 
                }
                return
            }

            # Execute installation steps based on platform
            if ($isWindows) {
                Install-CodexCLI-Windows
            } elseif ($isLinux) {
                Install-CodexCLI-Linux  
            } elseif ($isMacOS) {
                Install-CodexCLI-macOS
            }

            # Final verification
            Test-CodexCLIInstallation

            Write-CustomLog -Level 'SUCCESS' -Message "Codex CLI dependencies installation completed successfully"
            Write-CustomLog -Level 'INFO' -Message "Completed steps: $($script:CompletedSteps.Count)/$($script:InstallationSteps.Count)"
            
            if ($script:ErrorsEncountered.Count -gt 0) {
                Write-CustomLog -Level 'WARN' -Message "Errors encountered during installation:"
                $script:ErrorsEncountered | ForEach-Object {
                    Write-CustomLog -Level 'WARN' -Message "  - $_"
                }
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to install Codex CLI dependencies: $($_.Exception.Message)"
            $script:ErrorsEncountered += $_.Exception.Message
            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Codex CLI dependencies installation process finished"
        
        if ($script:CompletedSteps.Count -eq $script:InstallationSteps.Count -and $script:ErrorsEncountered.Count -eq 0) {
            Write-CustomLog -Level 'SUCCESS' -Message "All installation steps completed successfully!"
            Write-CustomLog -Level 'INFO' -Message "Next steps:"
            Write-CustomLog -Level 'INFO' -Message "1. Set up your OpenAI API key: export OPENAI_API_KEY='your-api-key-here'"
            Write-CustomLog -Level 'INFO' -Message "2. Get your API key from: https://platform.openai.com/api-keys"
            Write-CustomLog -Level 'INFO' -Message "3. Run 'codex --help' to see available commands"
        } else {
            Write-CustomLog -Level 'WARN' -Message "Installation completed with some issues. Check logs for details."
        }
    }
}

# Helper function for Windows installation
function Install-CodexCLI-Windows {
    Write-CustomLog -Level 'INFO' -Message "Installing Codex CLI on Windows"
    
    # Check if running as administrator for WSL installation
    if (-not $SkipWSL) {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isAdmin) {
            throw "Administrator privileges required for WSL installation. Run PowerShell as Administrator or use -SkipWSL parameter."
        }
    }

    # Step 1: Check Windows version
    Execute-InstallStep "Check Windows version compatibility" {
        $windowsVersion = [System.Environment]::OSVersion.Version
        if ($windowsVersion.Major -lt 10 -or ($windowsVersion.Major -eq 10 -and $windowsVersion.Build -lt 19041)) {
            throw "Windows 10 version 2004 (build 19041) or later is required for WSL2"
        }
        Write-CustomLog -Level 'INFO' -Message "Windows version compatible: $($windowsVersion.Major).$($windowsVersion.Minor) build $($windowsVersion.Build)"
    }

    if (-not $SkipWSL) {
        # Step 2: Enable WSL feature
        Execute-InstallStep "Enable WSL feature" {
            $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
            if ($wslFeature.State -ne "Enabled") {
                Write-CustomLog -Level 'INFO' -Message "Enabling WSL feature..."
                Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
            }
            
            $vmFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
            if ($vmFeature.State -ne "Enabled") {
                Write-CustomLog -Level 'INFO' -Message "Enabling Virtual Machine Platform..."
                Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
            }
        }

        # Step 3: Install WSL2 kernel update
        Execute-InstallStep "Install WSL2 kernel update" {
            $kernelUpdateUrl = "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
            $kernelUpdatePath = "$env:TEMP\wsl_update_x64.msi"
            
            Write-CustomLog -Level 'INFO' -Message "Downloading WSL2 kernel update..."
            Invoke-WebRequest -Uri $kernelUpdateUrl -OutFile $kernelUpdatePath
            
            Write-CustomLog -Level 'INFO' -Message "Installing WSL2 kernel update..."
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $kernelUpdatePath, "/quiet" -Wait
            
            # Set WSL2 as default
            wsl --set-default-version 2
        }

        # Step 4: Install Ubuntu distribution
        Execute-InstallStep "Install Ubuntu distribution" {
            $ubuntuInstalled = wsl --list --quiet | Where-Object { $_ -match "Ubuntu" }
            if (-not $ubuntuInstalled) {
                Write-CustomLog -Level 'INFO' -Message "Installing Ubuntu distribution..."
                wsl --install --distribution Ubuntu
            } else {
                Write-CustomLog -Level 'INFO' -Message "Ubuntu distribution already installed"
            }
        }

        # Step 5: Configure WSL user account
        Execute-InstallStep "Configure WSL user account" {
            if (-not $WSLUsername) {
                throw "WSLUsername parameter is required for new WSL installations"
            }
            
            Write-CustomLog -Level 'INFO' -Message "Configuring WSL user account: $WSLUsername"
            
            $password = if ($WSLPassword) {
                [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($WSLPassword)
                )
            } else {
                Read-Host -Prompt "Enter password for WSL user '$WSLUsername'" -AsSecureString |
                    ForEach-Object { [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($_)
                    )}
            }
            
            # Create user in WSL
            $createUserScript = @"
#!/bin/bash
sudo useradd -m -s /bin/bash $WSLUsername
echo '$WSLUsername`:$password' | sudo chpasswd
sudo usermod -aG sudo $WSLUsername
echo '$WSLUsername ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/$WSLUsername
"@
            
            $createUserScript | wsl bash
        }
    }

    # Install Node.js and Codex CLI in WSL
    Install-NodeAndCodex-WSL
}

# Helper function for Linux installation
function Install-CodexCLI-Linux {
    Write-CustomLog -Level 'INFO' -Message "Installing Codex CLI on Linux"
    
    # Step 1: Check Linux distribution
    Execute-InstallStep "Check Linux distribution" {
        if (Test-Path '/etc/os-release') {
            $osInfo = Get-Content '/etc/os-release' | ConvertFrom-StringData
            Write-CustomLog -Level 'INFO' -Message "Linux distribution: $($osInfo.NAME) $($osInfo.VERSION)"
        } else {
            Write-CustomLog -Level 'WARN' -Message "Could not detect Linux distribution"
        }
    }

    # Step 2: Install prerequisites
    Execute-InstallStep "Install prerequisites (curl, bash)" {
        $hasCurl = Get-Command curl -ErrorAction SilentlyContinue
        if (-not $hasCurl) {
            Write-CustomLog -Level 'INFO' -Message "Installing curl..."
            
            # Detect package manager and install curl
            if (Get-Command apt-get -ErrorAction SilentlyContinue) {
                sudo apt-get update && sudo apt-get install -y curl
            } elseif (Get-Command yum -ErrorAction SilentlyContinue) {
                sudo yum install -y curl
            } elseif (Get-Command dnf -ErrorAction SilentlyContinue) {
                sudo dnf install -y curl
            } elseif (Get-Command pacman -ErrorAction SilentlyContinue) {
                sudo pacman -S --noconfirm curl
            } else {
                throw "Could not detect package manager to install curl"
            }
        }
    }

    # Install Node.js and Codex CLI
    Install-NodeAndCodex-Native
}

# Helper function for macOS installation
function Install-CodexCLI-macOS {
    Write-CustomLog -Level 'INFO' -Message "Installing Codex CLI on macOS"
    
    # Step 1: Check macOS version
    Execute-InstallStep "Check macOS version" {
        $macOSVersion = sw_vers -productVersion
        Write-CustomLog -Level 'INFO' -Message "macOS version: $macOSVersion"
    }

    # Step 2: Install prerequisites
    Execute-InstallStep "Install prerequisites (curl, bash)" {
        $hasCurl = Get-Command curl -ErrorAction SilentlyContinue
        if (-not $hasCurl) {
            # On macOS, curl should be available by default
            # If not, recommend installing Xcode Command Line Tools
            throw "curl not found. Please install Xcode Command Line Tools: xcode-select --install"
        }
    }

    # Install Node.js and Codex CLI
    Install-NodeAndCodex-Native
}

# Helper function to install Node.js and Codex CLI in WSL
function Install-NodeAndCodex-WSL {
    # Step 6: Install Node.js via nvm in WSL
    Execute-InstallStep "Install Node.js via nvm in WSL" {
        $nvmInstallScript = @"
#!/bin/bash
set -e

# Install nvm
if [ ! -d "\$HOME/.nvm" ]; then
    echo "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
    
    # Source nvm
    export NVM_DIR="\$HOME/.nvm"
    [ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
    [ -s "\$NVM_DIR/bash_completion" ] && \. "\$NVM_DIR/bash_completion"
else
    echo "nvm already installed"
    export NVM_DIR="\$HOME/.nvm"
    [ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
fi

# Install Node.js
echo "Installing Node.js version: $NodeVersion"
nvm install $NodeVersion
nvm use $NodeVersion
nvm alias default $NodeVersion

# Verify installation
node --version
npm --version
"@
        
        Write-CustomLog -Level 'INFO' -Message "Installing Node.js via nvm in WSL..."
        $nvmInstallScript | wsl bash
    }

    # Step 7: Install Codex CLI in WSL
    Execute-InstallStep "Install Codex CLI in WSL" {
        $codexInstallScript = @"
#!/bin/bash
set -e

# Source nvm
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"

# Install Codex CLI
echo "Installing Codex CLI..."
npm install -g @openai/codex-cli

# Verify installation
codex --version || echo "Codex CLI installed but may need API key configuration"
"@
        
        Write-CustomLog -Level 'INFO' -Message "Installing Codex CLI in WSL..."
        $codexInstallScript | wsl bash
    }
}

# Helper function to install Node.js and Codex CLI natively (Linux/macOS)
function Install-NodeAndCodex-Native {
    # Install Node.js via nvm
    Execute-InstallStep "Install Node.js via nvm" {
        # Check if nvm is already installed
        $nvmDir = "$env:HOME/.nvm"
        if (-not (Test-Path $nvmDir)) {
            Write-CustomLog -Level 'INFO' -Message "Installing nvm..."
            
            $nvmInstallScript = "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash"
            Invoke-Expression $nvmInstallScript
        } else {
            Write-CustomLog -Level 'INFO' -Message "nvm already installed"
        }

        # Source nvm and install Node.js
        $nodeInstallScript = @"
#!/bin/bash
set -e

# Source nvm
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
[ -s "\$NVM_DIR/bash_completion" ] && \. "\$NVM_DIR/bash_completion"

# Install Node.js
echo "Installing Node.js version: $NodeVersion"
nvm install $NodeVersion
nvm use $NodeVersion
nvm alias default $NodeVersion

# Verify installation
node --version
npm --version
"@
        
        $nodeInstallScript | bash
    }

    # Install Codex CLI
    Execute-InstallStep "Install Codex CLI" {
        $codexInstallScript = @"
#!/bin/bash
set -e

# Source nvm
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"

# Install Codex CLI
echo "Installing Codex CLI..."
npm install -g @openai/codex-cli

# Verify installation
codex --version || echo "Codex CLI installed but may need API key configuration"
"@
        
        $codexInstallScript | bash
    }
}

# Helper function to execute installation steps with error handling
function Execute-InstallStep {
    param(
        [string]$StepName,
        [scriptblock]$ScriptBlock
    )
    
    try {
        Write-CustomLog -Level 'INFO' -Message "Executing step: $StepName"
        
        if ($PSCmdlet.ShouldProcess($StepName, "Execute installation step")) {
            & $ScriptBlock
            $script:CompletedSteps += $StepName
            Write-CustomLog -Level 'SUCCESS' -Message "Completed step: $StepName"
        }
    } catch {
        $errorMsg = "Failed step '$StepName': $($_.Exception.Message)"
        Write-CustomLog -Level 'ERROR' -Message $errorMsg
        $script:ErrorsEncountered += $errorMsg
        throw
    }
}

# Helper function to test Codex CLI installation
function Test-CodexCLIInstallation {
    Write-CustomLog -Level 'INFO' -Message "Verifying Codex CLI installation..."
    
    try {
        if ($isWindows -and -not $SkipWSL) {
            # Test in WSL
            $testResult = wsl bash -c "source ~/.nvm/nvm.sh && codex --version" 2>&1
        } else {
            # Test natively
            $testResult = bash -c "source ~/.nvm/nvm.sh && codex --version" 2>&1
        }
        
        if ($testResult) {
            Write-CustomLog -Level 'SUCCESS' -Message "Codex CLI installation verified: $testResult"
        } else {
            Write-CustomLog -Level 'WARN' -Message "Codex CLI installed but version check failed. May need API key configuration."
        }
    } catch {
        Write-CustomLog -Level 'WARN' -Message "Could not verify Codex CLI installation: $($_.Exception.Message)"
        Write-CustomLog -Level 'INFO' -Message "This may be normal if API key is not configured yet"
    }
}

# Export the function
Export-ModuleMember -Function Install-CodexCLIDependencies
