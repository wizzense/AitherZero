# ⚡ AitherZero 5-Minute Quick Start Guide

> **🎯 Goal**: Get from zero to running AitherZero in 5 minutes or less!

**Perfect for**: New users, engineering teams, and anyone who wants to get started immediately.

---

## 🚀 Step 1: Install PowerShell 7 (1 minute)

**🪟 Windows (choose one):**
```powershell
# Windows Package Manager (fastest)
winget install Microsoft.PowerShell

# Or Chocolatey
choco install powershell-core

# Or download: https://aka.ms/powershell-release
```

**🐧 Linux:**
```bash
# Ubuntu/Debian
sudo snap install powershell --classic

# RHEL/CentOS
sudo yum install powershell
```

**🍎 macOS:**
```bash
# Homebrew
brew install --cask powershell
```

**✅ Verify installation:**
```powershell
pwsh --version
# Should show: PowerShell 7.x.x
```

---

## 📦 Step 2: Download AitherZero (1 minute)

**Option A: One-Command Install (Recommended)**
```powershell
# Copy and paste this command:
iex (irm "https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1")
```
✅ **This command downloads, extracts, and starts setup automatically!**

**Option B: Manual Download**
1. Go to [releases](https://github.com/wizzense/AitherZero/releases/latest)
2. Download the latest `.zip` file
3. Extract to a folder (e.g., `C:\AitherZero` or `~/AitherZero`)

---

## 🛠️ Step 3: First-Time Setup (2 minutes)

**Navigate to AitherZero directory:**
```powershell
cd AitherZero  # or wherever you extracted it
```

**Run the setup wizard:**
```powershell
./Start-AitherZero.ps1 -Setup
```

**Choose your installation profile:**
- **Minimal** (5-8 MB) - Core infrastructure only
- **Developer** (35-50 MB) - Full development environment (recommended)
- **Full** (50+ MB) - Everything including AI tools

**🎉 That's it! Setup is complete.**

---

## 🏃 Step 4: Take Your First Steps (1 minute)

**🖥️ Interactive Mode (Recommended for beginners):**
```powershell
./Start-AitherZero.ps1
```
This launches the interactive menu with guided options.

**🚀 Quick Demo:**
```powershell
# Run a specific module
./Start-AitherZero.ps1 -Scripts "LabRunner"

# Preview mode (see what would happen without doing it)
./Start-AitherZero.ps1 -WhatIf

# Get help
./Start-AitherZero.ps1 -Help
```

---

## 🎯 You're Done! (Total time: ~5 minutes)

**✅ What you've accomplished:**
- ✅ Installed PowerShell 7
- ✅ Downloaded and set up AitherZero
- ✅ Ran your first automation
- ✅ Ready for infrastructure deployment!

---

## 🔧 Common Issues & Solutions

### ❌ "Scripts are disabled on this system"
**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### ❌ "PowerShell version not supported"
**What you see:**
```
⚡ AitherZero Requires PowerShell 7 ⚡
```
**Solution:** AitherZero automatically shows installation instructions. Follow the yellow text.

### ❌ "Module not found" or "Write-CustomLog not recognized"
**Solution:** This has been fixed! But if you encounter it:
```powershell
./Start-AitherZero.ps1 -Setup
```

### ❌ "Cannot find AitherZero directory"
**Solution:**
```powershell
# Make sure you're in the right directory
pwd
ls  # Should show Start-AitherZero.ps1
```

---

## 🚀 Next Steps (Choose Your Adventure)

### 🏗️ **For Infrastructure Teams:**
```powershell
# Set up lab environments
./Start-AitherZero.ps1 -Scripts "LabRunner"

# Deploy OpenTofu/Terraform
./Start-AitherZero.ps1 -Scripts "OpenTofuProvider"
```

### 💻 **For Developers:**
```powershell
# Set up development environment
./Start-AitherZero.ps1 -Scripts "DevEnvironment"

# Use PatchManager for Git workflows
./Start-AitherZero.ps1 -Scripts "PatchManager"
```

### 🔧 **For System Administrators:**
```powershell
# System monitoring
./Start-AitherZero.ps1 -Scripts "SystemMonitoring"

# Backup management
./Start-AitherZero.ps1 -Scripts "BackupManager"
```

---

## 📖 Learning Resources

**📚 Quick References:**
- [Full Documentation](README.md) - Complete guide
- [Module List](aither-core/modules/) - All 30+ modules
- [Configuration Guide](CLAUDE.md) - Advanced settings

**🆘 Getting Help:**
- [GitHub Issues](https://github.com/wizzense/AitherZero/issues) - Report problems
- [Discussions](https://github.com/wizzense/AitherZero/discussions) - Ask questions
- [Live Reports](https://wizzense.github.io/AitherZero/) - Project health

---

## 🎉 Success Tips

**✅ Pro Tips:**
1. **Always use the single entry point**: `./Start-AitherZero.ps1`
2. **Start with interactive mode**: Great for exploring features
3. **Use `-WhatIf` first**: Preview changes before applying
4. **Check the logs**: AitherZero provides detailed feedback
5. **Join the community**: GitHub discussions for help

**🚨 Remember:**
- AitherZero automatically detects your PowerShell version
- User-friendly error messages guide you to solutions
- All modules are loaded automatically - no manual imports needed
- Cross-platform compatible (Windows/Linux/macOS)

---

## 🏆 You're Ready!

**Congratulations! You've successfully:**
- ✅ Installed AitherZero in under 5 minutes
- ✅ Learned the essential commands
- ✅ Know how to troubleshoot common issues
- ✅ Ready to automate your infrastructure!

**🚀 Welcome to the AitherZero community!**

---

*💡 This guide is designed to get you productive in 5 minutes. For advanced features, see the [full documentation](README.md) or explore the interactive mode: `./Start-AitherZero.ps1`*