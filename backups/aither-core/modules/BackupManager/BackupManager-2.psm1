#
# BackupManager PowerShell Module
# Provides comprehensive backup management and maintenance capabilities
#

# Initialize logging system with fallback support
. "$PSScriptRoot/../../shared/Initialize-Logging.ps1"
Initialize-Logging

# Get public and private function definition files
$publicFunctions = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)
$privateFunctions = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue)

# Dot source the functions
foreach ($import in @($publicFunctions + $privateFunctions)) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error -Message "Failed to import function $($import.FullName): $_"
    }
}

# Export public functions
Export-ModuleMember -Function $publicFunctions.BaseName
