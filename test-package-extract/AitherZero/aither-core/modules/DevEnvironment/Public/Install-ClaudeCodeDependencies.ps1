#Requires -Version 7.0

<#
.SYNOPSIS
    Sets up all dependencies required to run Claude Code on Windows and Linux.

.DESCRIPTION
    This function installs and configures all dependencies needed to download and run Claude Code:

    On Windows:
    - Installs WSL2 with Ubuntu distribution
    - Sets up Node.js via nvm inside WSL
    - Installs Claude Code npm package

    On Linux:
    - Installs Node.js via nvm
    - Installs Claude Code npm package

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
    Install-ClaudeCodeDependencies -WSLUsername "developer"

    Sets up complete Claude Code environment on Windows with WSL.

.EXAMPLE
    Install-ClaudeCodeDependencies -SkipWSL

    Sets up Claude Code on Windows assuming WSL is already configured.

.EXAMPLE
    Install-ClaudeCodeDependencies

    Sets up Claude Code on Linux with Node.js via nvm.

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
#>

function Install-ClaudeCodeDependencies {
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
        # Use shared utility for project root detection
        . "$PSScriptRoot/../../../shared/Find-ProjectRoot.ps1"
        $projectRoot = Find-ProjectRoot

        Write-CustomLog -Message "=== Claude Code Dependencies Installation ===" -Level "INFO"
        Write-CustomLog -Message "Platform: $($env:PLATFORM ?? $(if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } else { 'macOS' }))" -Level "INFO"

        # Detect current platform
        $platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }

        if ($platform -eq 'Unknown') {
            throw "Unsupported platform detected. This function supports Windows and Linux only."
        }

        if ($platform -eq 'macOS') {
            Write-CustomLog -Message "macOS detected. This function currently supports Windows and Linux only." -Level "WARN"
            Write-CustomLog -Message "For macOS, please install Node.js manually and run: npm install -g @anthropic-ai/claude-code" -Level "INFO"
            return
        }
    }

    process {
        try {
            # Import AIToolsIntegration module for enhanced installation
            try {
                Import-Module (Join-Path $projectRoot "aither-core/modules/AIToolsIntegration") -Force -ErrorAction Stop
                Write-CustomLog -Message "✅ AIToolsIntegration module loaded" -Level "SUCCESS"

                # Use enhanced AI tools installation
                $nodeCheck = Test-NodeJsPrerequisites
                if ($nodeCheck.Success) {
                    Write-CustomLog -Message "✅ Node.js prerequisites already met" -Level "SUCCESS"

                    # Install Claude Code using enhanced function
                    $claudeResult = Install-ClaudeCode -Force:$Force -ConfigureIntegration -WhatIf:$WhatIf
                    if ($claudeResult.Success) {
                        Write-CustomLog -Message "✅ Claude Code installation completed via AIToolsIntegration module" -Level "SUCCESS"
                        return $claudeResult
                    } else {
                        Write-CustomLog -Message "⚠️ AIToolsIntegration installation failed, falling back to platform-specific method" -Level "WARNING"
                    }
                } else {
                    Write-CustomLog -Message "📋 Node.js prerequisites not met, installing dependencies first" -Level "INFO"
                    Write-CustomLog -Message "Node.js check: $($nodeCheck.Message)" -Level "INFO"
                }
            } catch {
                Write-CustomLog -Message "⚠️ Failed to load AIToolsIntegration module, using legacy installation method" -Level "WARNING"
            }

            # Platform-specific installation (legacy method or Node.js setup)
            if ($platform -eq 'Windows') {
                Install-WindowsClaudeCodeDependencies -SkipWSL:$SkipWSL -WSLUsername $WSLUsername -WSLPassword $WSLPassword -NodeVersion $NodeVersion -Force:$Force -WhatIf:$WhatIf
            } elseif ($platform -eq 'Linux') {
                Install-LinuxClaudeCodeDependencies -NodeVersion $NodeVersion -Force:$Force -WhatIf:$WhatIf
            }

            # Final verification and configuration
            $claudeCmd = Get-Command claude-code -ErrorAction SilentlyContinue
            if ($claudeCmd) {
                Write-CustomLog -Message "✅ Claude Code dependencies installation completed successfully!" -Level "SUCCESS"
                Write-CustomLog -Message "Claude Code available at: $($claudeCmd.Source)" -Level "INFO"

                # Try to configure integration if AIToolsIntegration is available
                if (Get-Module -Name "AIToolsIntegration" -ErrorAction SilentlyContinue) {
                    try {
                        Configure-ClaudeCodeIntegration
                        Write-CustomLog -Message "✅ Claude Code integration configured" -Level "SUCCESS"
                    } catch {
                        Write-CustomLog -Message "⚠️ Failed to configure Claude Code integration: $($_.Exception.Message)" -Level "WARNING"
                    }
                }

                Write-CustomLog -Message "You can now run Claude Code using: claude-code" -Level "INFO"
            } else {
                Write-CustomLog -Message "⚠️ Claude Code installation completed but command not found in PATH" -Level "WARNING"
                Write-CustomLog -Message "You may need to restart your terminal or reload your PATH" -Level "INFO"
            }

        } catch {
            Write-CustomLog -Message "❌ Failed to install Claude Code dependencies: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}

function Install-WindowsClaudeCodeDependencies {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$SkipWSL,
        [string]$WSLUsername,
        [SecureString]$WSLPassword,
        [string]$NodeVersion,
        [switch]$Force
    )

    Write-CustomLog -Message "🪟 Setting up Claude Code dependencies on Windows..." -Level "INFO"

    # Check if we're running as administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

    if (-not $SkipWSL -and -not $isAdmin) {
        Write-CustomLog -Message "❌ Administrator privileges required for WSL installation." -Level "ERROR"
        Write-CustomLog -Message "Please run PowerShell as Administrator or use -SkipWSL if WSL is already installed." -Level "INFO"
        throw "Administrator privileges required for WSL installation"
    }

    # Step 1: Install/Configure WSL
    if (-not $SkipWSL) {
        Install-WSLUbuntu -Username $WSLUsername -Password $WSLPassword -Force:$Force -WhatIf:$WhatIf
    } else {
        Write-CustomLog -Message "📋 Skipping WSL installation as requested" -Level "INFO"
        Test-WSLAvailability
    }

    # Step 2: Install Node.js and Claude Code in WSL
    Install-NodeJSInWSL -NodeVersion $NodeVersion -Force:$Force -WhatIf:$WhatIf
    Install-ClaudeCodeInWSL -Force:$Force -WhatIf:$WhatIf
}

function Install-LinuxClaudeCodeDependencies {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$NodeVersion,
        [switch]$Force
    )

    Write-CustomLog -Message "🐧 Setting up Claude Code dependencies on Linux..." -Level "INFO"

    # Step 1: Install Node.js via nvm
    Install-NodeJSLinux -NodeVersion $NodeVersion -Force:$Force -WhatIf:$WhatIf

    # Step 2: Install Claude Code npm package
    Install-ClaudeCodeLinux -Force:$Force -WhatIf:$WhatIf
}

function Install-WSLUbuntu {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Username,
        [SecureString]$Password,
        [switch]$Force
    )

    Write-CustomLog -Message "🔧 Installing WSL2 with Ubuntu..." -Level "INFO"

    if ($WhatIf) {
        Write-CustomLog -Message "[WHATIF] Would install WSL2 and Ubuntu distribution" -Level "INFO"
        return
    }

    try {
        # Check if WSL is already installed
        $wslInstalled = $false
        try {
            $wslOutput = wsl --list --verbose 2>$null
            if ($LASTEXITCODE -eq 0) {
                $wslInstalled = $true
                Write-CustomLog -Message "✅ WSL is already installed" -Level "SUCCESS"
            }
        } catch {
            Write-CustomLog -Message "📋 WSL not detected, will install" -Level "INFO"
        }

        if (-not $wslInstalled -or $Force) {
            if ($PSCmdlet.ShouldProcess("WSL2 and Ubuntu", "Install")) {
                Write-CustomLog -Message "Installing WSL2..." -Level "INFO"

                # Enable WSL feature
                Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
                Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart

                # Set WSL 2 as default
                wsl --set-default-version 2

                # Install Ubuntu
                Write-CustomLog -Message "Installing Ubuntu distribution..." -Level "INFO"
                wsl --install -d Ubuntu

                Write-CustomLog -Message "⚠️ A system restart may be required after WSL installation" -Level "WARN"
            }
        }

        # Configure Ubuntu user if username provided
        if ($Username) {
            Configure-WSLUser -Username $Username -Password $Password -WhatIf:$WhatIf
        }

    } catch {
        Write-CustomLog -Message "❌ Failed to install WSL: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Configure-WSLUser {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Username,
        [SecureString]$Password
    )

    if ($WhatIf) {
        Write-CustomLog -Message "[WHATIF] Would configure WSL user: $Username" -Level "INFO"
        return
    }

    try {
        # Convert secure string to plain text for WSL setup
        $plainPassword = ""
        if ($Password) {
            $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
        }

        if (-not $plainPassword) {
            Write-CustomLog -Message "Please set up your WSL Ubuntu user manually when prompted" -Level "INFO"
            Write-CustomLog -Message "After Ubuntu starts, create user: $Username" -Level "INFO"
        } else {
            Write-CustomLog -Message "🔧 Configuring WSL Ubuntu user: $Username" -Level "INFO"

            # Note: Actual user setup typically happens during first WSL run
            # This is handled interactively by Ubuntu
            Write-CustomLog -Message "✅ WSL user configuration prepared" -Level "SUCCESS"
        }

    } catch {
        Write-CustomLog -Message "❌ Failed to configure WSL user: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Test-WSLAvailability {
    [CmdletBinding()]
    param()

    try {
        $wslCheck = wsl --list --verbose 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-CustomLog -Message "✅ WSL is available and configured" -Level "SUCCESS"

            # Show available distributions
            $distributions = wsl --list --quiet
            Write-CustomLog -Message "Available WSL distributions: $($distributions -join ', ')" -Level "INFO"

            return $true
        } else {
            Write-CustomLog -Message "❌ WSL is not properly configured" -Level "ERROR"
            throw "WSL is not available. Please install WSL first or run without -SkipWSL."
        }
    } catch {
        Write-CustomLog -Message "❌ Failed to check WSL availability: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Install-NodeJSInWSL {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$NodeVersion,
        [switch]$Force

    )

    Write-CustomLog -Message "📦 Installing Node.js in WSL..." -Level "INFO"

    if ($WhatIf) {
        Write-CustomLog -Message "[WHATIF] Would install Node.js version $NodeVersion in WSL via nvm" -Level "INFO"
        return
    }

    try {
        if ($PSCmdlet.ShouldProcess("Node.js $NodeVersion in WSL", "Install")) {
            # Create installation script for WSL
            $installScript = @"
#!/bin/bash
set -e

echo "Installing Node.js via nvm in WSL..."

# Install nvm
if [ ! -d ~/.nvm ]; then
    echo "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
else
    echo "nvm already installed"
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi

# Install Node.js
echo "Installing Node.js $NodeVersion..."
nvm install $NodeVersion
nvm use $NodeVersion
nvm alias default $NodeVersion

# Verify installation
echo "Node.js version: `$(node --version)"
echo "npm version: `$(npm --version)"

echo "Node.js installation completed!"
"@

            # Write script to temp file and execute in WSL
            $tempScript = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $tempScript -Value $installScript -Encoding UTF8

            try {
                # Copy script to WSL and execute
                $wslPath = wsl wslpath -a $tempScript
                wsl chmod +x $wslPath
                wsl bash $wslPath

                Write-CustomLog -Message "✅ Node.js installed successfully in WSL" -Level "SUCCESS"
            } finally {
                Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Write-CustomLog -Message "❌ Failed to install Node.js in WSL: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Install-NodeJSLinux {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$NodeVersion,
        [switch]$Force

    )

    Write-CustomLog -Message "📦 Installing Node.js on Linux..." -Level "INFO"

    if ($WhatIf) {
        Write-CustomLog -Message "[WHATIF] Would install Node.js version $NodeVersion via nvm" -Level "INFO"
        return
    }

    try {
        if ($PSCmdlet.ShouldProcess("Node.js $NodeVersion", "Install")) {
            # Check if nvm is already installed
            $nvmInstalled = Test-Path "$env:HOME/.nvm/nvm.sh"

            if (-not $nvmInstalled -or $Force) {
                Write-CustomLog -Message "Installing nvm..." -Level "INFO"

                # Install nvm
                $installCmd = "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash"
                Invoke-Expression $installCmd

                # Source nvm
                $env:NVM_DIR = "$env:HOME/.nvm"
                . "$env:NVM_DIR/nvm.sh"
            } else {
                Write-CustomLog -Message "✅ nvm already installed" -Level "SUCCESS"
                $env:NVM_DIR = "$env:HOME/.nvm"
                . "$env:NVM_DIR/nvm.sh"
            }

            # Install Node.js
            Write-CustomLog -Message "Installing Node.js $NodeVersion..." -Level "INFO"

            # Use bash to ensure nvm is available
            $nodeInstallScript = @"
#!/bin/bash
export NVM_DIR="$HOME/.nvm"
[ -s "`$NVM_DIR/nvm.sh" ] && \. "`$NVM_DIR/nvm.sh"
[ -s "`$NVM_DIR/bash_completion" ] && \. "`$NVM_DIR/bash_completion"

nvm install $NodeVersion
nvm use $NodeVersion
nvm alias default $NodeVersion

echo "Node.js version: `$(node --version)"
echo "npm version: `$(npm --version)"
"@

            $tempScript = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $tempScript -Value $nodeInstallScript -Encoding UTF8

            try {
                chmod +x $tempScript
                bash $tempScript
                Write-CustomLog -Message "✅ Node.js installed successfully" -Level "SUCCESS"
            } finally {
                Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Write-CustomLog -Message "❌ Failed to install Node.js: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Install-ClaudeCodeInWSL {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$Force

    )

    Write-CustomLog -Message "🤖 Installing Claude Code in WSL..." -Level "INFO"

    if ($WhatIf) {
        Write-CustomLog -Message "[WHATIF] Would install @anthropic-ai/claude-code npm package in WSL" -Level "INFO"
        return
    }

    try {
        if ($PSCmdlet.ShouldProcess("Claude Code in WSL", "Install")) {
            # Create installation script
            $installScript = @"
#!/bin/bash
set -e

echo "Installing Claude Code..."

# Source nvm
export NVM_DIR="$HOME/.nvm"
[ -s "`$NVM_DIR/nvm.sh" ] && \. "`$NVM_DIR/nvm.sh"

# Install Claude Code globally
npm install -g @anthropic-ai/claude-code

# Upgrade npm to latest version
npm install -g npm@latest

echo "Claude Code installation completed!"
echo "You can now run: claude-code"
"@

            # Execute in WSL
            $tempScript = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $tempScript -Value $installScript -Encoding UTF8

            try {
                $wslPath = wsl wslpath -a $tempScript
                wsl chmod +x $wslPath
                wsl bash $wslPath

                Write-CustomLog -Message "✅ Claude Code installed successfully in WSL" -Level "SUCCESS"
            } finally {
                Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Write-CustomLog -Message "❌ Failed to install Claude Code in WSL: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Install-ClaudeCodeLinux {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$Force

    )

    Write-CustomLog -Message "🤖 Installing Claude Code on Linux..." -Level "INFO"

    if ($WhatIf) {
        Write-CustomLog -Message "[WHATIF] Would install @anthropic-ai/claude-code npm package" -Level "INFO"
        return
    }

    try {
        if ($PSCmdlet.ShouldProcess("Claude Code", "Install")) {
            # Create installation script
            $installScript = @"
#!/bin/bash
export NVM_DIR="$HOME/.nvm"
[ -s "`$NVM_DIR/nvm.sh" ] && \. "`$NVM_DIR/nvm.sh"
[ -s "`$NVM_DIR/bash_completion" ] && \. "`$NVM_DIR/bash_completion"

echo "Installing Claude Code..."
npm install -g @anthropic-ai/claude-code

echo "Upgrading npm to latest version..."
npm install -g npm@latest

echo "Claude Code installation completed!"
echo "You can now run: claude-code"
"@

            $tempScript = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $tempScript -Value $installScript -Encoding UTF8

            try {
                chmod +x $tempScript
                bash $tempScript
                Write-CustomLog -Message "✅ Claude Code installed successfully" -Level "SUCCESS"
            } finally {
                Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Write-CustomLog -Message "❌ Failed to install Claude Code: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}
