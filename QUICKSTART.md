# AitherZero Quick Start Guide

> **🏃 Need to get started in 5 minutes?** → [**5-Minute Quick Start Guide**](QUICK_START_5MIN.md)

## 🚀 Ultra-Simple Installation

**One Command for All Platforms (Windows, Linux, macOS):**

```bash
# Copy and paste this command into your terminal:
curl -sSL https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.sh | bash
```

**That's it!** This single command automatically:
- ✅ Detects your operating system (Windows, Linux, or macOS).
- ✅ Ensures PowerShell 7+ is available (and helps you install it if needed).
- ✅ Downloads and starts the AitherZero setup wizard.
- ✅ Provides user-friendly error messages with solutions.

## 📦 Alternative: Manual Installation

If you prefer manual control:

1.  **Download**: Go to the [latest release](https://github.com/wizzense/AitherZero/releases/latest) and download the source code archive (`.zip` or `.tar.gz`).
2.  **Extract**: Unzip the downloaded file to a location of your choice.
3.  **Run**: Open a terminal, navigate to the extracted directory, and run:
    ```powershell
    ./Start-AitherZero.ps1 -Setup
    ```

## 🏃 Getting Started

### Single Entry Point - Everything Through One Script

**AitherZero uses ONE entry point for everything:**

```powershell
# First-time setup (auto-detects PowerShell version)
./Start-AitherZero.ps1 -Setup

# Interactive mode with menu (recommended for beginners)
./Start-AitherZero.ps1

# Run specific modules
./Start-AitherZero.ps1 -Scripts "BackupManager,LabRunner"

# Automated mode
./Start-AitherZero.ps1 -Auto

# Preview mode (see what would happen without doing it)
./Start-AitherZero.ps1 -WhatIf
```

### Installation Profiles

Choose your installation profile during setup:

-   **Minimal** (5-8 MB) - Core infrastructure deployment only
-   **Developer** (35-50 MB) - Full development environment with AI tools
-   **Full** (50+ MB) - Everything including advanced features

### PowerShell Version Handling

AitherZero's bootstrap process automatically:

-   ✅ Detects your PowerShell version.
-   ✅ Provides friendly guidance to install or upgrade to PowerShell 7+ if needed.
-   ✅ Handles execution policy issues gracefully.

## 💡 PowerShell Version Notes

### PowerShell 5.1 (Windows Default)

-   ✅ Basic functionality works.
-   ⚠️ Some advanced features may be limited.
-   🔧 `Start-AitherZero.ps1` automatically detects your version and will prompt you to upgrade to PowerShell 7+ for the best experience.

### PowerShell 7+ (Recommended)

-   ✅ Full feature support across Windows, Linux, and macOS.
-   📥 **Download:** [https://aka.ms/powershell](https://aka.ms/powershell)

## 🆘 Troubleshooting

**🎉 New: User-Friendly Error Messages!**

AitherZero now automatically shows clear, actionable solutions when things go wrong.

### "Scripts are disabled on this system"

**AitherZero will show you this friendly message:**

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                ⚠️  ERROR                                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│  PowerShell Execution Policy Issue                                             │
│                                                                                 │
│  How to fix it:                                                                 │
│  1. Run: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser  │
│  2. Then try running AitherZero again                                          │
└─────────────────────────────────────────────────────────────────────────────────┘
```

**Quick fix:**

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "PowerShell version not supported"

**AitherZero automatically detects this and shows:**

-   ✅ Your current PowerShell version.
-   ✅ Clear instructions for installing PowerShell 7.
-   ✅ Direct download links for your platform.

### Installation Fails

**AitherZero now provides detailed error analysis and solutions.**

Common fixes:

```powershell
# 1. Check your internet connection
Test-NetConnection -ComputerName github.com -Port 443

# 2. If you downloaded manually, ensure you are in the correct directory
pwd
Test-Path ./Start-AitherZero.ps1  # Should return True

# 3. If all else fails, try a forced setup
./Start-AitherZero.ps1 -Setup -Force
```

## 📋 Prerequisites

### Required

-   PowerShell 7+ (the bootstrap script will help you install it).
-   An internet connection for the initial download.

### Optional (for full features)

-   Git for version control.
-   OpenTofu or Terraform for infrastructure deployment.

## 🎯 Quick Commands

```powershell
# Check your PowerShell version
$PSVersionTable.PSVersion

# Quick health check
./Start-AitherZero.ps1 -WhatIf

# Get help
./Start-AitherZero.ps1 -Help

# View available modules
Get-ChildItem ./aither-core/modules
```

## 📚 Next Steps

**🎯 Choose Your Path:**

### 🚀 **For New Users:**

1.  **Start Interactive Mode**: `./Start-AitherZero.ps1` (a guided experience).
2.  **Try Preview Mode**: `./Start-AitherZero.ps1 -WhatIf` (safe exploration).
3.  **Read the 5-Minute Guide**: [QUICK_START_5MIN.md](QUICK_START_5MIN.md)

### 🏗️ **For Infrastructure Teams:**

1.  **Set up Lab Environment**: `./Start-AitherZero.ps1 -Scripts "LabRunner"`
2.  **Deploy Infrastructure**: `./Start-AitherZero.ps1 -Scripts "OpenTofuProvider"`
3.  **System Monitoring**: `./Start-AitherZero.ps1 -Scripts "SystemMonitoring"`

### 💻 **For Development Teams:**

1.  **Development Environment**: `./Start-AitherZero.ps1 -Scripts "DevEnvironment"`
2.  **Git Workflow Management**: `./Start-AitherZero.ps1 -Scripts "PatchManager"`
3.  **AI Tools Integration**: `./Start-AitherZero.ps1 -Scripts "AIToolsIntegration"`

### 📖 **Learning Resources:**

-   [Full Documentation](README.md) - The complete guide.
-   [Module Reference](aither-core/modules/) - Details on all 30+ modules.
-   [Configuration Guide](CLAUDE.md) - Advanced settings.
-   [Live Reports](https://wizzense.github.io/AitherZero/) - Project health.

**🆘 Getting Help:**

-   [GitHub Issues](https://github.com/wizzense/AitherZero/issues) - Report problems.
-   [Discussions](https://github.com/wizzense/AitherZero/discussions) - Ask questions.
-   [Community](https://github.com/wizzense/AitherZero/community) - Connect with other users.

---

**🎉 Remember:** AitherZero is designed to be user-friendly with automatic error handling and helpful guidance. You've got this!
