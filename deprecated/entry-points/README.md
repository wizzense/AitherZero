# Deprecated Entry Points

These files have been moved to this directory as part of AitherZero entry point simplification.

## Files Moved (July 2025)

### Redundant Universal Launchers
- **`aitherzero.ps1`** - Redundant middle layer launcher
- **`aitherzero.cmd`** - Redundant Windows wrapper
  
**Reason for removal**: These provided the same functionality as the simpler aither.cmd/aither.ps1 and Start-AitherZero.cmd/Start-AitherZero.ps1 combination.

### Bootstrap Script
- **`bootstrap.ps1`** - Original bootstrap script (v2.1)

**Reason for removal**: Replaced by `bootstrap-fixed.ps1` (now renamed to `bootstrap.ps1`) which has better Windows 11 compatibility and more robust error handling.

## Current Entry Points (Simplified)

### For End Users
- **`aither init`** - Modern CLI interface (recommended)
- **`aither.cmd`** - Windows wrapper for aither.ps1

### For Advanced Users
- **`./Start-AitherZero.ps1`** - Full application with all parameters
- **`Start-AitherZero.cmd`** - Windows wrapper for Start-AitherZero.ps1

### For Installation
- **`bootstrap.ps1`** - Reliable remote installation script
- **`bootstrap.sh`** - Linux/macOS installation script

## Migration Guide

If you were using the deprecated files:

| Old Command | New Command |
|-------------|-------------|
| `aitherzero.ps1` | `aither init` or `./Start-AitherZero.ps1` |
| `aitherzero.cmd` | `aither.cmd` or `Start-AitherZero.cmd` |
| Old bootstrap URLs | Use updated GitHub raw URLs pointing to new bootstrap.ps1 |

## Benefits of Simplification

- **Reduced confusion**: 8 → 5 entry points (38% fewer files)
- **Clearer user journey**: Modern CLI → Full application → Installation
- **Better maintainability**: Less redundant code to maintain
- **Improved reliability**: Kept the working versions, removed problematic ones

This cleanup was performed as part of the comprehensive AitherZero organization and documentation improvement project.