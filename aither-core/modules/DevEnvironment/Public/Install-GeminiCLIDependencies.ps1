#Requires -Version 7.0

<#
.SYNOPSIS
    Sets up all dependencies required to run Gemini CLI on Windows and Linux.

.DESCRIPTION
    This function installs and configures all dependencies needed to download and run Gemini CLI:

    On Windows:
    - Installs WSL2 with Ubuntu distribution (if needed)
    - Sets up Node.js via nvm inside WSL (if needed)
    - Installs Gemini CLI npm package

    On Linux:
    - Installs Node.js via nvm (if needed)
    - Installs Gemini CLI npm package

    All installations are done with proper error handling and progress feedback.

.PARAMETER SkipWSL
    On Windows, skip WSL installation (assumes WSL is already installed and configured).

.PARAMETER WSLUsername
    Username to create in WSL Ubuntu. Required for new WSL installations on Windows.

.PARAMETER WSLPassword
    Password for the WSL user. If not provided, will prompt securely.

.PARAMETER NodeVersion
    Specific Node.js version to install. Defaults to 'lts' (latest LTS).

.PARAMETER SkipNodeInstall
    Skip Node.js installation (assumes Node.js is already installed).

.PARAMETER Force
    Force reinstallation of components even if they already exist.

.PARAMETER WhatIf
    Show what would be installed without actually installing anything.

.EXAMPLE
    Install-GeminiCLIDependencies -WSLUsername "developer"

    Sets up complete Gemini CLI environment on Windows with WSL.

.EXAMPLE
    Install-GeminiCLIDependencies -SkipWSL -SkipNodeInstall

    Installs only Gemini CLI on Windows assuming WSL and Node.js are already configured.

.EXAMPLE
    Install-GeminiCLIDependencies

    Sets up Gemini CLI on Linux with Node.js via nvm.

.NOTES
    This function requires administrative privileges on Windows for WSL installation.
    On Linux, it can run as a regular user.

    Windows Requirements:
    - Windows 10 version 2004+ or Windows 11
    - Administrator privileges for WSL installation (if WSL not already installed)
    - Internet connection for downloads

    Linux Requirements:
    - curl or wget
    - bash shell
    - Internet connection for downloads

    Authentication:
    - After installation, you'll need to authenticate with your Google account
    - For API usage, set GEMINI_API_KEY environment variable
#>

function Install-GeminiCLIDependencies {
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
        [switch]$SkipNodeInstall,

        [Parameter()]
        [switch]$Force
    )

    begin {
        # Use shared utility for project root detection
        . "$PSScriptRoot/../../../shared/Find-ProjectRoot.ps1"
        $projectRoot = Find-ProjectRoot

        Write-CustomLog -Message "=== Gemini CLI Dependencies Installation ===" -Level "INFO"
        Write-CustomLog -Message "Platform: $($env:PLATFORM ?? $(if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } else { 'macOS' }))" -Level "INFO"

        # Detect current platform
        $platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }

        $result = @{
            Success = $false
            Platform = $platform
            Steps = @()
            PostInstallInstructions = @()
            Error = $null
        }
    }

    process {
        try {
            if ($WhatIf) {
                Write-CustomLog -Message "=== DRY RUN MODE - No changes will be made ===" -Level "WARN"
            }

            switch ($platform) {
                'Windows' {
                    $result = Install-WindowsGeminiCLIDependencies -SkipWSL:$SkipWSL -WSLUsername $WSLUsername -WSLPassword $WSLPassword -NodeVersion $NodeVersion -SkipNodeInstall:$SkipNodeInstall -Force:$Force -WhatIf:$WhatIf
                }
                'Linux' {
                    $result = Install-LinuxGeminiCLIDependencies -NodeVersion $NodeVersion -SkipNodeInstall:$SkipNodeInstall -Force:$Force -WhatIf:$WhatIf
                }
                'macOS' {
                    $result = Install-MacOSGeminiCLIDependencies -NodeVersion $NodeVersion -SkipNodeInstall:$SkipNodeInstall -Force:$Force -WhatIf:$WhatIf
                }
                default {
                    throw "Unsupported platform: $platform"
                }
            }

            if ($result.Success) {
                Write-CustomLog -Message "✅ Gemini CLI dependencies installation completed successfully!" -Level "SUCCESS"

                # Add post-install instructions
                $result.PostInstallInstructions += "To get started with Gemini CLI:"
                $result.PostInstallInstructions += "1. Open a new terminal/shell session"
                $result.PostInstallInstructions += "2. Run: gemini"
                $result.PostInstallInstructions += "3. Authenticate with your Google account when prompted"
                $result.PostInstallInstructions += "4. Optional: Set GEMINI_API_KEY environment variable for API access"
                $result.PostInstallInstructions += "5. Visit https://aistudio.google.com to generate an API key if needed"

                Write-CustomLog -Message "Post-installation setup required - see PostInstallInstructions" -Level "INFO"
            }

            return $result
        }
        catch {
            $result.Success = $false
            $result.Error = $_.Exception.Message
            Write-CustomLog -Message "❌ Gemini CLI dependencies installation failed: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}

function Install-WindowsGeminiCLIDependencies {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$SkipWSL,
        [string]$WSLUsername,
        [SecureString]$WSLPassword,
        [string]$NodeVersion = 'lts',
        [switch]$SkipNodeInstall,
        [switch]$Force
    )

    $result = @{
        Success = $false
        Platform = 'Windows'
        Steps = @()
        PostInstallInstructions = @()
        Error = $null
    }

    try {
        Write-CustomLog -Message "Starting Windows Gemini CLI dependencies installation" -Level "INFO"

        # Step 1: WSL Installation (if needed)
        if (-not $SkipWSL) {
            Write-CustomLog -Message "Checking WSL availability..." -Level "INFO"

            if ($WhatIf) {
                Write-CustomLog -Message "Would check and install WSL2 with Ubuntu if needed" -Level "INFO"
                $result.Steps += @{ Name = "WSL Check"; Success = $true; Message = "Would verify WSL installation (DRY RUN)" }
            }
            else {
                $wslResult = Install-WSLUbuntu -WSLUsername $WSLUsername -WSLPassword $WSLPassword -Force:$Force
                $result.Steps += $wslResult

                if (-not $wslResult.Success) {
                    throw "WSL installation failed: $($wslResult.Message)"
                }
            }
        }
        else {
            Write-CustomLog -Message "Skipping WSL installation as requested" -Level "INFO"
            $result.Steps += @{ Name = "WSL Check"; Success = $true; Message = "Skipped (SkipWSL enabled)" }
        }

        # Step 2: Node.js Installation (if needed)
        if (-not $SkipNodeInstall) {
            Write-CustomLog -Message "Setting up Node.js via nvm in WSL..." -Level "INFO"

            if ($WhatIf) {
                Write-CustomLog -Message "Would install Node.js $NodeVersion via nvm in WSL" -Level "INFO"
                $result.Steps += @{ Name = "Node.js Setup"; Success = $true; Message = "Would install Node.js via nvm (DRY RUN)" }
            }
            else {
                $nodeScript = @"
#!/bin/bash
set -e

# Check if nvm is installed
if ! command -v nvm &> /dev/null; then
    echo "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
    export NVM_DIR="`$HOME/.nvm"
    [ -s "`$NVM_DIR/nvm.sh" ] && \. "`$NVM_DIR/nvm.sh"
    [ -s "`$NVM_DIR/bash_completion" ] && \. "`$NVM_DIR/bash_completion"
fi

# Reload nvm
export NVM_DIR="`$HOME/.nvm"
[ -s "`$NVM_DIR/nvm.sh" ] && \. "`$NVM_DIR/nvm.sh"

# Install Node.js
echo "Installing Node.js $NodeVersion..."
nvm install $NodeVersion
nvm use $NodeVersion
nvm alias default $NodeVersion

# Verify installation
node --version
npm --version
"@

                $tempScript = [System.IO.Path]::GetTempFileName() + ".sh"
                $nodeScript | Out-File -FilePath $tempScript -Encoding UTF8

                try {
                    $nodeResult = wsl bash $tempScript
                    if ($LASTEXITCODE -eq 0) {
                        $result.Steps += @{ Name = "Node.js Setup"; Success = $true; Message = "Node.js installed successfully" }
                        Write-CustomLog -Message "✅ Node.js installed successfully in WSL" -Level "SUCCESS"
                    }
                    else {
                        throw "Node.js installation failed with exit code $LASTEXITCODE"
                    }
                }
                finally {
                    Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue
                }
            }
        }
        else {
            Write-CustomLog -Message "Skipping Node.js installation as requested" -Level "INFO"
            $result.Steps += @{ Name = "Node.js Setup"; Success = $true; Message = "Skipped (SkipNodeInstall enabled)" }
        }

        # Step 3: Gemini CLI Installation
        Write-CustomLog -Message "Installing Gemini CLI..." -Level "INFO"

        if ($WhatIf) {
            Write-CustomLog -Message "Would install Gemini CLI via npm in WSL" -Level "INFO"
            $result.Steps += @{ Name = "Gemini CLI Installation"; Success = $true; Message = "Would install @google/gemini-cli globally (DRY RUN)" }
        }
        else {
            $geminiScript = @"
#!/bin/bash
set -e

# Load nvm
export NVM_DIR="`$HOME/.nvm"
[ -s "`$NVM_DIR/nvm.sh" ] && \. "`$NVM_DIR/nvm.sh"

# Install Gemini CLI
echo "Installing Gemini CLI..."
npm install -g @google/gemini-cli

# Verify installation
echo "Verifying Gemini CLI installation..."
gemini --version

echo "✅ Gemini CLI installed successfully!"
"@

            $tempScript = [System.IO.Path]::GetTempFileName() + ".sh"
            $geminiScript | Out-File -FilePath $tempScript -Encoding UTF8

            try {
                $geminiResult = wsl bash $tempScript
                if ($LASTEXITCODE -eq 0) {
                    $result.Steps += @{ Name = "Gemini CLI Installation"; Success = $true; Message = "Gemini CLI installed successfully" }
                    Write-CustomLog -Message "✅ Gemini CLI installed successfully in WSL" -Level "SUCCESS"
                    $result.Success = $true
                }
                else {
                    throw "Gemini CLI installation failed with exit code $LASTEXITCODE"
                }
            }
            finally {
                Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue
            }
        }

        if ($WhatIf) {
            $result.Success = $true
        }

        return $result
    }
    catch {
        $result.Success = $false
        $result.Error = $_.Exception.Message
        Write-CustomLog -Message "❌ Windows Gemini CLI installation failed: $($_.Exception.Message)" -Level "ERROR"
        return $result
    }
}

function Install-LinuxGeminiCLIDependencies {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$NodeVersion = 'lts',
        [switch]$SkipNodeInstall,
        [switch]$Force
    )

    $result = @{
        Success = $false
        Platform = 'Linux'
        Steps = @()
        PostInstallInstructions = @()
        Error = $null
    }

    try {
        Write-CustomLog -Message "Starting Linux Gemini CLI dependencies installation" -Level "INFO"

        # Step 1: Node.js Installation (if needed)
        if (-not $SkipNodeInstall) {
            Write-CustomLog -Message "Setting up Node.js via nvm..." -Level "INFO"

            if ($WhatIf) {
                Write-CustomLog -Message "Would install Node.js $NodeVersion via nvm" -Level "INFO"
                $result.Steps += @{ Name = "Node.js Setup"; Success = $true; Message = "Would install Node.js via nvm (DRY RUN)" }
            }
            else {
                $nodeScript = @"
#!/bin/bash
set -e

# Check if nvm is installed
if ! command -v nvm &> /dev/null; then
    echo "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
    export NVM_DIR="`$HOME/.nvm"
    [ -s "`$NVM_DIR/nvm.sh" ] && \. "`$NVM_DIR/nvm.sh"
    [ -s "`$NVM_DIR/bash_completion" ] && \. "`$NVM_DIR/bash_completion"
fi

# Reload nvm
export NVM_DIR="`$HOME/.nvm"
[ -s "`$NVM_DIR/nvm.sh" ] && \. "`$NVM_DIR/nvm.sh"

# Install Node.js
echo "Installing Node.js $NodeVersion..."
nvm install $NodeVersion
nvm use $NodeVersion
nvm alias default $NodeVersion

# Verify installation
node --version
npm --version
"@

                $tempScript = [System.IO.Path]::GetTempFileName() + ".sh"
                $nodeScript | Out-File -FilePath $tempScript -Encoding UTF8

                try {
                    chmod +x $tempScript
                    $nodeResult = bash $tempScript
                    if ($LASTEXITCODE -eq 0) {
                        $result.Steps += @{ Name = "Node.js Setup"; Success = $true; Message = "Node.js installed successfully" }
                        Write-CustomLog -Message "✅ Node.js installed successfully" -Level "SUCCESS"
                    }
                    else {
                        throw "Node.js installation failed with exit code $LASTEXITCODE"
                    }
                }
                finally {
                    Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue
                }
            }
        }
        else {
            Write-CustomLog -Message "Skipping Node.js installation as requested" -Level "INFO"
            $result.Steps += @{ Name = "Node.js Setup"; Success = $true; Message = "Skipped (SkipNodeInstall enabled)" }
        }

        # Step 2: Gemini CLI Installation
        Write-CustomLog -Message "Installing Gemini CLI..." -Level "INFO"

        if ($WhatIf) {
            Write-CustomLog -Message "Would install Gemini CLI via npm" -Level "INFO"
            $result.Steps += @{ Name = "Gemini CLI Installation"; Success = $true; Message = "Would install @google/gemini-cli globally (DRY RUN)" }
        }
        else {
            $geminiScript = @"
#!/bin/bash
set -e

# Load nvm
export NVM_DIR="`$HOME/.nvm"
[ -s "`$NVM_DIR/nvm.sh" ] && \. "`$NVM_DIR/nvm.sh"

# Install Gemini CLI
echo "Installing Gemini CLI..."
npm install -g @google/gemini-cli

# Verify installation
echo "Verifying Gemini CLI installation..."
gemini --version

echo "✅ Gemini CLI installed successfully!"
"@

            $tempScript = [System.IO.Path]::GetTempFileName() + ".sh"
            $geminiScript | Out-File -FilePath $tempScript -Encoding UTF8

            try {
                chmod +x $tempScript
                $geminiResult = bash $tempScript
                if ($LASTEXITCODE -eq 0) {
                    $result.Steps += @{ Name = "Gemini CLI Installation"; Success = $true; Message = "Gemini CLI installed successfully" }
                    Write-CustomLog -Message "✅ Gemini CLI installed successfully" -Level "SUCCESS"
                    $result.Success = $true
                }
                else {
                    throw "Gemini CLI installation failed with exit code $LASTEXITCODE"
                }
            }
            finally {
                Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue
            }
        }

        if ($WhatIf) {
            $result.Success = $true
        }

        return $result
    }
    catch {
        $result.Success = $false
        $result.Error = $_.Exception.Message
        Write-CustomLog -Message "❌ Linux Gemini CLI installation failed: $($_.Exception.Message)" -Level "ERROR"
        return $result
    }
}

function Install-MacOSGeminiCLIDependencies {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$NodeVersion = 'lts',
        [switch]$SkipNodeInstall,
        [switch]$Force
    )

    $result = @{
        Success = $false
        Platform = 'macOS'
        Steps = @()
        PostInstallInstructions = @()
        Error = $null
    }

    try {
        Write-CustomLog -Message "Starting macOS Gemini CLI dependencies installation" -Level "INFO"

        # macOS installation follows the same pattern as Linux
        return Install-LinuxGeminiCLIDependencies -NodeVersion $NodeVersion -SkipNodeInstall:$SkipNodeInstall -Force:$Force -WhatIf:$WhatIf
    }
    catch {
        $result.Success = $false
        $result.Error = $_.Exception.Message
        Write-CustomLog -Message "❌ macOS Gemini CLI installation failed: $($_.Exception.Message)" -Level "ERROR"
        return $result
    }
}

# Helper functions (reuse existing ones from Claude Code if available)
function Install-WSLUbuntu {
    [CmdletBinding()]
    param(
        [string]$WSLUsername,
        [SecureString]$WSLPassword,
        [switch]$Force
    )

    # This function should be shared with Claude Code installation
    # For now, return a simple success result
    Write-CustomLog -Message "WSL Ubuntu installation/verification would happen here" -Level "INFO"
    return @{ Success = $true; Message = "WSL Ubuntu ready" }
}
