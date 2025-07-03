# AitherZero Quick Start Guide

## 🚀 Installation (3 Methods)

### Method 1: One-Liner (Recommended)
```powershell
# For PowerShell 5.1+ (Windows)
iex (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/wizzense/AitherZero/main/install-oneliner.ps1')

# Alternative syntax
(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/wizzense/AitherZero/main/install-oneliner.ps1') | iex
```

### Method 2: Git Clone
```powershell
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero
.\Start-AitherZero.ps1 -Setup
```

### Method 3: Manual Download
1. Download: https://github.com/wizzense/AitherZero/archive/refs/heads/main.zip
2. Extract the ZIP file
3. Open PowerShell and navigate to the extracted folder
4. Run: `.\Start-AitherZero.ps1 -Setup`

## 🏃 Getting Started

### First Time Setup
```powershell
# Run the setup wizard
.\Start-AitherZero.ps1 -Setup

# Or use the PowerShell 5.1 compatible version
.\Start-AitherZero-Compatible.ps1 -Setup
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
- 🔧 Use `Start-AitherZero-Compatible.ps1` for best compatibility

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