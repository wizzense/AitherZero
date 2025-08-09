#Requires -Version 7.0
# Stage: Development
# Dependencies: Node, Python
# Description: Install Google Gemini CLI and dependencies

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

Write-ScriptLog "Starting Gemini CLI installation"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if Gemini CLI installation is enabled
    $shouldInstall = $false
    $geminiConfig = @{}

    if ($config -and $config.ContainsKey('AITools') -and $config.AITools) {
        if ($config.AITools.ContainsKey('GeminiCLI') -and $config.AITools.GeminiCLI) {
            $geminiConfig = $config.AITools.GeminiCLI
            $shouldInstall = $geminiConfig.Install -eq $true
        }
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "Gemini CLI installation is not enabled in configuration"
        exit 0
    }

    # Check prerequisites
    Write-ScriptLog "Checking prerequisites..."

    # Check Node.js
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if (-not $nodeCmd) {
        Write-ScriptLog "Node.js is required but not found. Please run 0201_Install-Node.ps1 first" -Level 'Error'
        exit 1
    }

    # Check npm
    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
    if (-not $npmCmd) {
        Write-ScriptLog "npm is required but not found. Please ensure Node.js is properly installed" -Level 'Error'
        exit 1
    }
    
    Write-ScriptLog "Prerequisites satisfied"

    # Check if Gemini CLI is already installed
    $geminiCmd = Get-Command gemini -ErrorAction SilentlyContinue

    if ($geminiCmd) {
        Write-ScriptLog "Gemini CLI is already installed"
        
        # Get version
        try {
            # Check if command exists and is executable
            if (Test-Path $geminiCmd.Path) {
                $version = & $geminiCmd.Path --version 2>&1
                Write-ScriptLog "Current version: $version"
            } else {
                Write-ScriptLog "Gemini CLI path not found, may need reinstallation" -Level 'Warning'
            }

            # Check for updates if configured
            if ($geminiConfig.CheckForUpdates -eq $true) {
                Write-ScriptLog "Checking for updates..."
                if ($PSCmdlet.ShouldProcess('gemini-cli', 'Update')) {
                    & npm update -g @google/generative-ai-cli 2>&1 | ForEach-Object { Write-ScriptLog $_ -Level 'Debug' }
                }
            }
        } catch {
            Write-ScriptLog "Could not determine version" -Level 'Debug'
        }
        
        exit 0
    }
    
    Write-ScriptLog "Installing Gemini CLI..."

    # Install via npm
    if ($PSCmdlet.ShouldProcess('gemini-cli', 'Install globally via npm')) {
        try {
            # Install specific version if configured
            $packageName = if ($geminiConfig.Version) {
                "@google/generative-ai-cli@$($geminiConfig.Version)"
            } else {
                "@google/generative-ai-cli@latest"
            }
            
            Write-ScriptLog "Installing package: $packageName"

            # Run npm install
            $npmArgs = @('install', '-g', $packageName)
            & npm $npmArgs 2>&1 | ForEach-Object { Write-ScriptLog $_ -Level 'Debug' }

            # Check exit code
            if ($LASTEXITCODE -ne 0) {
                throw "npm install failed with exit code: $LASTEXITCODE"
            }
            
        } catch {
            Write-ScriptLog "Failed to install Gemini CLI via npm: $_" -Level 'Error'
            throw
        }
    }

    # Verify installation
    $geminiCmd = Get-Command gemini -ErrorAction SilentlyContinue

    if (-not $geminiCmd) {
        Write-ScriptLog "Gemini CLI command not found after installation" -Level 'Error'
        exit 1
    }
    
    Write-ScriptLog "Gemini CLI installed successfully at: $($geminiCmd.Source)"

    # Test Gemini CLI
    try {
        $version = & gemini --version 2>&1
        Write-ScriptLog "Installed version: $version"
    } catch {
        Write-ScriptLog "Gemini CLI installed but may not be functioning correctly" -Level 'Warning'
    }

    # Configure API key if provided
    if ($geminiConfig.ApiKey) {
        Write-ScriptLog "Configuring API key..."
        if ($PSCmdlet.ShouldProcess('GEMINI_API_KEY', 'Set environment variable')) {
            try {
                # Set for current session
                $env:GEMINI_API_KEY = $geminiConfig.ApiKey
                
                # Persist based on platform
                if ($IsWindows) {
                    [Environment]::SetEnvironmentVariable('GEMINI_API_KEY', $geminiConfig.ApiKey, 'User')
                } else {
                    # For Linux/macOS, add to profile
                    $profilePaths = @(
                        "~/.bashrc",
                        "~/.zshrc",
                        "~/.profile"
                    )
                
                    foreach ($profilePath in $profilePaths) {
                        $expandedPath = [System.Environment]::ExpandEnvironmentVariables($profilePath)
                        if (Test-Path $expandedPath) {
                            $exportLine = "export GEMINI_API_KEY='$($geminiConfig.ApiKey)'"
                            if (-not (Select-String -Path $expandedPath -Pattern "GEMINI_API_KEY" -Quiet)) {
                                Add-Content -Path $expandedPath -Value $exportLine
                                Write-ScriptLog "Added API key to $profilePath" -Level 'Debug'
                            }
                        }
                    }
                }
                
                Write-ScriptLog "API key configured successfully"
            } catch {
                Write-ScriptLog "Failed to configure API key: $_" -Level 'Warning'
            }
        }
    }

    # Platform-specific configuration
    if ($IsWindows -and $geminiConfig.WSLIntegration -eq $true) {
        Write-ScriptLog "Configuring WSL integration..."
        # WSL integration would be handled here if needed
    }
    
    Write-ScriptLog "Gemini CLI installation completed successfully"
    Write-ScriptLog ""
    Write-ScriptLog "Next steps:"
    Write-ScriptLog "1. Open a new terminal session"
    Write-ScriptLog "2. Run: gemini --help"
    Write-ScriptLog "3. Authenticate when prompted (first run)"

    if (-not $geminiConfig.ApiKey) {
        Write-ScriptLog "4. Set GEMINI_API_KEY environment variable"
        Write-ScriptLog "5. Get API key from: https://aistudio.google.com/app/apikey"
    }
    
    exit 0
    
} catch {
    Write-ScriptLog "Critical error during Gemini CLI installation: $_" -Level 'Error'
    Write-ScriptLog $_.ScriptStackTrace -Level 'Error'
    exit 1
}