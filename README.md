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

### 🏃 **New Users: 5-Minute Quick Start Guide**
**👉 [**QUICK_START_5MIN.md**](QUICK_START_5MIN.md) - Complete beginner-friendly guide that gets you from zero to running AitherZero in 5 minutes!**

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

### 🚀 **SINGLE ENTRY POINT** - Works on All Platforms

There is **only ONE way** to start AitherZero (no confusion!):

```powershell
# ✅ THE ONLY WAY TO START AITHERZERO:
./Start-AitherZero.ps1

# ✅ First time? Run setup:
./Start-AitherZero.ps1 -Setup

# ✅ Get help:
./Start-AitherZero.ps1 -Help
```

**💡 Smart Features:**
- ✅ **Auto-detects PowerShell version** - works with PowerShell 5.1+ and 7+
- ✅ **Cross-platform** - same command on Windows, Linux, macOS  
- ✅ **Auto-launches PowerShell 7** if available
- ✅ **Clear installation guidance** if PowerShell 7 is needed
- ✅ **No wrappers or multiple scripts** - one entry point

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
- **[Setup Wizard Guide](aither-core/domains/experience/README.md)** - Interactive setup walkthrough
- **[Installation Profiles](configs/carousel/README.md)** - Profile selection and configuration

### 📖 **Domain Architecture Documentation**  
- **[Domain Architecture](aither-core/domains/README.md)** - Consolidated domain-based architecture overview
- **[Infrastructure Domain](aither-core/domains/infrastructure/README.md)** - Lab automation, OpenTofu deployment, ISO management, system monitoring
- **[Security Domain](aither-core/domains/security/README.md)** - Security automation, credential management, compliance hardening
- **[Configuration Domain](aither-core/domains/configuration/README.md)** - Multi-environment configuration management and switching
- **[Utilities Domain](aither-core/domains/utilities/README.md)** - Semantic versioning, license management, maintenance utilities
- **[Experience Domain](aither-core/domains/experience/README.md)** - Setup wizard, startup experience, user onboarding
- **[Automation Domain](aither-core/domains/automation/README.md)** - Script management and workflow orchestration

### 🛠️ **Development & Contributing**
- **[Contributing Guide](CONTRIBUTING.md)** - How to contribute to AitherZero
- **[GitHub Automation](.github/README.md)** - CI/CD workflows and release process  
- **[Testing Framework](tests/README.md)** - Testing patterns and validation
- **[Development Environment](aither-core/domains/experience/README.md)** - Development setup and tools

### 🧪 **Testing & Validation**
- **[Test Runner Guide](tests/README.md)** - Running tests and validation
- **[Performance Testing](docs/testing/)** - Performance benchmarks and optimization
- **[Quality Assurance](scripts/auditing/README.md)** - Code quality and duplicate detection

### 🏗️ **Infrastructure & Deployment**
- **[OpenTofu Templates](opentofu/README.md)** - Infrastructure as Code templates
- **[Configuration Templates](configs/README.md)** - Environment and profile configurations
- **[Build System](build/README.md)** - Package building and distribution

### 🔬 **Advanced Topics**
- **[Utility Services](aither-core/domains/utilities/README.md)** - License management, semantic versioning, maintenance utilities
- **[Security Automation](aither-core/domains/security/README.md)** - Enterprise security hardening and compliance
- **[Script Management](aither-core/domains/automation/README.md)** - Advanced script execution and orchestration

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
- 🔧 **6 Consolidated Domains** with 196+ functions for infrastructure automation (reduced from 30+ modules)
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

## 🌍 Platform Compatibility

AitherZero is designed for **cross-platform compatibility** with PowerShell 7.0+ and provides graceful degradation for platform-specific features:

### ✅ Fully Supported Platforms

| Platform | PowerShell Version | Status | Key Features |
|----------|-------------------|---------|-------------|
| **Windows** | 7.0+ (Core) | ✅ **Full Support** | Complete feature set including Windows Services, Registry, Event Logs |
| **Linux** | 7.0+ (Core) | ✅ **Full Support** | SystemD services, Unix permissions, package management |
| **macOS** | 7.0+ (Core) | ✅ **Full Support** | LaunchD services, Unix permissions, Homebrew integration |

### 🔧 Platform-Specific Features

| Feature | Windows | Linux | macOS | Fallback Behavior |
|---------|---------|-------|-------|-------------------|
| **Service Management** | Get-Service | systemctl | launchctl | Generic process management |
| **System Information** | WMI/CIM | /proc, /sys | system_profiler | Basic PowerShell cmdlets |
| **User Management** | AD/Local Users | /etc/passwd, useradd | dscl | Standard user operations |
| **Package Management** | winget/Chocolatey | apt/yum/dnf | brew/port | Manual installation |
| **File Permissions** | ACLs | chmod/chown | chmod/chown | Basic file operations |
| **Path Handling** | Backslash (\) | Forward slash (/) | Forward slash (/) | Automatic conversion |

### 🛠️ Cross-Platform Utilities

AitherZero includes built-in utilities for handling platform differences:

```powershell
# Automatic platform detection and path handling
Get-CrossPlatformPath -BasePath $env:HOME -ChildPath @("documents", "file.txt")
# Windows: C:\Users\username\documents\file.txt
# Linux/macOS: /home/username/documents/file.txt

# Platform-specific feature detection
Test-PlatformFeature -FeatureName "WindowsServices" -RequiredCommands @("Get-Service")
# Returns: IsSupported, AlternativeOptions, RecommendedAction

# Graceful feature execution with fallback
Invoke-PlatformFeatureWithFallback -FeatureName "ServiceManagement" -PrimaryAction { Get-Service } -FallbackAction { Get-Process }
```

### 📋 Platform Testing

Run platform-specific tests to validate compatibility:

```powershell
# Test cross-platform compatibility
./tests/Run-Tests.ps1 -Platform

# Generate platform compatibility report
./tests/platform/CrossPlatform.Tests.ps1
```

### ⚠️ Platform Limitations

- **Windows-only features**: Some security modules require Windows-specific APIs
- **Linux-only features**: SystemD-specific functionality not available on other platforms
- **macOS-only features**: LaunchD and native macOS integrations
- **Performance variations**: File system operations may vary in speed across platforms

---

## 🚀 Key Features

**Infrastructure Automation Framework:**
- 🔄 **Cross-Platform**: Windows, Linux, macOS with PowerShell 7.0+
- 🏗️ **Infrastructure as Code**: OpenTofu/Terraform integration
- 🧩 **Domain Architecture**: 6 consolidated domains with 196+ functions organized by business logic
- 🤖 **AI-Powered Automation**: Intelligent infrastructure management
- 📊 **Enterprise Logging**: Centralized logging with multiple levels
- 🔧 **Git Workflow**: Automated patch management with PR/issue creation
- 🧪 **Testing Framework**: Bulletproof validation with Pester integration
- ⚡ **Performance Optimized**: 50-80% faster CI/CD with parallel execution and caching

**Core Domains:** 
- **Infrastructure**: LabRunner, OpenTofuProvider, ISOManager, SystemMonitoring (57 functions)
- **Security**: SecureCredentials, SecurityAutomation (41 functions)
- **Configuration**: ConfigurationCore, ConfigurationCarousel, ConfigurationRepository, ConfigurationManager (36 functions)
- **Utilities**: SemanticVersioning, LicenseManager, RepoSync, UnifiedMaintenance, UtilityServices (24 functions)
- **Experience**: SetupWizard, StartupExperience (22 functions)  
- **Automation**: ScriptManager, OrchestrationEngine (16 functions)

### 🎯 Performance Metrics & Optimization

**CI/CD Performance Achievements:**
- ⚡ **50% Faster CI Execution** - Optimized from ~10 minutes to ~5 minutes
- 🚀 **Parallel Test Execution** - 2-4x speedup with intelligent throttling
- 💾 **Module Loading Optimization** - 50-80% faster with intelligent caching
- 📦 **Enhanced Dependency Caching** - 30-50% reduction in dependency install time
- 🔄 **Adaptive Resource Optimization** - Dynamic scaling based on system resources

**Current Performance Baseline:**
- **Test Execution**: Sub-2 minutes for core test suite
- **Module Loading**: <1 second parallel import of 30+ modules
- **CI Pipeline**: ~5 minutes end-to-end (down from ~10 minutes)
- **Cache Hit Rate**: >90% for modules and dependencies

[📊 View Performance Reports](https://wizzense.github.io/AitherZero/performance-metrics.html)

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
│   ├── domains/           # 6 business domains with 196+ functions
│   │   ├── infrastructure/    # Lab automation, OpenTofu, ISO, monitoring
│   │   ├── security/         # Security automation and credentials  
│   │   ├── configuration/    # Multi-environment configuration
│   │   ├── utilities/        # Version, license, maintenance utilities
│   │   ├── experience/       # Setup wizard and startup experience
│   │   └── automation/       # Script management and orchestration
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

