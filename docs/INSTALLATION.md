# AitherZero Installation Guide

## Table of Contents

- [Overview](#overview)
- [System Requirements](#system-requirements)
- [Installation Methods](#installation-methods)
  - [Quick Start (Recommended)](#quick-start-recommended)
  - [Developer Installation](#developer-installation)
  - [Claude Code MCP Setup](#claude-code-mcp-setup)
- [Platform-Specific Instructions](#platform-specific-instructions)
  - [Windows](#windows)
  - [Linux](#linux)
  - [macOS](#macos)
- [Post-Installation](#post-installation)
- [Troubleshooting](#troubleshooting)

## Overview

AitherZero can be installed in two ways:
1. **Application Package** - Pre-built releases for end users (recommended)
2. **Development Repository** - Full source code for contributors

## System Requirements

### Minimum Requirements

- **Operating System**: Windows 10+, Ubuntu 20.04+, macOS 11+
- **PowerShell**: Version 7.0 or later
- **Memory**: 4GB RAM minimum, 8GB recommended
- **Storage**: 2GB free space
- **Network**: Internet connection for package downloads

### Optional Requirements

- **Git**: For PatchManager and repository operations
- **OpenTofu/Terraform**: For infrastructure automation
- **Node.js 18+**: For Claude Code MCP integration
- **Claude Code**: For AI-powered automation

## Installation Methods

### Quick Start (Recommended)

#### Option 1: One-Click Download

1. Visit [Latest Release](https://github.com/wizzense/AitherZero/releases/latest)
2. Download the appropriate package:
   - Windows: `AitherZero-[version]-windows.zip`
   - Linux: `AitherZero-[version]-linux.tar.gz`
   - macOS: `AitherZero-[version]-macos.tar.gz`
3. Extract and run the launcher

#### Option 2: Command Line Installation

**Windows PowerShell:**
```powershell
# Download, extract, and run
$url = (irm "https://api.github.com/repos/wizzense/AitherZero/releases/latest").assets | 
    ? name -like "*-windows-*.zip" | % browser_download_url
iwr $url -OutFile "AitherZero.zip"
Expand-Archive "AitherZero.zip" -Force
cd AitherZero-*
.\AitherZero.bat
```

**Linux/macOS:**
```bash
# Download, extract, and run
curl -s https://api.github.com/repos/wizzense/AitherZero/releases/latest | 
    grep "browser_download_url.*$(uname -s | tr '[:upper:]' '[:lower:]').tar.gz" | 
    head -1 | cut -d '"' -f 4 | xargs curl -L | tar -xz
cd AitherZero-*
./aitherzero.sh
```

### Developer Installation

For contributing or development work:

```bash
# Clone the repository
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero

# Install PowerShell 7 if needed (see platform instructions)

# Run from source
pwsh -File ./aither-core/aither-core.ps1

# Run tests
pwsh -File ./tests/Run-BulletproofValidation.ps1 -ValidationLevel Quick
```

### Claude Code MCP Setup

Enable AI-powered automation:

```bash
# Navigate to MCP server directory
cd mcp-server

# Install dependencies
npm install

# Add MCP server to Claude Code
claude mcp add aitherzero -- node claude-code-mcp-server.js

# Or use the setup script
./setup-claude-code-mcp.sh
```

## Platform-Specific Instructions

### Windows

#### Installing PowerShell 7

**Option 1: Windows Package Manager (winget)**
```powershell
winget install Microsoft.PowerShell
```

**Option 2: MSI Installer**
1. Download from [PowerShell Releases](https://github.com/PowerShell/PowerShell/releases)
2. Run the MSI installer
3. Follow installation prompts

#### Running AitherZero

```powershell
# From application package
.\AitherZero.bat
# or
.\Start-AitherZero.ps1

# From development repository
pwsh -File .\aither-core\aither-core.ps1
```

### Linux

#### Installing PowerShell 7

**Ubuntu/Debian:**
```bash
# Update package list
sudo apt-get update

# Install PowerShell
sudo apt-get install -y wget apt-transport-https software-properties-common
wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install -y powershell
```

**RHEL/CentOS:**
```bash
# Register Microsoft repository
curl https://packages.microsoft.com/config/rhel/7/prod.repo | sudo tee /etc/yum.repos.d/microsoft.repo

# Install PowerShell
sudo yum install -y powershell
```

#### Running AitherZero

```bash
# From application package
./aitherzero.sh
# or
pwsh Start-AitherZero.ps1

# From development repository
pwsh -File ./aither-core/aither-core.ps1
```

### macOS

#### Installing PowerShell 7

**Using Homebrew:**
```bash
# Install Homebrew if not present
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install PowerShell
brew install --cask powershell
```

**Direct Download:**
1. Download the `.pkg` file from [PowerShell Releases](https://github.com/PowerShell/PowerShell/releases)
2. Double-click to install
3. Follow installation prompts

#### Running AitherZero

```bash
# From application package
./aitherzero.sh
# or
pwsh Start-AitherZero.ps1

# From development repository
pwsh -File ./aither-core/aither-core.ps1
```

## Post-Installation

### First-Time Setup

Run the setup wizard to verify your environment:

```powershell
# Application package
./Start-AitherZero.ps1 -Setup

# Development repository
pwsh -File ./aither-core/aither-core.ps1 -Setup
```

### Configuration

1. **Review default settings**: `configs/default-config.json`
2. **Create custom config**: Copy to `configs/custom-config.json`
3. **Set environment variables** (optional):
   ```powershell
   $env:AITHERZERO_CONFIG = "custom"
   $env:AITHERZERO_LOG_LEVEL = "Debug"
   ```

### Verify Installation

```powershell
# Check PowerShell version
$PSVersionTable.PSVersion

# Test AitherZero modules
./Start-AitherZero.ps1 -Help

# Run quick validation
./tests/Run-BulletproofValidation.ps1 -ValidationLevel Quick
```

## Troubleshooting

### Common Issues

#### PowerShell Version Error
**Problem**: "PowerShell 7.0 or later required"
**Solution**: Install PowerShell 7 following platform instructions above

#### Module Import Failures
**Problem**: "Module not found" errors
**Solution**: 
```powershell
# Ensure you're in the correct directory
Get-Location

# Check module path
$env:PSModulePath -split ';'

# Force module import
Import-Module ./aither-core/modules/ModuleName -Force
```

#### Permission Denied (Linux/macOS)
**Problem**: "Permission denied" when running scripts
**Solution**:
```bash
# Make scripts executable
chmod +x Start-AitherZero.ps1
chmod +x aitherzero.sh
```

#### Git Not Found
**Problem**: PatchManager features unavailable
**Solution**: Install Git from [git-scm.com](https://git-scm.com/)

### Getting Help

1. **Check documentation**: Review guides in `/docs`
2. **Run diagnostics**: `./Start-AitherZero.ps1 -Diagnose`
3. **Enable debug logging**: `$env:AITHERZERO_LOG_LEVEL = "Debug"`
4. **Community support**: [GitHub Issues](https://github.com/wizzense/AitherZero/issues)

### Clean Reinstall

If experiencing persistent issues:

```powershell
# Remove existing installation
Remove-Item -Path "./AitherZero-*" -Recurse -Force

# Clear PowerShell module cache
Remove-Module * -Force
Get-Module -ListAvailable | Where Name -like "Aither*" | Remove-Module -Force

# Reinstall fresh
# Follow installation steps above
```

## Next Steps

- Review the [Quick Start Guide](../QUICK-START-GUIDE.md)
- Explore [Module Documentation](MODULE-REFERENCE.md)
- Set up [Claude Code MCP Integration](CLAUDE-CODE-MCP-INTEGRATION.md)
- Read [Contributing Guidelines](../CONTRIBUTING.md) for development

---

For additional help, visit our [GitHub repository](https://github.com/wizzense/AitherZero) or open an issue.