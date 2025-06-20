# Menu Selection Off-By-One Error Fix

## Problem Description

Users experienced an off-by-one error when selecting scripts in the interactive menu:

- Typing "0002" would execute "0001_Reset-Git" instead of "0002_Setup-Directories"
- Typing "0006" would execute "0008_Install-OpenTofu" instead of "0006_Install-ValidationTools"

## Root Cause

The issue was in the script selection logic in `aither-core/core-runner.ps1` line 355:

```powershell
# BEFORE (problematic)
if ($item -match '^\d+$' -and [int]$item -le $availableScripts.Count -and [int]$item -gt 0) {
    $script = $availableScripts[[int]$item - 1]
}
```

**Problem**: The regex `^\d+$` matches ANY sequence of digits, including 4-digit script names like "0002". 

When a user typed "0002":
1. It matched `^\d+$` (all digits)
2. Got converted to integer `2` 
3. Was treated as menu position 2
4. Selected `$availableScripts[2-1] = $availableScripts[1]` (the second script)
5. But the user wanted script "0002_Setup-Directories"

## Solution

Changed the regex pattern to only match 1-2 digit numbers as menu positions:

```powershell
# AFTER (fixed)
if ($item -match '^\d{1,2}$' -and [int]$item -le $availableScripts.Count -and [int]$item -gt 0) {
    $script = $availableScripts[[int]$item - 1]
}
```

## Behavior After Fix

| User Input | Interpretation | Result |
|------------|----------------|---------|
| "1" | Menu position 1 | Executes first script in menu |
| "12" | Menu position 12 | Executes 12th script in menu |
| "38" | Menu position 38 | Executes 38th script in menu |
| "0002" | Script name | Finds script matching "0002*" |
| "0006" | Script name | Finds script matching "0006*" |
| "123" | Script name | Finds script matching "123*" |

## Testing

The fix was verified with comprehensive test cases:

```powershell
✅ '1' -> Menu (Single digit menu number)
✅ '12' -> Menu (Two digit menu number)  
✅ '38' -> Menu (Large two digit menu number)
✅ '0002' -> Script (Four digit script name)
✅ '0006' -> Script (Another four digit script name)
✅ '123' -> Script (Three digit number)
✅ 'abc' -> Script (Non-numeric input)
```

## Impact

- ✅ Users can now type "0002" to execute "0002_Setup-Directories"
- ✅ Users can now type "0006" to execute "0006_Install-ValidationTools"  
- ✅ Traditional menu numbers (1, 2, 12, 38) still work as expected
- ✅ No breaking changes for existing workflows
- ✅ Backward compatible with all existing usage patterns

This fix resolves the confusing off-by-one behavior while maintaining full compatibility with existing menu functionality.
