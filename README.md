# AitherZero Infrastructure Automation

**🚀 Standalone PowerShell automation framework** for OpenTofu/Terraform infrastructure management with comprehensive testing and modular architecture.

[![Build Status](https://github.com/wizzense/AitherZero/actions/workflows/build-release.yml/badge.svg)](https://github.com/wizzense/AitherZero/actions)
[![PowerShell](https://img.shields.io/badge/PowerShell-7.0+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![OpenTofu](https://img.shields.io/badge/OpenTofu-Compatible-orange.svg)](https://opentofu.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Contributors Welcome](https://img.shields.io/badge/Contributors-Welcome-brightgreen.svg)](CONTRIBUTING.md)

## ⚡ Quick Start - Download & Run (30 seconds)

### 🎯 Windows Users

```powershell
# Download latest Windows release and run:
$url = (irm "https://api.github.com/repos/wizzense/AitherZero/releases/latest").assets | ? name -like "*windows.zip" | % browser_download_url; iwr $url -OutFile "AitherZero.zip"; Expand-Archive "AitherZero.zip" -Force; $folder = (gci -Directory | ? Name -like "AitherZero*")[0].Name; cd $folder; .\AitherZero.bat
```

**Or step-by-step:**

```powershell
# Step 1: Download
gh release download --repo wizzense/AitherZero --pattern "*windows.zip"

# Step 2: Extract and run
Expand-Archive "AitherZero-*-windows.zip" -Force; cd AitherZero-*-windows; .\AitherZero.bat
```

### 🐧 Linux Users

```bash
# Download latest Linux release and run:
gh release download --repo wizzense/AitherZero --pattern "*linux.tar.gz"
tar -xzf AitherZero-*-linux.tar.gz
cd AitherZero-*-linux
./aitherzero.sh
```

**Or with curl:**

```bash
# Get latest release URL and download
curl -s https://api.github.com/repos/wizzense/AitherZero/releases/latest | grep "browser_download_url.*linux.tar.gz" | cut -d '"' -f 4 | xargs curl -L -o AitherZero-linux.tar.gz
tar -xzf AitherZero-linux.tar.gz
cd AitherZero-*-linux
pwsh Start-AitherZero.ps1
```

### 🍎 macOS Users

```bash
# Download latest macOS release and run:
gh release download --repo wizzense/AitherZero --pattern "*macos.tar.gz"
tar -xzf AitherZero-*-macos.tar.gz
cd AitherZero-*-macos
./aitherzero.sh
```

**Or with curl:**

```bash
# Get latest release URL and download
curl -s https://api.github.com/repos/wizzense/AitherZero/releases/latest | grep "browser_download_url.*macos.tar.gz" | cut -d '"' -f 4 | xargs curl -L -o AitherZero-macos.tar.gz
tar -xzf AitherZero-macos.tar.gz
cd AitherZero-*-macos
pwsh Start-AitherZero.ps1
```

### 📋 Manual Download

1. Go to **[GitHub Releases](https://github.com/wizzense/AitherZero/releases/latest)**
2. Download your platform package:
   - **Windows**: `AitherZero-[version]-windows.zip`
   - **Linux**: `AitherZero-[version]-linux.tar.gz`
   - **macOS**: `AitherZero-[version]-macos.tar.gz`
3. Extract and run:
   - **Windows**: Double-click `AitherZero.bat` or run `Start-AitherZero.ps1`
   - **Linux/macOS**: Run `./aitherzero.sh` or `pwsh Start-AitherZero.ps1`

## 📦 What You Get

**🎯 Lean Application Package Contents:**

- `Start-AitherZero.ps1` - **Main PowerShell launcher**
- `AitherZero.bat` / `aitherzero.sh` - **Platform-specific quick launchers**
- `aither-core.ps1` - **Core application script**
- `modules/` - **Essential PowerShell modules**
- `configs/` - **Configuration templates**
- `opentofu/` - **Infrastructure automation templates**
- `INSTALL.md` - **Installation and usage guide**

**💡 What's NOT included:** Development tools, tests, build scripts, or full repository content. This is a focused application package for running AitherZero, not developing it.

---

## 🔧 Development & Contributing

Want to contribute or modify AitherZero? You'll need the full repository:

```bash
# Clone the full development repository:
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero

# Run the core application:
pwsh -File ./aither-core/aither-core.ps1
```

**Development vs. Application:**

- **Application releases** (above): Lean packages for running AitherZero
- **Repository clone**: Full development environment with tests, build tools, and documentation

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

---

## 🚀 Features

AitherZero provides a comprehensive infrastructure automation framework:

### Core Capabilities

- **Cross-Platform**: Windows, Linux, macOS support with PowerShell 7.0+
- **Infrastructure as Code**: OpenTofu/Terraform integration for lab environments
- **Modular Architecture**: 14+ specialized PowerShell modules
- **Advanced Automation**: Lab setup, backup management, parallel execution
- **Enterprise Logging**: Centralized logging with multiple levels
- **Patch Management**: Git-controlled workflows with automated PR/issue creation
- **Testing Framework**: Bulletproof validation with Pester integration

### Essential Modules

- **LabRunner**: Lab automation orchestration and test execution
- **PatchManager**: Git workflow automation with intelligent PR creation
- **BackupManager**: File backup, cleanup, and consolidation
- **DevEnvironment**: Development environment preparation
- **OpenTofuProvider**: Infrastructure deployment and management
- **ParallelExecution**: Runspace-based parallel task execution
- **Logging**: Centralized logging across all operations

## 🔧 Requirements

- **PowerShell 7.0 or later**
- **Git** (for repository operations and PatchManager)
- **OpenTofu/Terraform** (for infrastructure automation)
- **Windows/Linux/macOS** (cross-platform compatible)

## 📖 Usage Examples

### Running AitherZero

```powershell
# Start the application (from downloaded package)
.\Start-AitherZero.ps1

# Run with specific options
.\aither-core.ps1 -Verbosity detailed -NonInteractive
.\aither-core.ps1 -Scripts "LabRunner,BackupManager" -Auto
.\aither-core.ps1 -WhatIf  # Preview mode
```

### Using Individual Modules

```powershell
# PatchManager - Create automated patches
Import-Module "./modules/PatchManager" -Force
Invoke-PatchWorkflow -PatchDescription "Fix configuration issue" -CreatePR

# LabRunner - Automate lab deployment
Import-Module "./modules/LabRunner" -Force
Start-LabEnvironment -ConfigPath "./configs/lab-config.json"

# BackupManager - Manage backups
Import-Module "./modules/BackupManager" -Force
Invoke-BackupCleanup -RetentionDays 30
```

## 🏗️ Architecture

```text
AitherZero Application Package/
├── Start-AitherZero.ps1          # Main launcher
├── aither-core.ps1               # Core application
├── modules/                      # PowerShell modules
│   ├── LabRunner/               # Lab automation
│   ├── PatchManager/            # Git workflows
│   ├── BackupManager/           # Backup operations
│   ├── Logging/                 # Centralized logging
│   └── [other modules]/
├── configs/                      # Configuration templates
├── opentofu/                     # Infrastructure templates
└── shared/                       # Shared utilities
```

## 📚 Documentation

- **[Installation Guide](INSTALL.md)** - Detailed setup instructions
- **[Contributing Guide](CONTRIBUTING.md)** - Development setup and guidelines
- **[API Documentation](docs/)** - Module and function reference
- **[Examples](docs/examples/)** - Common usage patterns and scripts

## 🔄 Support & Community

- **Issues**: [GitHub Issues](https://github.com/wizzense/AitherZero/issues)
- **Discussions**: [GitHub Discussions](https://github.com/wizzense/AitherZero/discussions)
- **License**: [MIT License](LICENSE)

## ⚠️ Important Notes

- **Application packages** are for running AitherZero, not developing it
- For development work, clone the full repository
- The application has built-in capabilities to clone repositories as needed
- All bootstrap scripts and manual setup methods have been deprecated in favor of clean application releases

---

**Made with ❤️ for infrastructure automation**
