# Enhanced Script Module Import Template
# This template provides comprehensive module loading for all aither-core scripts

function Import-AitherCoreModules {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$RequiredModules = @(),

        [Parameter()]
        [switch]$SuppressWarnings
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

        # Available modules in aither-core
        $availableModules = @{
            'BackupManager' = @{
                Description = 'File backup, cleanup, and consolidation operations'
                Functions = @('Start-BackupOperation', 'Remove-OldBackups', 'Invoke-BackupConsolidation')
            }
            'DevEnvironment' = @{
                Description = 'Development environment preparation and validation'
                Functions = @('Initialize-DevEnvironment', 'Test-DevEnvironmentReady', 'Install-DevTools')
            }
            'ISOCustomizer' = @{
                Description = 'ISO customization and template management'
                Functions = @('New-CustomISO', 'Add-ISOPackages', 'Set-ISOConfiguration')
            }
            'ISOManager' = @{
                Description = 'ISO download, verification, and management'
                Functions = @('Get-WindowsISO', 'Test-ISOIntegrity', 'Mount-ISOFile')
            }
            'LabRunner' = @{
                Description = 'Lab automation orchestration and test execution coordination'
                Functions = @('Invoke-LabStep', 'Get-LabConfig', 'Initialize-StandardParameters')
            }
            'Logging' = @{
                Description = 'Centralized logging with levels (INFO, WARN, ERROR, SUCCESS)'
                Functions = @('Write-CustomLog', 'Initialize-LoggingSystem', 'Get-LoggingConfiguration')
            }
            'OpenTofuProvider' = @{
                Description = 'OpenTofu provider management and infrastructure automation'
                Functions = @('Initialize-OpenTofuProvider', 'Deploy-Infrastructure', 'Test-ProviderConfiguration')
            }
            'ParallelExecution' = @{
                Description = 'Runspace-based parallel task execution'
                Functions = @('Invoke-ParallelTasks', 'Start-ParallelJob', 'Wait-ParallelJobs')
            }
            'PatchManager' = @{
                Description = 'Patch management with git-controlled workflows'
                Functions = @('Invoke-PatchWorkflow', 'New-PatchIssue', 'New-PatchPR', 'Invoke-PatchRollback')
            }
            'RemoteConnection' = @{
                Description = 'Remote connection management and automation'
                Functions = @('New-RemoteSession', 'Invoke-RemoteCommand', 'Test-RemoteConnection')
            }
            'ScriptManager' = @{
                Description = 'Script repository management and template handling'
                Functions = @('Get-ScriptTemplate', 'New-ScriptFromTemplate', 'Update-ScriptRepository')
            }
            'SecureCredentials' = @{
                Description = 'Secure credential management and storage'
                Functions = @('Get-SecureCredential', 'Set-SecureCredential', 'Test-CredentialStore')
            }
            'TestingFramework' = @{
                Description = 'Pester test wrapper with project-specific configurations'
                Functions = @('Invoke-ProjectTests', 'New-TestCase', 'Get-TestResults')
            }
            'UnifiedMaintenance' = @{
                Description = 'Unified entry point for all maintenance operations'
                Functions = @('Start-MaintenanceTask', 'Get-MaintenanceStatus', 'Stop-MaintenanceTask')
            }
        }

        # Import core modules (always needed)
        $coreModules = @('LabRunner', 'Logging')
        $allModules = $coreModules + $RequiredModules | Sort-Object -Unique

        $importedModules = @{}

        foreach ($moduleName in $allModules) {
            try {
                $modulePath = Join-Path $ProjectRoot (Join-Path "aither-core" (Join-Path "modules" (Join-Path $moduleName "$moduleName.psm1")))
                if (Test-Path $modulePath) {
                    Import-Module $modulePath -Force -Global -ErrorAction Stop
                    $importedModules[$moduleName] = $true
                    Write-Verbose "Successfully imported $moduleName from aither-core/modules"
                } else {
                    # Fallback to Import-ModuleSafe
                    $result = Import-ModuleSafe -ModuleName $moduleName -ProjectRoot $ProjectRoot -Force -CreateMockOnFailure
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
            AvailableModules = $availableModules
        }
    } catch {
        Write-Error "Failed to import aither-core modules: $($_.Exception.Message)"
        throw    }
}

# Function is automatically available when dot-sourced
# Export-ModuleMember is only valid in .psm1 modules, not dot-sourced .ps1 files
# The conditional check doesn't work reliably for dot-sourced scripts
