## 🔧 Major Startup Fixes & Dependency Removal Features

This release completely resolves all startup issues and adds powerful dependency management capabilities for clean laptop setup.

### 🐛 Critical Startup Issues Fixed

- **✅ Missing configuration files** - Fixed missing `default-config.json` in configs directory
- **✅ Module loading errors** - Fixed `Find-ProjectRoot.ps1` path resolution in StartupExperience module
- **✅ Missing module manifests** - Created proper `SetupWizard.psd1` with correct exports
- **✅ LicenseManager integration** - Added automatic module loading with graceful fallbacks
- **✅ Configuration profile handling** - Enhanced error handling for missing profiles
- **✅ Terminal UI cursor positioning** - Fixed cursor positioning errors in WSL/Linux environments
- **✅ Console operations** - Added comprehensive error handling for non-interactive terminals

### 🗑️ New Dependency Removal Features

- **PowerShell 7 Removal** - Complete uninstallation support via winget and manual methods
- **Git Removal** - Automatic detection and removal of Git installations
- **Enhanced Uninstaller** - New `-RemoveDependencies` parameter for complete cleanup
- **Smart Detection** - Automatically finds and removes installed dependencies

### 🔧 What's Changed

- **Enhanced Remove-AitherZero.ps1** with dependency removal capabilities
- **Fixed ProgressTracking module** cursor positioning for cross-platform compatibility  
- **Improved StartupExperience module** with robust error handling
- **Added SetupWizard.psd1** with proper module manifest
- **Fixed OpenTofuProvider** console operations for better terminal compatibility

### 💡 Usage Examples

```powershell
# Clean installation removal including all dependencies
.\scripts\Remove-AitherZero.ps1 -RemoveDependencies

# Remove with confirmation skip
.\scripts\Remove-AitherZero.ps1 -RemoveDependencies -Force

# Keep user data but remove dependencies  
.\scripts\Remove-AitherZero.ps1 -RemoveDependencies -KeepData
```

### 🚀 Laptop Setup Ready

Perfect for setting up new laptops - the bootstrap installer now works flawlessly:

```powershell
# One-liner installation (now works without errors!)
iex (irm "https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1")
```

### 📦 Packages

- **AitherZero-0.6.16-minimal-windows.zip** - Minimal installation
- **AitherZero-0.6.16-standard-windows.zip** - Standard installation  
- **AitherZero-0.6.16-development-windows.zip** - Full development installation
- **aitherzero-standard-windows-latest.zip** - Compatibility alias for standard
- **aitherzero-full-windows-latest.zip** - Compatibility alias for development

### 🧪 Testing

All changes tested across:
- ✅ PowerShell 5.1 compatibility maintained
- ✅ PowerShell 7.x support enhanced
- ✅ WSL/Linux terminal compatibility verified  
- ✅ Windows native console verified
- ✅ Dependency removal tested (PowerShell 7, Git)
- ✅ Bootstrap installer verified working