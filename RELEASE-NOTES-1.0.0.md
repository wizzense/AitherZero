# AitherZero v1.0.0 - First Stable Release with Unified Platform API 🎉

We're thrilled to announce the first stable release of AitherZero - a comprehensive PowerShell automation framework for OpenTofu/Terraform infrastructure management, now featuring the revolutionary Unified Platform API!

## 🚀 Quick Start

### One-Click Installation

**Windows:**
```powershell
# Download and run in one command:
$url = (irm "https://api.github.com/repos/wizzense/AitherZero/releases/latest").assets | ? name -like "*windows.zip" | % browser_download_url; iwr $url -OutFile "AitherZero.zip"; Expand-Archive "AitherZero.zip" -Force; cd AitherZero-*; .\AitherZero.bat
```

**Linux/macOS:**
```bash
# Download and run in one command:
curl -s https://api.github.com/repos/wizzense/AitherZero/releases/latest | grep "browser_download_url.*$(uname -s | tr '[:upper:]' '[:lower:]').tar.gz" | head -1 | cut -d '"' -f 4 | xargs curl -L | tar -xz && cd AitherZero-* && ./aitherzero.sh
```

## ✨ What's New in 1.0.0

### 🎯 Core Features
- **Unified Platform API** - Revolutionary single entry point with `Initialize-AitherPlatform`
- **20+ PowerShell Modules** for comprehensive infrastructure automation
- **AI Integration** with Claude Code MCP server (20+ tools)
- **Cross-Platform Support** for Windows, Linux, and macOS
- **Intelligent Setup Wizard** with installation profiles
- **Visual Progress Tracking** for long-running operations
- **Enterprise Features** including secure credentials and multi-environment configs
- **PatchManager Safety** - Never lose uncommitted work with automatic backups

### 📚 Documentation
- **Completely Reorganized** with clear navigation for all user types
- **Quick Start Guides** to get you running in minutes
- **Comprehensive Module Reference** for all 20+ modules
- **Developer Documentation** for contributors

### 🧪 Testing & Quality
- **Bulletproof Validation System** with 4 levels of testing
- **100% Module Coverage** with Pester tests
- **Cross-Platform CI/CD** with GitHub Actions
- **Performance Monitoring** built-in

## 📦 Download Options

### Application Packages (Recommended)
- **Windows**: `AitherZero-1.0.0-windows.zip` - Includes `AitherZero.bat` launcher
- **Linux**: `AitherZero-1.0.0-linux.tar.gz` - Includes `aitherzero.sh` launcher
- **macOS**: `AitherZero-1.0.0-macos.tar.gz` - Includes `aitherzero.sh` launcher

### Source Code
- **Source code (zip)**: Full repository with development tools
- **Source code (tar.gz)**: Full repository with development tools

## 🔧 Installation Profiles

Choose your setup experience:
- **Minimal** (2-3 min): Core modules + OpenTofu/Terraform
- **Developer** (5-7 min): Minimal + AI tools + MCP server
- **Full** (8-12 min): Everything including enterprise features

Run setup wizard after installation:
```powershell
./Start-AitherZero.ps1 -Setup
```

## 📋 Key Modules

### Infrastructure & Automation
- **LabRunner** - Lab automation orchestration
- **OpenTofuProvider** - Infrastructure deployment
- **OrchestrationEngine** - Advanced workflow automation
- **ConfigurationCarousel** - Multi-environment management

### Development & Operations
- **PatchManager** - Git workflow automation
- **BackupManager** - File backup and consolidation
- **DevEnvironment** - Development setup automation
- **SystemMonitoring** - Performance monitoring

### AI & Integration
- **AIToolsIntegration** - Claude Code, Gemini CLI management
- **MCP Server** - 20+ tools for AI automation
- **RestAPIServer** - External integrations
- **CloudProviderIntegration** - Multi-cloud support

## 🎯 Getting Started

1. **Download** your platform's package above
2. **Extract** the archive
3. **Run** the launcher (`AitherZero.bat` or `aitherzero.sh`)
4. **Follow** the setup wizard for first-time configuration

## 📖 Documentation

- [Installation Guide](https://github.com/wizzense/AitherZero/blob/main/docs/quickstart/installation.md)
- [Quick Start Guide](https://github.com/wizzense/AitherZero/blob/main/docs/quickstart/)
- [Module Reference](https://github.com/wizzense/AitherZero/blob/main/docs/guides/module-reference.md)
- [Troubleshooting](https://github.com/wizzense/AitherZero/blob/main/docs/quickstart/troubleshooting.md)

## 🤝 Contributing

We welcome contributions! See our [Contributing Guide](https://github.com/wizzense/AitherZero/blob/main/CONTRIBUTING.md) to get started.

## 🙏 Thank You

This release represents months of development, testing, and refinement. Thank you to all contributors who helped make AitherZero a reality!

## 📊 Stats
- **20+ Modules** for comprehensive automation
- **40+ Documentation Files** reorganized for clarity
- **100+ VS Code Tasks** for developer productivity
- **4 Testing Levels** for quality assurance
- **3 Platforms** supported out of the box

---

**Full Changelog**: https://github.com/wizzense/AitherZero/blob/main/CHANGELOG.md

**Report Issues**: https://github.com/wizzense/AitherZero/issues

**Get Help**: https://github.com/wizzense/AitherZero/discussions