Set-Location $PSScriptRoot
Import-Module ./aither-core/modules/PatchManager -Force

# Create PR for bootstrap fixes
Invoke-PatchWorkflow -PatchDescription "Fix bootstrap PowerShell 7 installation issues" -PatchOperation {
    $message = @"
Fixed critical bootstrap issues that caused window to close during PS7 installation:

## Issues Fixed:
1. Window closing immediately when running via iex
2. Script path detection failing for iex execution
3. No error feedback when installation fails
4. Missing CI/CD support for non-interactive mode
5. No option to reinstall/clean corrupted PS7

## Changes:
1. Added Exit-Bootstrap function
   - Pauses before exit on error (interactive mode)
   - Shows clear error messages
   - Cleans up temp files

2. Fixed script path detection for IEX
   - Downloads and saves script to temp when path not available
   - Properly handles re-launch from temp location

3. Improved re-launch logic
   - Added -NoExit flag to keep window open
   - Better status messages during re-launch
   - Proper environment variable preservation

4. Added PS7 management options
   - AITHER_REINSTALL_PS7='true' to force reinstall
   - AITHER_CLEAN_PS7='true' to remove existing installation
   - AITHER_PS7_MSI_URL for custom download URLs
   - AITHER_BYPASS_PS7_CHECK='true' to skip PS7 requirement

5. Enhanced CI/CD support
   - All prompts respect environment variables
   - Non-interactive mode properly handled
   - Better error codes for automation

## Testing:
All changes tested with PowerShell 5.1:
- Syntax validation passed
- Functions properly defined
- Environment variables documented
"@
    Write-Host $message
} -CreatePR

Write-Host "PR creation completed!"