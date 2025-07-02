# 🚀 AitherZero v1.3.2 - Download and Test Guide

Welcome to AitherZero Infrastructure Automation Framework! This guide will help you quickly download, test, and get started with AitherZero.

## 📦 Quick Download Options

### Option 1: Local Package (Recommended for Testing)
Download the latest local build package: **AitherZero-1.3.2-windows-local.zip** (135 KB)

**What's included:**
- ✅ Core runner script (`aither-core.ps1`)
- ✅ Essential modules (Logging, LabRunner, DevEnvironment, etc.)
- ✅ Shared utilities and helpers
- ✅ Windows launcher scripts (`.bat` and `.ps1`)
- ✅ Documentation and license

### Option 2: Full Repository Clone
```bash
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero
```

### Option 3: GitHub Release Download
Visit: https://github.com/wizzense/AitherZero/releases/tag/v1.3.2

## 🏃‍♂️ Quick Start - Test in 30 Seconds

### Windows Users:
1. **Download** `AitherZero-1.3.2-windows-local.zip`
2. **Extract** to any folder (e.g., `C:\AitherZero\`)
3. **Run** either:
   - Double-click `AitherZero.bat` (Windows batch file)
   - Or run in PowerShell: `.\Start-AitherZero.ps1`

### PowerShell Users:
```powershell
# Download and test in one command (if you have the zip file)
Expand-Archive AitherZero-1.3.2-windows-local.zip -DestinationPath .\AitherZero-Test
cd .\AitherZero-Test
.\Start-AitherZero.ps1
```

## ✅ What to Expect

When you run AitherZero, you should see:

```
🚀 AitherZero Infrastructure Automation Framework v1.3.2
   Local Build - Essential Components Only

[Timestamp] [INFO] Starting AitherZero Infrastructure Automation Framework
[Timestamp] [INFO] Project root detected: C:\Your\Path\Here
[Timestamp] [INFO] Loading essential modules...
```

## 🧪 Test Features

### 1. Test Core Functionality
```powershell
# Check available modules
.\Start-AitherZero.ps1 -ListModules

# Test logging system
.\Start-AitherZero.ps1 -TestLogging

# Show help
.\Start-AitherZero.ps1 -Help
```

### 2. Test Development Tools
```powershell
# Initialize development environment
.\Start-AitherZero.ps1 -InitDev

# Run quick validation
.\Start-AitherZero.ps1 -Validate Quick
```

### 3. Test Lab Runner (Advanced)
```powershell
# List available lab scripts
.\Start-AitherZero.ps1 -ListLabs

# Run a simple lab setup
.\Start-AitherZero.ps1 -RunLab Setup
```

## 🛠️ Development Testing (Full Repository)

If you cloned the full repository, you can test the complete development experience:

### VS Code Integration
1. **Open** the repository in VS Code
2. **Install** recommended extensions (PowerShell, GitLens, etc.)
3. **Press** `Ctrl+Shift+P` and type "Tasks"
4. **Try** these tasks:
   - `🚀 Bulletproof Validation - Quick` (30 seconds)
   - `🔧 Development: Setup Complete Environment`
   - `📦 Local Build: Create Windows Package`

### Command Line Testing
```powershell
# Quick module validation (3 seconds)
.\Quick-ModuleCheck.ps1

# Fast test suite (10-30 seconds)
.\Turbo-Test.ps1 -TestLevel Fast

# Full validation (2-5 minutes)
.\tests\Run-BulletproofValidation.ps1 -ValidationLevel Standard
```

## 🔧 Common Issues & Solutions

### Issue: "Execution policy not set"
**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Issue: "Module not found"
**Solution:**
```powershell
# Make sure you're in the AitherZero directory
cd C:\Path\To\AitherZero
# Run with full path
pwsh -File .\Start-AitherZero.ps1
```

### Issue: "PowerShell version too old"
**Solution:**
- Install PowerShell 7.0+ from: https://github.com/PowerShell/PowerShell/releases
- Or use Windows PowerShell 5.1+ as fallback

## 📊 Performance Expectations

| Test Type | Expected Time | Description |
|-----------|---------------|-------------|
| Package Download | < 10 seconds | Download 135KB package |
| First Launch | 5-10 seconds | Initial module loading |
| Quick Validation | 30 seconds | Core functionality test |
| Standard Validation | 2-5 minutes | Full test suite |
| Complete Validation | 10-15 minutes | Comprehensive testing |

## 🎯 Next Steps

Once you've verified AitherZero works:

1. **Explore** the available modules and features
2. **Read** the full documentation in `docs/`
3. **Try** building infrastructure with OpenTofu integration
4. **Contribute** by reporting issues or submitting PRs
5. **Join** the community discussions

## 🆘 Need Help?

- **Documentation:** Check the `docs/` folder
- **Issues:** https://github.com/wizzense/AitherZero/issues
- **Quick Start:** See `docs/QUICKSTART.md`
- **Examples:** Check `examples/` folder

## 🌟 What Makes AitherZero Special?

- ⚡ **Ultra-fast** module validation (3 seconds)
- 🎯 **Bulletproof** testing framework
- 🚀 **Turbo** testing modes for rapid development
- 🔧 **VS Code** fully integrated development experience
- 📦 **Local packages** for easy distribution
- 🌐 **Cross-platform** PowerShell 7.0+ support

---

**Ready to automate your infrastructure?** Start with the Quick Start section above! 🚀

*AitherZero v1.3.2 - Built for developers, by developers*
