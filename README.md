# AitherZero Infrastructure Automation

**🚀 Standalone PowerShell automation framework** for OpenTofu/Terraform infrastructure management with comprehensive testing, modular architecture, and AI-powered automation.

[![Build Status](https://github.com/wizzense/AitherZero/actions/workflows/ci.yml/badge.svg)](https://github.com/wizzense/AitherZero/actions)
[![Comprehensive Report](https://github.com/wizzense/AitherZero/actions/workflows/comprehensive-report.yml/badge.svg)](https://github.com/wizzense/AitherZero/actions/workflows/comprehensive-report.yml)
[![PowerShell](https://img.shields.io/badge/PowerShell-7.0+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![OpenTofu](https://img.shields.io/badge/OpenTofu-Compatible-orange.svg)](https://opentofu.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Contributors Welcome](https://img.shields.io/badge/Contributors-Welcome-brightgreen.svg)](CONTRIBUTING.md)

## 📊 [View Live Dashboard & Reports](https://wizzense.github.io/AitherZero/)

**Automated reports updated daily:** https://wizzense.github.io/AitherZero/

### 📈 Available Reports:
- **[Comprehensive Project Report](https://wizzense.github.io/AitherZero/aitherZero-comprehensive-report.html)** - Full project health analysis with test coverage, documentation audit, and code quality metrics
- **[Feature & Dependency Map](https://wizzense.github.io/AitherZero/feature-dependency-map.html)** - Interactive visualization of module relationships
- **[CI Dashboard](https://wizzense.github.io/AitherZero/comprehensive-ci-dashboard.html)** - Latest CI/CD results and trends
- **[Executive Summary](https://wizzense.github.io/AitherZero/executive-summary.md)** - High-level project status for stakeholders

## ⚡ Ultra-Simple Installation (30 seconds)

> 🎯 **Get AitherZero running with a single command** - compatible with PowerShell 5.1+ on Windows/Linux/macOS

```powershell
# Windows - One command downloads and runs AitherZero:
iex (irm "https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1")

# Linux/macOS - One command downloads and runs AitherZero:
curl -sSL https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.sh | bash
```

### 📦 **Profile Selection During Install**
The bootstrap will prompt you to choose your profile:

- **Minimal** (5-8 MB): Core infrastructure deployment only
- **Standard** (15-25 MB): Production-ready automation (recommended)  
- **Development** (35-50 MB): Complete contributor environment

### 🤖 **Automated Installation**
For CI/CD or automated deployment:

```powershell
# Windows - Automated with specific profile
$env:AITHER_PROFILE='minimal'; iex (irm "https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1")

# Linux/macOS - Automated with specific profile  
AITHER_PROFILE=standard curl -sSL https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.sh | bash
```

### 📖 **What This Command Does**
1. ✅ **Profile Selection** - Choose minimal, standard, or development
2. ✅ **Downloads** the appropriate AitherZero package from GitHub
3. ✅ **Extracts** it to your directory (or custom path)
4. ✅ **Auto-starts** the setup process  
5. ✅ **Cross-platform** - works on Windows, Linux, and macOS
6. ✅ **PowerShell Requirements** - 7.0+ for core features, 5.1+ for bootstrap only

> 💡 **That's it!** No complex setup, no manual downloads, intelligent profile selection.

## 🎯 Quick Start After Installation

### Windows Users
```cmd
# Option 1: Use the Windows launcher (works from cmd or PowerShell)
Start-AitherZero.cmd

# Option 2: Use PowerShell directly (auto-detects PS7)
.\Start-AitherZero.ps1

# Option 3: Run setup again if needed
.\Start-AitherZero.ps1 -Setup
```

### Linux/macOS Users
```bash
# Start AitherZero
./Start-AitherZero.ps1

# Or if PowerShell 7 is not in PATH
pwsh ./Start-AitherZero.ps1
```

### 🚀 First Time? Run Setup!
```powershell
# Interactive setup wizard
./Start-AitherZero.ps1 -Setup

# Setup with specific profile
./Start-AitherZero.ps1 -Setup -InstallationProfile developer
```

### Common Launch Options
```powershell
# Interactive mode (default) - shows menu
./Start-AitherZero.ps1

# Run specific modules
./Start-AitherZero.ps1 -Scripts "LabRunner"
./Start-AitherZero.ps1 -Scripts "BackupManager,OpenTofuProvider"

# Automated mode
./Start-AitherZero.ps1 -Auto

# Get help
./Start-AitherZero.ps1 -Help
```

## 📚 Documentation Index

### 🚀 **Getting Started**
- **[Quick Start Guide](QUICKSTART.md)** - Fast setup and basic usage
- **[Setup Wizard Guide](aither-core/modules/SetupWizard/README.md)** - Interactive setup walkthrough
- **[Installation Profiles](configs/carousel/README.md)** - Profile selection and configuration

### 📖 **Module Documentation**  
- **[Module Architecture](aither-core/modules/README.md)** - 28+ specialized modules overview
- **[Configuration Management](aither-core/modules/ConfigurationCarousel/README.md)** - Multi-environment config system
- **[Infrastructure Deployment](aither-core/modules/OpenTofuProvider/README.md)** - OpenTofu/Terraform automation
- **[Git Workflow Automation](aither-core/modules/PatchManager/README.md)** - Automated patch and release management
- **[System Monitoring](aither-core/modules/SystemMonitoring/README.md)** - Real-time system monitoring and alerting
- **[Security Automation](aither-core/modules/SecurityAutomation/README.md)** - Enterprise security hardening

### 🛠️ **Development & Contributing**
- **[Contributing Guide](CONTRIBUTING.md)** - How to contribute to AitherZero
- **[GitHub Automation](.github/README.md)** - CI/CD workflows and release process  
- **[Testing Framework](aither-core/modules/TestingFramework/README.md)** - Testing patterns and validation
- **[Development Environment](aither-core/modules/DevEnvironment/README.md)** - Development setup and tools

### 🧪 **Testing & Validation**
- **[Test Runner Guide](tests/README.md)** - Running tests and validation
- **[Performance Testing](docs/testing/)** - Performance benchmarks and optimization
- **[Quality Assurance](scripts/auditing/README.md)** - Code quality and duplicate detection

### 🏗️ **Infrastructure & Deployment**
- **[OpenTofu Templates](opentofu/README.md)** - Infrastructure as Code templates
- **[Configuration Templates](configs/README.md)** - Environment and profile configurations
- **[Build System](build/README.md)** - Package building and distribution

### 🔬 **Advanced Topics**
- **[Module Communication](aither-core/modules/ModuleCommunication/README.md)** - Inter-module messaging and APIs
- **[Parallel Execution](aither-core/modules/ParallelExecution/README.md)** - High-performance parallel processing
- **[License Management](aither-core/modules/LicenseManager/README.md)** - License compliance and management
- **[API Integration](aither-core/modules/RestAPIServer/README.md)** - REST API server and webhooks

---

## 📦 Manual Installation (If Preferred)

**Alternative if you prefer manual control:**

1. **Download**: Go to **[Releases](https://github.com/wizzense/AitherZero/releases/latest)** → Choose your profile and platform
2. **Extract**: Right-click → Extract All (or `tar -xzf` on Unix)
3. **Run**: Double-click `AitherZero.bat` (Windows) or run `./aitherzero.sh` (Unix)

**Available Package Matrix:**
| Profile | Windows | Linux | macOS |
|---------|---------|-------|-------|
| **Minimal** (5-8 MB) | `AitherZero-[version]-minimal-windows.zip` | `AitherZero-[version]-minimal-linux.tar.gz` | `AitherZero-[version]-minimal-macos.tar.gz` |
| **Standard** (15-25 MB) | `AitherZero-[version]-standard-windows.zip` | `AitherZero-[version]-standard-linux.tar.gz` | `AitherZero-[version]-standard-macos.tar.gz` |
| **Development** (35-50 MB) | `AitherZero-[version]-development-windows.zip` | `AitherZero-[version]-development-linux.tar.gz` | `AitherZero-[version]-development-macos.tar.gz` |

> 💡 **Recommendation**: Start with **Standard** profile for most use cases

## 🎯 After Installation - Modern CLI Interface

**Once installed, AitherZero provides a clean, modern CLI:**

```bash
# 🚀 Essential Commands
aither help                                    # Show all commands
aither init                                    # Interactive setup
aither dev patch "Bug fix"             # Development workflow  
aither deploy plan ./infrastructure            # Infrastructure planning
```

**Windows users** can use the convenient batch wrapper:
```cmd
aither help
aither init  
aither dev patch "Bug fix"
```

### 🛠 Setup Options
```bash
# Interactive setup (recommended)
./aither.ps1 init

# Or traditional setup with profiles:
./Start-AitherZero.ps1 -Setup -InstallationProfile minimal     # Core only
./Start-AitherZero.ps1 -Setup -InstallationProfile developer   # + AI tools
./Start-AitherZero.ps1 -Setup -InstallationProfile full        # + Enterprise
```

## 🎯 What You Get

**Complete Infrastructure Automation Framework:**
- ✨ **Ultra-Simple Installation** - One command gets you running
- 🚀 **Modern CLI Interface** with clean command structure (`aither [command]`)
- 🧠 **Intelligent Setup Wizard** with progress tracking
- 🔧 **23 Consolidated Modules** for infrastructure automation (reduced from 30+)
- ⚡ **Cross-Platform Support** - Windows, Linux, macOS
- 🔄 **Developer Workflow Automation** - Git, releases, testing
- 🎯 **No Installation Required** - Portable application packages
- 🤖 **AI-Powered Automation** support for intelligent operations

---

## 🔧 Development & Contributing

> 📝 **Note**: Instructions above are for end users. If you're developing AitherZero, use these commands:

```powershell
# Run from development repository:
pwsh -File ./aither-core/aither-core.ps1

# Run tests:
./tests/Run-Tests.ps1 -Quick

# Build packages:
./build/Build-Package.ps1
```

**See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed development setup.**

---


## 🚀 Key Features

**Infrastructure Automation Framework:**
- 🔄 **Cross-Platform**: Windows, Linux, macOS with PowerShell 5.1+
- 🏗️ **Infrastructure as Code**: OpenTofu/Terraform integration
- 🧩 **Modular Architecture**: 23 consolidated PowerShell modules with clear boundaries
- 🤖 **AI-Powered Automation**: Intelligent infrastructure management
- 📊 **Enterprise Logging**: Centralized logging with multiple levels
- 🔧 **Git Workflow**: Automated patch management with PR/issue creation
- 🧪 **Testing Framework**: Bulletproof validation with Pester integration

**Core Modules:** Logging, ConfigurationCore, ModuleCommunication, LicenseManager
**Feature Modules:** LabRunner, PatchManager, BackupManager, DevEnvironment, OpenTofuProvider, UserExperience, AIToolsIntegration, TestingFramework, and more.

## 📋 Requirements

- **PowerShell 5.1+** (PowerShell 7+ recommended)
- **Git** (for repository operations)
- **OpenTofu/Terraform** (for infrastructure automation)
- **Windows/Linux/macOS** (cross-platform compatible)

*Optional: Node.js 18+, Claude Code (for AI features)*

## 💡 Usage Examples

```bash
# After installation, start with:
aither init                                    # Interactive setup
aither help                                    # Show all commands

# Development workflows:
# Note: Use Invoke-ReleaseWorkflow for creating releases
# aither dev commands are for other development tasks

# Infrastructure operations:
aither deploy plan ./infrastructure            # Plan deployment
aither deploy apply ./infrastructure           # Apply changes

# Module operations:
aither backup cleanup --retention 30           # Cleanup old backups
aither lab deploy --config lab-config.json     # Deploy lab environment
```

## 🏗️ Architecture

```text
AitherZero/
├── aither.ps1              # Modern CLI interface
├── aither-core/            # Core application engine
│   ├── modules/           # 28+ PowerShell modules
│   └── shared/            # Shared utilities
├── configs/                # Configuration templates
└── opentofu/               # Infrastructure templates
```

## 📚 Documentation

- **[Contributing Guide](CONTRIBUTING.md)** - Development setup and guidelines
- **[Testing Guide](docs/BULLETPROOF-TESTING-GUIDE.md)** - Comprehensive testing documentation
- **[PatchManager Guide](docs/PATCHMANAGER-COMPLETE-GUIDE.md)** - Git workflow automation
- **[Examples](docs/examples/)** - Common usage patterns and scripts

## 🔄 Support & Community

- **Issues**: [GitHub Issues](https://github.com/wizzense/AitherZero/issues)
- **Discussions**: [GitHub Discussions](https://github.com/wizzense/AitherZero/discussions)
- **License**: [MIT License](LICENSE)

---

**Made with ❤️ for infrastructure automation**

