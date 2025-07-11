# AitherZero Infrastructure Automation

**🚀 Standalone PowerShell automation framework** for OpenTofu/Terraform infrastructure management with comprehensive testing, modular architecture, and AI-powered automation.

[![Build Status](https://github.com/wizzense/AitherZero/actions/workflows/build-release.yml/badge.svg)](https://github.com/wizzense/AitherZero/actions)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![OpenTofu](https://img.shields.io/badge/OpenTofu-Compatible-orange.svg)](https://opentofu.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Contributors Welcome](https://img.shields.io/badge/Contributors-Welcome-brightgreen.svg)](CONTRIBUTING.md)

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
6. ✅ **PowerShell 5.1+ Compatible** - works on older systems

> 💡 **That's it!** No complex setup, no manual downloads, intelligent profile selection.

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
- 🔧 **18+ Specialized Modules** for infrastructure automation
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
./tests/Run-Tests.ps1 -Type Unit

# Build packages:
./build/Build-Package.ps1
```

**See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed development setup.**

---


## 🚀 Key Features

**Infrastructure Automation Framework:**
- 🔄 **Cross-Platform**: Windows, Linux, macOS with PowerShell 5.1+
- 🏗️ **Infrastructure as Code**: OpenTofu/Terraform integration
- 🧩 **Modular Architecture**: 18+ specialized PowerShell modules
- 🤖 **AI-Powered Automation**: Intelligent infrastructure management
- 📊 **Enterprise Logging**: Centralized logging with multiple levels
- 🔧 **Git Workflow**: Automated patch management with PR/issue creation
- 🧪 **Testing Framework**: Bulletproof validation with Pester integration

**Essential Modules:** LabRunner, PatchManager, BackupManager, DevEnvironment, OpenTofuProvider, SetupWizard, ProgressTracking, SecurityAutomation, and more.

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
│   ├── modules/           # 18+ PowerShell modules
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

