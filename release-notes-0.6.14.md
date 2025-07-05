## 🐛 Bug Fixes

- **Fixed PowerShell 5.1 compatibility issue** - The bootstrap installer now works correctly on fresh Windows 11 installations
- **Resolved "positional parameter cannot be found" error** - Fixed Join-Path syntax incompatibility in Start-AitherZero.ps1
- **Bootstrap auto-start now works** - The application correctly launches after extraction

## 📦 What's Changed

- Modified line 57 in Start-AitherZero.ps1 to use nested Join-Path calls for PS 5.1 compatibility
- Changed from: `Join-Path $scriptPath "aither-core" "aither-core.ps1"`  
- To: `Join-Path (Join-Path $scriptPath "aither-core") "aither-core.ps1"`

## 💡 Notes

This critical fix ensures AitherZero works correctly on fresh Windows installations using the default PowerShell 5.1. The one-liner bootstrap installation should now complete successfully and auto-start the application.

## 📥 Installation

```powershell
# One-liner installation (now working!)
irm https://github.com/wizzense/AitherZero/releases/download/v0.6.14/bootstrap.ps1 | iex
```

## 📦 Packages

- **AitherZero-0.6.14-minimal-windows.zip** - Minimal installation (0.05 MB)
- **AitherZero-0.6.14-standard-windows.zip** - Standard installation (0.38 MB)
- **AitherZero-0.6.14-development-windows.zip** - Full development installation (0.77 MB)
- **aitherzero-standard-windows-latest.zip** - Compatibility alias for standard
- **aitherzero-full-windows-latest.zip** - Compatibility alias for development