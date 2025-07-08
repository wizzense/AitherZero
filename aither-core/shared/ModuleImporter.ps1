# Enhanced Script Module Import Template
# This template provides comprehensive module loading for all aither-core scripts

function Import-AitherCoreModules {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$RequiredModules = @(),

        [Parameter()]
        [switch]$SuppressWarnings,
        
        [Parameter()]
        [switch]$Force
    )

    try {
        # Get project root
        $ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

        # Import shared utilities with warning suppression
        $oldWarningPreference = $WarningPreference
        if ($SuppressWarnings) { $WarningPreference = 'SilentlyContinue' }

        . "$ProjectRoot/aither-core/shared/PathManagement.ps1"
        . "$ProjectRoot/aither-core/shared/PrivilegeManagement.ps1"
        $ProjectRoot = Find-ProjectRoot -StartPath $PSScriptRoot

        $WarningPreference = $oldWarningPreference
        
        # Use standardized AitherCore orchestration approach
        $aitherCorePath = Join-Path $ProjectRoot "aither-core/AitherCore.psm1"
        if (Test-Path $aitherCorePath) {
            try {
                # Import AitherCore orchestration module
                Import-Module $aitherCorePath -Force:$Force -Global -ErrorAction Stop
                
                # Determine loading strategy based on requirements
                $requireOnly = $RequiredModules.Count -eq 0
                
                # Use AitherCore's sophisticated module loading
                $result = Import-CoreModules -RequiredOnly:$requireOnly -Force:$Force
                
                return @{
                    ProjectRoot = $ProjectRoot
                    ImportedModules = @{}
                    LoadingResult = $result
                    AvailableModules = @{}
                    StandardizedApproach = $true
                }
            } catch {
                Write-Warning "Failed to use AitherCore orchestration approach: $_"
                # Fall back to legacy approach
            }
        }

        # Legacy fallback approach (only used when AitherCore orchestration fails)
        Write-Warning "Using legacy module import approach as fallback"
        
        # Import core modules (always needed)
        $coreModules = @('LabRunner', 'Logging')
        $allModules = $coreModules + $RequiredModules | Sort-Object -Unique

        $importedModules = @{}

        foreach ($moduleName in $allModules) {
            try {
                $modulePath = Join-Path $ProjectRoot (Join-Path "aither-core" (Join-Path "modules" (Join-Path $moduleName "$moduleName.psm1")))
                if (Test-Path $modulePath) {
                    Import-Module $modulePath -Force:$Force -Global -ErrorAction Stop
                    $importedModules[$moduleName] = $true
                    Write-Verbose "Successfully imported $moduleName from aither-core/modules"
                } else {
                    # Fallback to Import-ModuleSafe
                    $result = Import-ModuleSafe -ModuleName $moduleName -ProjectRoot $ProjectRoot -Force:$Force -CreateMockOnFailure
                    $importedModules[$moduleName] = $result
                    if (-not $result) {
                        Write-Warning "$moduleName module import failed, using mock functions"
                    }
                }
            } catch {
                Write-Warning "$moduleName module import failed: $($_.Exception.Message)"
                $importedModules[$moduleName] = $false
            }
        }

        return @{
            ProjectRoot = $ProjectRoot
            ImportedModules = $importedModules
            AvailableModules = @{}
            StandardizedApproach = $false
        }
    } catch {
        Write-Error "Failed to import aither-core modules: $($_.Exception.Message)"
        throw    }
}

# Function is automatically available when dot-sourced
# Export-ModuleMember is only valid in .psm1 modules, not dot-sourced .ps1 files
# The conditional check doesn't work reliably for dot-sourced scripts
