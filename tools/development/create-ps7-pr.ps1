Set-Location $PSScriptRoot
Import-Module ./aither-core/modules/PatchManager -Force

# Create PR for PowerShell 7 auto-installation feature
Invoke-PatchWorkflow -PatchDescription "Add automatic PowerShell 7 installation to bootstrap" -PatchOperation {
    # Changes already made to bootstrap.ps1
    $message = @"
PowerShell 7 auto-installation feature implemented in bootstrap.ps1:

## Changes:
1. Added Install-PowerShell7 helper function
   - Supports Windows, Linux, and macOS
   - Downloads latest PS7 release from GitHub
   - Handles admin/non-admin scenarios on Windows
   - Uses appropriate package managers on Linux/macOS

2. Enhanced PowerShell version check
   - Detects PS 5.1 and prompts for PS7 installation
   - Supports interactive mode with user prompts
   - Supports non-interactive mode via environment variables
   - Automatically re-launches bootstrap in PS7 after installation

3. Added environment variable documentation
   - AITHER_AUTO_INSTALL_PS7='true' for automatic installation

## Benefits:
- Completely automated dependency resolution
- No more manual PS7 installation required
- Seamless upgrade path from PS 5.1 to PS 7
- Works in CI/CD environments with non-interactive mode
"@
    Write-Host $message
} -CreatePR

Write-Host "PR creation completed!"
