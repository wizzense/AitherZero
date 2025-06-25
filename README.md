# AitherZero Infrastructure Automation

**🚀 Standalone PowerShell automation framework** for OpenTofu/Terraform infrastructure management with comprehensive testing and modular architecture.

[![Build Status](https://github.com/wizzense/AitherZero/actions/workflows/build-release.yml/badge.svg)](https://github.com/wizzense/AitherZero/actions)
[![PowerShell](https://img.shields.io/badge/PowerShell-7.0+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![OpenTofu](https://img.shields.io/badge/OpenTofu-Compatible-orange.svg)](https://opentofu.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Contributors Welcome](https://img.shields.io/badge/Contributors-Welcome-brightgreen.svg)](CONTRIBUTING.md)

## ⚡ Quick Start - One-Click Setup (30 seconds)

### 🔥 Super Simple - Just 3 Steps:

#### 🖱️ **Windows (One-Click)**
1. **Download**: Go to **[Releases](https://github.com/wizzense/AitherZero/releases/latest)** → Download `AitherZero-*-windows.zip`
2. **Extract**: Right-click → Extract All
3. **Run**: Double-click `AitherZero.bat` ✨

#### �️ **Linux/macOS (One-Command)**
```bash
# One command downloads and runs AitherZero:
curl -s https://api.github.com/repos/wizzense/AitherZero/releases/latest | grep "browser_download_url.*$(uname -s | tr '[:upper:]' '[:lower:]').tar.gz" | head -1 | cut -d '"' -f 4 | xargs curl -L | tar -xz && cd AitherZero-* && ./aitherzero.sh
```

### 🚀 Alternative Downloads

#### Windows PowerShell One-Liner
```powershell
# Download and run in one command:
$url = (irm "https://api.github.com/repos/wizzense/AitherZero/releases/latest").assets | ? name -like "*windows.zip" | % browser_download_url; iwr $url -OutFile "AitherZero.zip"; Expand-Archive "AitherZero.zip" -Force; $folder = (gci -Directory | ? Name -like "AitherZero*")[0].Name; cd $folder; .\AitherZero.bat
```

#### Manual Download (If you prefer)
1. **Go to [GitHub Releases](https://github.com/wizzense/AitherZero/releases/latest)**
2. **Download your platform**:
   - **Windows**: `AitherZero-[version]-windows.zip` 
   - **Linux**: `AitherZero-[version]-linux.tar.gz`
   - **macOS**: `AitherZero-[version]-macos.tar.gz`
3. **Extract and run**:
   - **Windows**: `AitherZero.bat` or `Start-AitherZero-Windows.ps1`
   - **Linux/macOS**: `./aitherzero.sh` or `pwsh Start-AitherZero.ps1`

### � First-Time Setup Wizard
```bash
# Run setup wizard to check your environment:
./Start-AitherZero.ps1 -Setup
```

### 💡 Usage Examples
```bash
# Interactive menu (default)
./Start-AitherZero.ps1

# Run all automation scripts
./Start-AitherZero.ps1 -Auto

# Run specific modules
./Start-AitherZero.ps1 -Scripts "LabRunner,BackupManager"

# Get help and see all options
./Start-AitherZero.ps1 -Help
```

## 🎯 What You Get

**Ready-to-Run Application Package:**
- ✅ **One-click execution** on all platforms
- ✅ **Built-in setup wizard** (`-Setup`)
- ✅ **Interactive menu system** for guided usage
- ✅ **Automated execution mode** (`-Auto`)
- ✅ **No compilation or installation** required
- ✅ **Cross-platform launchers** included

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
