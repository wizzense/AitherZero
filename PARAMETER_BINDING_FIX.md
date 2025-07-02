# AitherZero Parameter Binding Fix

## Issue Fixed
The startup error "Cannot bind parameter because parameter 'Parent' is specified more than once" has been resolved.

## Root Cause
The error was caused by incorrect PowerShell syntax in multiple files where `Split-Path` was used with the `-Parent` parameter positioned incorrectly:

```powershell
# INCORRECT - Parameter before path
Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
```

## Solution Applied
Fixed the syntax by placing the `-Parent` parameter after the path argument:

```powershell
# CORRECT - Parameter after path  
Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
```

## Files Fixed
1. `aither-core/shared/ModuleImporter.ps1` (Line 16)
2. `tests/archive/unit/modules/RealWorld-Workflows.Tests.ps1` (Line 8)
3. `tests/archive/unit/modules/ParallelExecution/ParallelExecution-Core.Tests.ps1` (Line 14)

## Testing
To verify the fix, run AitherZero from a PowerShell terminal:

```powershell
# Option 1: Standard launch
./Start-AitherZero.ps1

# Option 2: Help mode (simpler test)
./Start-AitherZero.ps1 -Help

# Option 3: Setup mode
./Start-AitherZero.ps1 -Setup
```

The application should now start without the parameter binding error.

## Additional Notes
- Ensure you're using PowerShell 7.0+ for full compatibility
- If issues persist, check for any local modifications in the `local-build` directory
- The fix ensures proper path resolution for finding the project root directory