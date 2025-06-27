# Claude Code Dependencies Installation Guide

## Overview

AitherZero now includes comprehensive support for setting up all dependencies required to download and run Claude Code on both Windows and Linux platforms. This capability is integrated into the `DevEnvironment` module and provides automated installation with proper error handling and progress feedback.

## What Gets Installed

### Windows Platform
1. **WSL2 (Windows Subsystem for Linux)**
   - Enables WSL feature in Windows
   - Installs Ubuntu distribution
   - Configures WSL2 as default version
   - Sets up user account in Ubuntu

2. **Node.js via nvm (in WSL)**
   - Downloads and installs nvm (Node Version Manager)
   - Installs latest LTS Node.js version (or specified version)
   - Configures nvm environment variables
   - Sets up default Node.js alias

3. **Claude Code Package**
   - Installs `@anthropic-ai/claude-code` globally via npm
   - Upgrades npm to latest version
   - Configures claude-code command availability

### Linux Platform
1. **Node.js via nvm**
   - Downloads and installs nvm (Node Version Manager)
   - Installs latest LTS Node.js version (or specified version)
   - Configures nvm environment variables
   - Sets up default Node.js alias

2. **Claude Code Package**
   - Installs `@anthropic-ai/claude-code` globally via npm
   - Upgrades npm to latest version
   - Configures claude-code command availability

## Usage

### PowerShell Command Line

```powershell
# Import the DevEnvironment module
Import-Module './aither-core/modules/DevEnvironment' -Force

# Install with default settings (automatic platform detection)
Install-ClaudeCodeDependencies

# Windows: Install with custom WSL username
Install-ClaudeCodeDependencies -WSLUsername "myusername"

# Windows: Skip WSL installation (assumes WSL already configured)
Install-ClaudeCodeDependencies -SkipWSL

# Install specific Node.js version
Install-ClaudeCodeDependencies -NodeVersion "18.20.0"

# Force reinstallation even if components exist
Install-ClaudeCodeDependencies -Force

# Preview installation without actually installing (recommended first run)
Install-ClaudeCodeDependencies -WhatIf
```

### VS Code Tasks

Access these through `Ctrl+Shift+P → Tasks: Run Task`:

1. **🤖 DevEnvironment: Install Claude Code Dependencies**
   - Automatic platform detection and installation
   - Default settings for quick setup

2. **🪟 DevEnvironment: Install Claude Code (Windows + WSL)**
   - Windows-specific installation with WSL setup
   - Prompts for WSL username

3. **🐧 DevEnvironment: Install Claude Code (Linux)**
   - Linux-specific installation
   - Uses nvm for Node.js management

4. **🔍 DevEnvironment: Preview Claude Code Installation (WhatIf)**
   - Shows what would be installed without actually installing
   - Perfect for testing and verification

5. **🧪 DevEnvironment: Test Claude Code Dependencies Function**
   - Runs comprehensive tests for the installation function
   - Validates functionality and error handling

## Prerequisites

### Windows Requirements
- **Windows 10 version 2004+ or Windows 11**
- **Administrator privileges** (required for WSL installation)
- **Internet connection** for downloads
- **PowerShell 7.0+**

### Linux Requirements
- **curl or wget** (for downloading nvm)
- **bash shell**
- **Internet connection** for downloads
- **PowerShell 7.0+**

## Step-by-Step Installation Process

### Windows Installation Flow
1. **Administrator Check**: Verifies admin privileges for WSL installation
2. **WSL Installation**: 
   - Enables WSL and Virtual Machine Platform features
   - Sets WSL2 as default version
   - Installs Ubuntu distribution
3. **User Setup**: Configures Ubuntu user account (interactive or scripted)
4. **Node.js Installation**: Installs nvm and Node.js inside WSL Ubuntu
5. **Claude Code Installation**: Installs the claude-code npm package globally
6. **Verification**: Tests that claude-code command is available

### Linux Installation Flow
1. **Platform Detection**: Confirms Linux platform
2. **nvm Installation**: Downloads and installs Node Version Manager
3. **Node.js Installation**: Installs specified Node.js version via nvm
4. **Environment Setup**: Configures nvm environment variables
5. **Claude Code Installation**: Installs the claude-code npm package globally
6. **Verification**: Tests that claude-code command is available

## Advanced Configuration

### Custom Node.js Versions
```powershell
# Install specific Node.js version
Install-ClaudeCodeDependencies -NodeVersion "16.20.0"
Install-ClaudeCodeDependencies -NodeVersion "18.18.0"
Install-ClaudeCodeDependencies -NodeVersion "20.10.0"

# Install latest LTS (default)
Install-ClaudeCodeDependencies -NodeVersion "lts"
```

### Windows WSL Configuration
```powershell
# Provide WSL credentials upfront
$securePassword = ConvertTo-SecureString "mypassword" -AsPlainText -Force
Install-ClaudeCodeDependencies -WSLUsername "developer" -WSLPassword $securePassword

# Skip WSL installation if already configured
Install-ClaudeCodeDependencies -SkipWSL
```

### Force Reinstallation
```powershell
# Force reinstall all components
Install-ClaudeCodeDependencies -Force

# Useful for:
# - Updating to newer versions
# - Fixing corrupted installations
# - Changing Node.js versions
```

## Troubleshooting

### Common Issues

#### Windows: "Administrator privileges required"
- **Solution**: Run PowerShell as Administrator
- **Alternative**: Use `-SkipWSL` if WSL is already installed

#### Linux: "curl command not found"
- **Solution**: Install curl: `sudo apt update && sudo apt install curl`
- **Alternative**: The script will also work with wget

#### "Node.js installation failed"
- **Solution**: Check internet connectivity
- **Solution**: Try with `-Force` to reinstall nvm
- **Solution**: Check if firewall is blocking downloads

#### "WSL installation requires restart"
- **Solution**: Restart Windows after WSL installation
- **Solution**: Run the command again after restart

#### "claude-code command not found"
- **Solution**: Restart terminal/PowerShell session
- **Solution**: Source the nvm environment: `source ~/.bashrc`
- **Windows WSL**: Log out and back into WSL

### Verification Commands

After installation, verify everything works:

```bash
# Check Node.js version
node --version

# Check npm version  
npm --version

# Check Claude Code installation
claude-code --version

# Test Claude Code (if configured with API key)
claude-code --help
```

### Manual Cleanup (if needed)

#### Windows WSL Reset
```powershell
# Remove WSL distribution
wsl --unregister Ubuntu

# Disable WSL features
Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
Disable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
```

#### Linux nvm Removal
```bash
# Remove nvm directory
rm -rf ~/.nvm

# Remove nvm lines from ~/.bashrc
# Edit ~/.bashrc and remove nvm-related lines
```

## Security Considerations

### Password Handling
- WSL passwords are handled securely using `SecureString`
- Passwords are not logged or displayed in output
- Temporary password conversion is minimized and secured

### Download Security
- All downloads use HTTPS connections
- nvm installation uses official GitHub repository
- npm packages installed from official npm registry

### Privilege Requirements
- Windows: Administrator privileges only required for WSL installation
- Linux: No elevated privileges required (installs to user directory)

## Integration with AitherZero

### Module Structure
```
aither-core/modules/DevEnvironment/
├── Public/
│   ├── Install-ClaudeCodeDependencies.ps1  # Main function
│   └── [other functions...]
├── DevEnvironment.psd1                     # Updated manifest
└── DevEnvironment.psm1                     # Module loader
```

### Testing Framework
```
tests/unit/modules/DevEnvironment/
└── Install-ClaudeCodeDependencies.Tests.ps1  # Comprehensive tests
```

### VS Code Integration
- Tasks defined in `.vscode/tasks.json`
- Input prompts for interactive setup
- Proper error handling and user feedback

## Examples

### Quick Setup for Developers
```powershell
# Preview what will be installed
Install-ClaudeCodeDependencies -WhatIf

# Install with default settings
Install-ClaudeCodeDependencies

# Verify installation
claude-code --version
```

### Windows Developer Workstation
```powershell
# Complete Windows setup with custom username
Install-ClaudeCodeDependencies -WSLUsername "developer"

# After installation, test in WSL
wsl
claude-code --version
```

### Linux Server Setup
```powershell
# Install on Linux server
Install-ClaudeCodeDependencies

# Verify Node.js and Claude Code
node --version
npm --version
claude-code --version
```

### CI/CD Pipeline Setup
```powershell
# Automated installation for CI/CD
Install-ClaudeCodeDependencies -Force

# Use in GitHub Actions, Azure DevOps, etc.
```

## API Reference

### Install-ClaudeCodeDependencies

**Synopsis**: Sets up all dependencies required to run Claude Code on Windows and Linux.

**Syntax**:
```powershell
Install-ClaudeCodeDependencies
    [-SkipWSL]
    [-WSLUsername <String>]
    [-WSLPassword <SecureString>]
    [-NodeVersion <String>]
    [-Force]
    [-WhatIf]
    [<CommonParameters>]
```

**Parameters**:
- **SkipWSL**: (Windows only) Skip WSL installation, assumes WSL already configured
- **WSLUsername**: Username for WSL Ubuntu setup
- **WSLPassword**: Secure password for WSL user
- **NodeVersion**: Node.js version to install (default: 'lts')
- **Force**: Force reinstallation of components
- **WhatIf**: Preview installation without executing

**Returns**: None (writes progress to console via Write-CustomLog)

**Throws**: 
- Administrator privileges required (Windows WSL installation)
- Unsupported platform
- Network connectivity issues
- Installation failures

## Contributing

### Adding New Platforms
To add support for additional platforms (e.g., macOS):

1. Update platform detection logic
2. Add platform-specific installation functions
3. Update tests for new platform
4. Add VS Code tasks for new platform
5. Update documentation

### Extending Functionality
Consider these enhancement opportunities:

1. **Version Management**: Allow switching between Node.js versions
2. **Configuration Templates**: Pre-configured Claude Code setups
3. **Update Mechanism**: Check for and install updates
4. **Uninstall Support**: Clean removal of all components
5. **Alternative Package Managers**: Support for Homebrew, Chocolatey, etc.

## Support

For issues or questions:

1. **Check this documentation** for common solutions
2. **Run tests**: Use the test VS Code task to validate functionality
3. **Check logs**: Review console output for error details
4. **Use WhatIf**: Preview installation to identify potential issues
5. **Report issues**: Submit GitHub issues with full error details and system information
