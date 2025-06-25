# 🚀 AitherZero v0.10.1 HOTFIX - PowerShell Compatibility Issue

## ❌ Problem

Users experiencing errors with v0.10.0 release:

- **PowerShell 5.1 compatibility**: #requires -Version 7.0 prevents execution
- **Parameter mismatch**: -Verbosity parameter not recognized by core script

## ✅ IMMEDIATE SOLUTION (Use Fixed Launchers)

### For Windows Users

#### Option 1: Use the Fixed Batch Launcher

`cmd
# This handles PowerShell version detection automatically
AitherZero-Fixed.bat
`

#### Option 2: Use the Fixed PowerShell Launcher

`powershell
# Compatible with PowerShell 5.1+ and 7.x
.\Start-AitherZero-Fixed.ps1 -Setup
.\Start-AitherZero-Fixed.ps1 -Help
.\Start-AitherZero-Fixed.ps1 -Interactive
`

#### Option 3: Direct Core Script Execution

`powershell
# Bypass the launcher entirely - works on any PowerShell version
pwsh -ExecutionPolicy Bypass -File "aither-core.ps1" -Help
pwsh -ExecutionPolicy Bypass -File "aither-core.ps1" -Verbosity detailed
`

### For Linux/macOS Users

`ash
# The shell launcher should work correctly
./aitherzero.sh

# Or use PowerShell directly
pwsh -ExecutionPolicy Bypass -File "Start-AitherZero-Fixed.ps1" -Setup
`

## 🔧 What's Fixed in the Hotfix Launchers

### Start-AitherZero-Fixed.ps1

- ✅ **No #requires statement** - runs on PowerShell 5.1+
- ✅ **Proper parameter mapping** to ither-core.ps1
- ✅ **PowerShell 7 detection** with graceful fallback
- ✅ **Clear error messaging** and troubleshooting guidance
- ✅ **Cross-platform compatibility** maintained

### AitherZero-Fixed.bat

- ✅ **Automatic PowerShell detection** (tries pwsh first, falls back to powershell)
- ✅ **Enhanced error handling** with specific Windows guidance
- ✅ **Execution policy bypass** built-in
- ✅ **User-friendly output** with clear status messages

## 🔄 Parameter Mapping Reference

| Launcher Parameter | Core Script Parameter | Description |
|---|---|---|
| -Verbosity | -Verbosity | Logging level (silent/normal/detailed) |
| -Scripts | -Scripts | Specific modules to run |
| -Auto | -Auto | Automated execution mode |
| -ConfigFile | -ConfigFile | Custom configuration file |
| -Setup | N/A | First-time setup wizard (launcher only) |
| -Help | -Help | Usage information |

## 🎯 Quick Validation

Test that the hotfix works:

`powershell
# Test setup mode
.\Start-AitherZero-Fixed.ps1 -Setup

# Test interactive mode
.\Start-AitherZero-Fixed.ps1 -Interactive

# Test with verbosity
.\Start-AitherZero-Fixed.ps1 -Verbosity detailed

# Test help
.\Start-AitherZero-Fixed.ps1 -Help
`

## �� Next Release (v0.10.2)

The next release will integrate these fixes into the main launchers:

- Replace Start-AitherZero.ps1 with the fixed version
- Replace AitherZero.bat with the fixed version
- Update workflow to generate compatible launchers
- Remove strict #requires statements from generated scripts

## 💡 For Developers

If you're building from source, the fixed launchers are already in the repository:

- Start-AitherZero-Fixed.ps1 (main fix)
- AitherZero-Fixed.bat (Windows batch fix)

These will be integrated into the build workflow for future releases.
