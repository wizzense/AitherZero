# AitherZero Quick Start Guide

## 🚀 Ultra-Simple Installation

**One command installs and runs AitherZero:**

```powershell
# Copy and paste this command:
iex (irm "https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1")
```

**That's it!** This command:
- ✅ Downloads the latest release
- ✅ Extracts it automatically  
- ✅ Starts the setup wizard
- ✅ Works on Windows, Linux, and macOS
- ✅ Compatible with PowerShell 5.1+

## 📦 Alternative: Manual Installation

If you prefer manual control:

1. **Download**: Go to [releases](https://github.com/wizzense/AitherZero/releases/latest)
2. **Extract**: Unzip the downloaded file
3. **Run**: `.\Start-AitherZero.ps1 -Setup`

## 🏃 Getting Started

### First Time Setup
```powershell
# Run the setup wizard (auto-detects PowerShell version)
.\Start-AitherZero.ps1 -Setup

# For PowerShell 5.1 users, ensure execution policy allows scripts
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Basic Usage
```powershell
# Interactive mode with menu
.\Start-AitherZero.ps1 -Interactive

# Run specific modules
.\Start-AitherZero.ps1 -Scripts "BackupManager,LabRunner"

# Automated mode
.\Start-AitherZero.ps1 -Auto
```

## 💡 PowerShell Version Notes

### PowerShell 5.1 (Windows Default)
- ✅ Basic functionality works
- ⚠️ Some advanced features may be limited
- 🔧 `Start-AitherZero.ps1` automatically detects and adapts to your PowerShell version

### PowerShell 7+ (Recommended)
- ✅ Full feature support
- ✅ Cross-platform (Windows, Linux, macOS)
- 📥 Download: https://aka.ms/powershell

## 🆘 Troubleshooting

### "Scripts are disabled on this system"
```powershell
# Run this first:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Cannot find modules"
```powershell
# Ensure you're in the AitherZero directory:
cd AitherZero
.\Start-AitherZero.ps1 -Setup
```

### Installation Fails
Try the manual download method (Method 3) or:
```powershell
# Download the fixed installer directly
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/wizzense/AitherZero/main/get-aither.ps1" -OutFile "get-aither.ps1"
.\get-aither.ps1
```

## 📋 Prerequisites

### Required
- Windows PowerShell 5.1+ or PowerShell Core 7+
- Internet connection for download

### Optional (for full features)
- Git for version control
- OpenTofu or Terraform for infrastructure deployment
- PowerShell 7+ for advanced features

## 🎯 Quick Commands

```powershell
# Check your PowerShell version
$PSVersionTable.PSVersion

# Quick health check
.\Start-AitherZero.ps1 -WhatIf

# Get help
.\Start-AitherZero.ps1 -Help

# View available modules
Get-ChildItem .\aither-core\modules
```

## 📚 Next Steps

1. Run the setup wizard: `.\Start-AitherZero.ps1 -Setup`
2. Explore interactive mode: `.\Start-AitherZero.ps1 -Interactive`
3. Check out the full documentation in the `docs/` folder
4. Join our community discussions on GitHub

---

**Need Help?** Open an issue at: https://github.com/wizzense/AitherZero/issues