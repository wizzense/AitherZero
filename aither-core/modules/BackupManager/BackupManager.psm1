#
# BackupManager PowerShell Module
# Provides comprehensive backup management and maintenance capabilities
#

# Write-CustomLog fallback for test isolation scenarios
if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
    function Global:Write-CustomLog {
        param(
            [string]$Message,
            [string]$Level = 'INFO'
        )
        Write-Host "[$Level] $Message"
    }
}

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
