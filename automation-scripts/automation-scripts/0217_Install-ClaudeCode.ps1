#Requires -Version 7.0
# Stage: Development
# Dependencies: Node, Python
# Description: Install Claude Code CLI and dependencies

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

Write-ScriptLog "Starting Claude Code installation"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if Claude Code installation is enabled
    $shouldInstall = $false
    $claudeConfig = @{}

    if ($config.AITools -and $config.AITools.ClaudeCode) {
        $claudeConfig = $config.AITools.ClaudeCode
        $shouldInstall = $claudeConfig.Install -eq $true
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "Claude Code installation is not enabled in configuration"
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

    # Check if Claude Code is already installed
    $claudeCmd = Get-Command claude-code -ErrorAction SilentlyContinue

    if ($claudeCmd) {
        Write-ScriptLog "Claude Code is already installed"

        # Get version
        try {
            $version = & claude-code --version 2>&1
            Write-ScriptLog "Current version: $version"

            # Check for updates if configured
            if ($claudeConfig.CheckForUpdates -eq $true) {
                Write-ScriptLog "Checking for updates..."
                if ($PSCmdlet.ShouldProcess('claude-code', 'Update')) {
                    & npm update -g claude-code 2>&1 | ForEach-Object { Write-ScriptLog $_ -Level 'Debug' }
                }
            }
        } catch {
            Write-ScriptLog "Could not determine version" -Level 'Debug'
        }

        exit 0
    }

    Write-ScriptLog "Installing Claude Code CLI..."

    # Install via npm
    if ($PSCmdlet.ShouldProcess('claude-code', 'Install globally via npm')) {
        try {
            # Install specific version if configured
            $packageName = if ($claudeConfig.Version) {
                "claude-code@$($claudeConfig.Version)"
            } else {
                "claude-code@latest"
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
            Write-ScriptLog "Failed to install Claude Code via npm: $_" -Level 'Error'
            throw
        }
    }

    # Verify installation
    $claudeCmd = Get-Command claude-code -ErrorAction SilentlyContinue

    if (-not $claudeCmd) {
        Write-ScriptLog "Claude Code command not found after installation" -Level 'Error'
        exit 1
    }

    Write-ScriptLog "Claude Code installed successfully at: $($claudeCmd.Source)"

    # Test Claude Code
    try {
        $version = & claude-code --version 2>&1
        Write-ScriptLog "Installed version: $version"
    } catch {
        Write-ScriptLog "Claude Code installed but may not be functioning correctly" -Level 'Warning'
    }

    # Configure Claude Code if settings provided
    if ($claudeConfig.Settings) {
        Write-ScriptLog "Configuring Claude Code..."

        foreach ($setting in $claudeConfig.Settings.GetEnumerator()) {
            if ($PSCmdlet.ShouldProcess("Claude Code config $($setting.Key)", 'Configure')) {
                try {
                    & claude-code config set $setting.Key $setting.Value 2>&1 | ForEach-Object { Write-ScriptLog $_ -Level 'Debug' }
                } catch {
                    Write-ScriptLog "Failed to set config $($setting.Key): $_" -Level 'Warning'
                }
            }
        }
    }

    # Set up API key if provided
    if ($claudeConfig.ApiKey) {
        Write-ScriptLog "Configuring API key..."
        if ($PSCmdlet.ShouldProcess('Claude Code API key', 'Configure')) {
            try {
                & claude-code config set api-key $claudeConfig.ApiKey 2>&1 | ForEach-Object { Write-ScriptLog $_ -Level 'Debug' }
                Write-ScriptLog "API key configured successfully"
            } catch {
                Write-ScriptLog "Failed to configure API key: $_" -Level 'Warning'
            }
        }
    }

    # Platform-specific configuration
    if ($IsWindows -and $claudeConfig.WSLIntegration -eq $true) {
        Write-ScriptLog "Configuring WSL integration..."
        # WSL integration would be handled here if needed
    }

    Write-ScriptLog "Claude Code installation completed successfully"
    Write-ScriptLog ""
    Write-ScriptLog "Next steps:"
    Write-ScriptLog "1. Open a new terminal session"
    Write-ScriptLog "2. Run: claude-code --help"
    Write-ScriptLog "3. Set API key if not already done: claude-code config set api-key YOUR_API_KEY"
    Write-ScriptLog "4. Start using Claude Code for development!"

    exit 0

} catch {
    Write-ScriptLog "Critical error during Claude Code installation: $_" -Level 'Error'
    Write-ScriptLog $_.ScriptStackTrace -Level 'Error'
    exit 1
}