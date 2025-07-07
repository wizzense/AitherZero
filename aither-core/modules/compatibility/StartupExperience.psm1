# StartupExperience Compatibility Shim
# This module provides a compatibility layer for the StartupExperience module
# StartupExperience is still an active module - this shim ensures backward compatibility

# Find and import the actual StartupExperience module
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot
$startupExperiencePath = Join-Path $projectRoot "aither-core/modules/StartupExperience"

# Import the actual module
if (Test-Path $startupExperiencePath) {
    try {
        Import-Module $startupExperiencePath -Force -ErrorAction Stop
        Write-Verbose "[COMPATIBILITY] StartupExperience module loaded successfully."
        
        # Export all functions from the loaded module
        $moduleInfo = Get-Module StartupExperience
        if ($moduleInfo) {
            Export-ModuleMember -Function $moduleInfo.ExportedFunctions.Keys
        }
    } catch {
        Write-Error "Failed to load StartupExperience module: $_"
        throw
    }
} else {
    Write-Error "StartupExperience module not found at expected location: $startupExperiencePath"
    throw "StartupExperience module is required but not found."
}