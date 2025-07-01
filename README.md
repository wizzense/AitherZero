# AitherZero Infrastructure Automation

**🚀 Standalone PowerShell automation framework** for OpenTofu/Terraform infrastructure management with comprehensive testing, modular architecture, and AI-powered automation.

[![Build Status](https://github.com/wizzense/AitherZero/actions/workflows/build-release.yml/badge.svg)](https://github.com/wizzense/AitherZero/actions)
[![PowerShell](https://img.shields.io/badge/PowerShell-7.0+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![OpenTofu](https://img.shields.io/badge/OpenTofu-Compatible-orange.svg)](https://opentofu.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Contributors Welcome](https://img.shields.io/badge/Contributors-Welcome-brightgreen.svg)](CONTRIBUTING.md)

> **🚨 HOTFIX AVAILABLE (See Latest Release)**: If you're experiencing PowerShell compatibility errors with v0.10.0, use the **fixed launchers**:
> - **Windows**: Use AitherZero-Fixed.bat or Start-AitherZero-Fixed.ps1
> - **PowerShell 5.1 users**: These hotfix launchers work with your version!
> - **Quick Fix**: .\Start-AitherZero-Fixed.ps1 -Setup for first-time setup
>
> See [HOTFIX-README.md](HOTFIX-README.md) for detailed instructions.

## ⚡ Quick Start - One-Click Setup (30 seconds)

### 🎉 NEW: Interactive Quickstart Experience!

```powershell
# First-time users - try our new interactive quickstart:
./Start-AitherZero.ps1 -Quickstart
```

This launches:
- ✨ **Enhanced Interactive UI** with rich terminal experience
- 🎯 **Module Explorer** to discover all available features
- 📦 **Configuration Manager** with visual editing
- 🔐 **License Management** for feature tiers
- 💾 **Profile System** with GitHub sync

### 🔥 Traditional Quick Start - Just 3 Steps:

#### 🖱️ **Windows (One-Click)**
1. **Download**: Go to **[Releases](https://github.com/wizzense/AitherZero/releases/latest)** → Download `AitherZero-*-windows.zip`
2. **Extract**: Right-click → Extract All
3. **Run**: Double-click `AitherZero.bat` or use `.\Start-AitherZero.ps1 -Quickstart` ✨

#### 🐧 **Linux/macOS (One-Command)**
```bash
# One command downloads and runs AitherZero:
curl -s https://api.github.com/repos/wizzense/AitherZero/releases/latest | grep "browser_download_url.*$(uname -s | tr '[:upper:]' '[:lower:]').tar.gz" | head -1 | cut -d '"' -f 4 | xargs curl -L | tar -xz && cd AitherZero-* && ./Start-AitherZero.ps1 -Quickstart
```

### 🚀 Alternative Downloads

#### Windows PowerShell One-Liner
```powershell
# Download and run in one command:
$url = (irm "https://api.github.com/repos/wizzense/AitherZero/releases/latest").assets | ? name -like "*-windows-*.zip" | Select -First 1 | % browser_download_url; iwr $url -OutFile "AitherZero.zip"; Expand-Archive "AitherZero.zip" -Force; $folder = (gci -Directory | ? Name -like "AitherZero*")[0].Name; cd $folder; .\AitherZero.bat
```

#### Quick Environment Validation
```powershell
# Run quickstart validation to check your environment:
./tests/Run-BulletproofValidation.ps1 -ValidationLevel Quickstart -QuickstartSimulation
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

### 🛠 Enhanced First-Time Setup Wizard
```bash
# Interactive setup with profile selection:
./Start-AitherZero.ps1 -Setup

# Installation profiles for different needs:
./Start-AitherZero.ps1 -Setup -InstallationProfile minimal     # Core features only
./Start-AitherZero.ps1 -Setup -InstallationProfile developer   # + AI tools
./Start-AitherZero.ps1 -Setup -InstallationProfile full        # + Cloud CLIs & enterprise

# Legacy options still supported:
./Start-AitherZero.ps1 -Setup -SkipOptional

# Validate environment without setup:
./tests/Run-BulletproofValidation.ps1 -ValidationLevel Quickstart
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
- ✅ **Intelligent setup wizard** with progress tracking (`-Setup`)
- ✅ **Interactive menu system** for guided usage
- ✅ **Automated execution mode** (`-Auto`)
- ✅ **Quickstart validation** for new user environments
- ✅ **Visual progress indicators** for long-running operations
- ✅ **Platform-specific guidance** and recommendations
- ✅ **No compilation or installation** required
- ✅ **Cross-platform launchers** included
- ✅ **AI-powered automation** support

---

## 🔧 Development & Contributing

**📋 You have the DEVELOPMENT repository** (not an application package). Use these commands:

### 🚀 Running from Development Repository

```powershell
# Windows - Run the core application directly:
pwsh -File .\aither-core\aither-core.ps1

# Linux/macOS - Run the core application:
pwsh -File ./aither-core/aither-core.ps1

# With options:
pwsh -File .\aither-core\aither-core.ps1 -Verbosity detailed
pwsh -File .\aither-core\aither-core.ps1 -Auto
pwsh -File .\aither-core\aither-core.ps1 -Help
```

### 🧪 Development Testing

```powershell
# Run tests:
pwsh -File .\tests\Run-BulletproofValidation.ps1 -ValidationLevel Quick

# Test all modules:
Get-ChildItem .\aither-core\modules -Directory | ForEach-Object { Import-Module $_.FullName -Force }
```

### 📦 Create Application Package

```powershell
# Build local packages (like the releases):
pwsh -File .\build\Build-Package.ps1
```

**Development vs. Application:**

- **🏗️ Development repository** (what you have): Full source code, tests, build tools
- **📦 Application releases**: Lean packages for end users (no development tools)

The README instructions above are for **application packages only**. Since you have the development repository, use the commands in this section.

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed development setup and guidelines.

---

## 🎯 Enhanced User Experience (New!)

AitherZero now provides an enhanced user experience with intelligent setup and validation:

### 🧠 Intelligent Setup Wizard
- **Installation Profiles**: Choose from Minimal, Developer, Full, or Interactive profiles
- **Platform Detection**: Automatically detects your OS, PowerShell version, and architecture
- **AI Tools Integration**: Automatic Claude Code setup (Developer/Full profiles)
- **Dependency Checking**: Validates Git, OpenTofu/Terraform, Node.js, and cloud tools
- **Configuration Generation**: Creates platform-specific configuration files
- **Progress Tracking**: Visual progress bars with time estimates and completion status
- **Smart Recommendations**: Provides actionable suggestions for missing dependencies

### 📊 Quickstart Validation System
- **New User Validation**: Special validation level for first-time users
- **Environment Assessment**: Comprehensive check of platform requirements
- **Guided Setup Process**: Step-by-step guidance for optimal configuration
- **Cross-Platform Testing**: Validates functionality across Windows, Linux, and macOS
- **Performance Benchmarking**: Optional performance testing during setup

### 🎮 Interactive Progress Tracking
- **Visual Progress Bars**: Real-time progress indicators for long operations
- **Multiple Display Styles**: Bar, spinner, percentage, and detailed views
- **Time Tracking**: Elapsed time and estimated completion time
- **Multi-Operation Support**: Track multiple parallel operations simultaneously
- **Error and Warning Tracking**: Comprehensive logging with visual feedback

### 💡 Usage Examples
```powershell
# Interactive setup with profile selection
./Start-AitherZero.ps1 -Setup

# Minimal setup for production environments
./Start-AitherZero.ps1 -Setup -InstallationProfile minimal

# Developer setup with AI tools integration
./Start-AitherZero.ps1 -Setup -InstallationProfile developer

# Full setup with all features
./Start-AitherZero.ps1 -Setup -InstallationProfile full

# Quick validation for existing users
./tests/Run-BulletproofValidation.ps1 -ValidationLevel Quickstart

# Custom setup with progress tracking
Import-Module ./aither-core/modules/SetupWizard
$result = Start-IntelligentSetup -InstallationProfile developer
```

---

## 🚀 Features

AitherZero provides a comprehensive infrastructure automation framework:

### Core Capabilities

- **Cross-Platform**: Windows, Linux, macOS support with PowerShell 7.0+
- **Infrastructure as Code**: OpenTofu/Terraform integration for lab environments
- **Modular Architecture**: 14+ specialized PowerShell modules
- **AI-Powered Automation**: Support for intelligent infrastructure management
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
- **SetupWizard**: Intelligent first-time setup with platform detection
- **ProgressTracking**: Visual progress indicators and operation tracking
- **ISOManager/ISOCustomizer**: ISO management and customization
- **RemoteConnection**: Multi-protocol remote connections
- **SecureCredentials**: Enterprise credential management
- **TestingFramework**: Pester-based testing integration
- **SecurityAutomation**: Automated security hardening and compliance
- **SystemMonitoring**: System performance monitoring and alerting
- **RestAPIServer**: REST API server for external integrations

## 🔧 Requirements

- **PowerShell 7.0 or later**
- **Git** (for repository operations and PatchManager)
- **OpenTofu/Terraform** (for infrastructure automation)
- **Windows/Linux/macOS** (cross-platform compatible)
- **Node.js 18+** (optional, for AI tools)
- **Claude Code** (optional, for AI-powered automation)

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

- **[Installation Guide](docs/INSTALLATION.md)** - Detailed setup instructions
- **[Quick Start Guide](QUICK-START-GUIDE.md)** - Get started in minutes with intelligent setup
- **[Setup Wizard Guide](docs/SETUP-WIZARD-GUIDE.md)** - Comprehensive setup wizard documentation
- **[Progress Tracking Guide](docs/PROGRESS-TRACKING-GUIDE.md)** - Visual progress indicators guide
- **[Quickstart Validation Guide](docs/QUICKSTART-VALIDATION-GUIDE.md)** - New user validation system
- **[Contributing Guide](CONTRIBUTING.md)** - Development setup and guidelines
- **[Module Reference](docs/MODULE-REFERENCE.md)** - Complete module documentation
- **[Testing Guide](docs/BULLETPROOF-TESTING-GUIDE.md)** - Comprehensive testing documentation
- **[PatchManager Guide](docs/PATCHMANAGER-COMPLETE-GUIDE.md)** - Git workflow automation
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
