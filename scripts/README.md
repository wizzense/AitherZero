# AitherZero Scripts Directory

This directory contains utility scripts for development environment setup and automation tasks.

## Directory Structure

```
scripts/
├── Install-DevTools.ps1       # Cross-platform development tools installer
├── Install-DevTools.README.md # Documentation for the installer script
└── install-dev-tools.sh       # Unix/Linux shell script for tool installation
```

## Overview

The scripts directory provides essential utilities for setting up development environments across different platforms.
The primary focus is on automating the installation of development tools required for working with AitherZero and
modern infrastructure automation.

## Key Components

### Install-DevTools.ps1

A comprehensive PowerShell script that installs essential development tools across Windows, Linux, and macOS.

**Tools Installed:**
- Git (version control)
- GitHub CLI (`gh` command)
- Node.js and npm (via nvm)
- Claude Code (Anthropic AI CLI)
- PowerShell 7 (cross-platform shell)

**Platform-Specific Behavior:**
- **Windows**: Installs/configures WSL2 with Ubuntu, then installs tools within WSL
- **Linux**: Direct installation using native package managers
- **macOS**: Installation using Homebrew

**Key Features:**
- Full integration with AitherZero modules (Logging, DevEnvironment)
- Fallback mode for standalone operation
- Cross-platform compatibility
- WhatIf mode for previewing changes
- Comprehensive error handling and logging

### install-dev-tools.sh

A Bash script that handles the Unix/Linux side of tool installation. Called by the PowerShell script when running in WSL or directly on Linux/macOS systems.

**Features:**
- Automatic OS and distribution detection
- Package manager abstraction (apt, dnf/yum, pacman, brew)
- Node.js installation via nvm for version management
- Verification of all installations
- Post-installation configuration guidance

### Install-DevTools.README.md

Detailed documentation for the PowerShell installer script, including:
- AitherZero integration details
- Module usage patterns
- Parameter documentation
- Error handling approaches

## Usage

### Windows Installation

```powershell
# Full installation with WSL setup
./scripts/Install-DevTools.ps1 -WSLUsername "developer"

# Use existing WSL
./scripts/Install-DevTools.ps1 -SkipWSL

# Skip PowerShell 7 on Windows host
./scripts/Install-DevTools.ps1 -SkipWSL -SkipHostPowerShell
```

### Linux/macOS Installation

```powershell
# Standard installation
./scripts/Install-DevTools.ps1

# Or use the shell script directly
chmod +x ./scripts/install-dev-tools.sh
./scripts/install-dev-tools.sh
```

### Common Options

```powershell
# Preview what would be installed
./scripts/Install-DevTools.ps1 -WhatIf

# Force reinstallation
./scripts/Install-DevTools.ps1 -Force

# Provide WSL password (instead of interactive prompt)
$securePassword = ConvertTo-SecureString "password" -AsPlainText -Force
./scripts/Install-DevTools.ps1 -WSLUsername "developer" -WSLPassword $securePassword
```

## Dependencies

### Prerequisites

**Windows:**
- PowerShell 5.1 or higher (for initial execution)
- Administrator privileges (for WSL installation)
- Windows 10 version 2004+ or Windows 11

**Linux:**
- sudo privileges
- curl or wget
- Basic development tools (usually pre-installed)

**macOS:**
- Xcode Command Line Tools
- Homebrew (will be installed if missing)

### Runtime Dependencies

The scripts will install these if missing:
- curl, wget (Linux)
- apt-transport-https, software-properties-common (Ubuntu/Debian)
- Microsoft package repositories (for PowerShell)
- nvm (Node Version Manager)

## Integration with AitherZero

### Module Integration

When AitherZero modules are available, the script uses:
```powershell
# Logging module for standardized output
Import-Module ./aither-core/modules/Logging -Force
Write-CustomLog -Level 'INFO' -Message "Starting installation"

# DevEnvironment module for tool management
Import-Module ./aither-core/modules/DevEnvironment -Force
Install-ClaudeCodeDependencies
Install-GeminiCLIDependencies
```

### Fallback Behavior

When running standalone (without AitherZero modules):
- Defines local `Write-CustomLog` function
- Uses shell script for installations
- Provides basic colored output

### Error Handling

Follows AitherZero patterns:
```powershell
try {
    # Installation logic
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Failed: $($_.Exception.Message)"
    throw
}
```

## Post-Installation

After successful installation, the scripts provide:

1. **Verification Output**: Shows installed versions of all tools
2. **Configuration Steps**: Git setup, GitHub CLI auth, API keys
3. **Shell Integration**: Automatic nvm setup in .bashrc/.zshrc

### Required Manual Steps

1. Configure Git:
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```

2. Authenticate GitHub CLI:
   ```bash
   gh auth login
   ```

3. Set Claude Code API key:
   ```bash
   export ANTHROPIC_API_KEY='your-api-key-here'
   # Add to ~/.bashrc or ~/.zshrc to persist
   ```

## Notes

- WSL installation may require a system restart
- Node.js is installed via nvm for better version management
- Claude Code requires npm, which is why Node.js is installed first
- PowerShell 7 installation methods vary by Linux distribution
- The scripts follow AitherZero's comprehensive error handling patterns
- All logging integrates with the central AitherZero logging system when available

## Troubleshooting

### Common Issues

1. **WSL Installation Fails**
   - Ensure Windows version is 2004 or higher
   - Run PowerShell as Administrator
   - Check virtualization is enabled in BIOS

2. **Node.js/npm Not Found After Installation**
   - Source nvm: `. ~/.nvm/nvm.sh`
   - Check nvm installation: `ls ~/.nvm`
   - Verify shell profile was updated

3. **Permission Denied Errors**
   - Ensure sudo privileges
   - Check script has execute permissions
   - Verify target directories are writable

### Debug Mode

```powershell
# Run with verbose output
$VerbosePreference = 'Continue'
./scripts/Install-DevTools.ps1 -Verbose

# Check what would happen
./scripts/Install-DevTools.ps1 -WhatIf
```

## Related Documentation

- See `aither-core/modules/DevEnvironment/` for AI tools integration
- See `aither-core/modules/Logging/` for logging system details
- See `CLAUDE.md` for AI tools commands and usage