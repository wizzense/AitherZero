## 🐛 Bug Fixes - Bootstrap PowerShell 7 Installation Issues

- **Fixed window closing during PS7 installation** - Bootstrap no longer closes immediately when PowerShell 7 installation is triggered
- **Fixed script path detection for IEX execution** - When running via `iex`, the script properly saves itself to temp for re-launch
- **Added proper error handling** - Clear error messages with pause before window closure (interactive mode only)
- **Fixed re-launch mechanism** - PowerShell 7 window now stays open with `-NoExit` flag

## 🔧 What's Changed

- **Added Exit-Bootstrap function** (lines 22-46)
  - Pauses before exit on error in interactive mode
  - Shows clear error messages
  - Cleans up temporary files
  - Respects CI/CD environment variables

- **Enhanced script path detection** (lines 576-589)
  - Downloads and saves script to temp when running via `iex`
  - Properly handles re-launch from temporary location
  - Automatic cleanup after completion

- **Improved re-launch logic** (lines 591-609)
  - Added `-NoExit` flag to keep PowerShell 7 window open
  - Better status messages during re-launch process
  - Wait for new process to complete before exiting

- **Updated all exit points** to use proper error handling
  - Lines 620, 628, 634, 686 now use Exit-Bootstrap function

## 💡 Notes

This release specifically fixes the critical issue where the bootstrap installer window would close immediately without feedback when installing PowerShell 7. The one-liner installation now provides a smooth user experience:

```powershell
# Now works perfectly without window closing issues!
iex (irm "https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1")
```

## 📥 Installation

```powershell
# One-liner installation (fixed!)
irm https://github.com/wizzense/AitherZero/releases/download/v0.6.15/bootstrap.ps1 | iex
```

## 📦 Packages

- **AitherZero-0.6.15-minimal-windows.zip** - Minimal installation (0.05 MB)
- **AitherZero-0.6.15-standard-windows.zip** - Standard installation (0.38 MB) 
- **AitherZero-0.6.15-development-windows.zip** - Full development installation (0.77 MB)
- **aitherzero-standard-windows-latest.zip** - Compatibility alias for standard
- **aitherzero-full-windows-latest.zip** - Compatibility alias for development

## 🧪 Testing

All changes tested with PowerShell 5.1:
- ✅ Syntax validation passed
- ✅ Functions properly defined  
- ✅ Script path detection for IEX verified
- ✅ Error handling tested
- ✅ Window closing issue resolved