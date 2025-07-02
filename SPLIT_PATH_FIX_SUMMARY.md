# Split-Path Parameter Binding Error Fix

## Issue Found
The PowerShell parameter binding error "A positional parameter cannot be found that accepts argument '-Parent'" was caused by incorrect syntax in the `Split-Path` cmdlet usage.

## Root Cause
The incorrect syntax was:
```powershell
Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
```

This syntax places `-Parent` before the path parameter in the outer `Split-Path` call, which causes PowerShell to interpret it as trying to bind `-Parent` twice to the same parameter, resulting in the error.

## Correct Syntax
The correct syntax should be:
```powershell
Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
```

## Files Fixed
1. `/mnt/c/Users/alexa/OneDrive/Documents/0. wizzense/AitherZero/aither-core/shared/ModuleImporter.ps1` (Line 16)
2. `/mnt/c/Users/alexa/OneDrive/Documents/0. wizzense/AitherZero/tests/archive/unit/modules/RealWorld-Workflows.Tests.ps1` (Line 8)
3. `/mnt/c/Users/alexa/OneDrive/Documents/0. wizzense/AitherZero/tests/archive/unit/modules/ParallelExecution/ParallelExecution-Core.Tests.ps1` (Line 14)

## Additional Files with Similar Pattern (Not Fixed)
- `/mnt/c/Users/alexa/OneDrive/Documents/0. wizzense/AitherZero/local-build/windows/AitherZero-1.3.2-windows-local/shared/ModuleImporter.ps1` (This is in a build directory and should be regenerated from source)

## Validation
The fix ensures that:
- The `-Parent` parameter is correctly positioned after the path input for each `Split-Path` call
- The nested calls work from inside out: first getting the parent of `$PSScriptRoot`, then getting the parent of that result

## Testing the Fix
To test that the fix works, run:
```powershell
./Start-AitherZero.ps1
```

The parameter binding error should no longer occur.