#Requires -Version 7.0

<#
.SYNOPSIS
    Discovers and enumerates module capabilities for dynamic menu generation
.DESCRIPTION
    Scans all modules to extract metadata, functions, and capabilities
#>

function Get-ModuleCapabilities {
    [CmdletBinding()]
    param(
        [string]$ModulesPath = $env:PWSH_MODULES_PATH
    )
    
    $moduleInfo = @()
    
    if (-not $ModulesPath -or -not (Test-Path $ModulesPath)) {
        Write-Warning "Modules path not found: $ModulesPath"
        return $moduleInfo
    }
    
    # Module metadata definitions
    $moduleDescriptions = @{
        'LabRunner' = @{
            Description = 'Lab automation and infrastructure orchestration'
            Category = 'Infrastructure'
            MenuPriority = 10
        }
        'OpenTofuProvider' = @{
            Description = 'OpenTofu/Terraform infrastructure deployment'
            Category = 'Infrastructure'
            MenuPriority = 20
        }
        'BackupManager' = @{
            Description = 'File backup and restoration management'
            Category = 'Operations'
            MenuPriority = 30
        }
        'PatchManager' = @{
            Description = 'Git workflow automation and release management'
            Category = 'Development'
            MenuPriority = 40
        }
        'DevEnvironment' = @{
            Description = 'Development environment setup and management'
            Category = 'Development'
            MenuPriority = 50
        }
        'SetupWizard' = @{
            Description = 'Intelligent setup and configuration wizard'
            Category = 'Configuration'
            MenuPriority = 5
        }
        'ConfigurationCarousel' = @{
            Description = 'Multi-environment configuration management'
            Category = 'Configuration'
            MenuPriority = 15
        }
        'ConfigurationRepository' = @{
            Description = 'Git-based configuration repository management'
            Category = 'Configuration'
            MenuPriority = 25
        }
        'OrchestrationEngine' = @{
            Description = 'Advanced workflow and playbook execution'
            Category = 'Automation'
            MenuPriority = 35
        }
        'ISOManager' = @{
            Description = 'ISO file management and manipulation'
            Category = 'Utilities'
            MenuPriority = 60
        }
        'ISOCustomizer' = @{
            Description = 'ISO customization and modification'
            Category = 'Utilities'
            MenuPriority = 65
        }
        'SecureCredentials' = @{
            Description = 'Enterprise credential management'
            Category = 'Security'
            MenuPriority = 70
        }
        'RemoteConnection' = @{
            Description = 'Multi-protocol remote connection management'
            Category = 'Connectivity'
            MenuPriority = 80
        }
        'SystemMonitoring' = @{
            Description = 'System performance and health monitoring'
            Category = 'Operations'
            MenuPriority = 90
        }
        'AIToolsIntegration' = @{
            Description = 'AI development tools management (Claude, Gemini)'
            Category = 'Development'
            MenuPriority = 100
        }
        'ParallelExecution' = @{
            Description = 'Runspace-based parallel processing'
            Category = 'Performance'
            MenuPriority = 110
        }
        'TestingFramework' = @{
            Description = 'Pester-based testing integration'
            Category = 'Development'
            MenuPriority = 120
        }
        'Logging' = @{
            Description = 'Centralized logging system'
            Category = 'Core'
            MenuPriority = 200
            Hidden = $true  # Core module, not shown in menu
        }
        'ProgressTracking' = @{
            Description = 'Visual progress tracking for operations'
            Category = 'UI'
            MenuPriority = 130
        }
        'StartupExperience' = @{
            Description = 'Enhanced interactive UI with rich terminal experience'
            Category = 'UI'
            MenuPriority = 1
        }
    }
    
    # Get all module directories
    $modules = Get-ChildItem -Path $ModulesPath -Directory | Sort-Object Name
    
    foreach ($module in $modules) {
        $moduleManifest = Join-Path $module.FullName "$($module.Name).psd1"
        $moduleScript = Join-Path $module.FullName "$($module.Name).psm1"
        
        if (Test-Path $moduleManifest) {
            try {
                # Import module manifest to get metadata
                $manifest = Import-PowerShellDataFile -Path $moduleManifest -ErrorAction SilentlyContinue
                
                # Get module info from our descriptions or manifest
                $info = $moduleDescriptions[$module.Name]
                if (-not $info) {
                    $info = @{
                        Description = $manifest.Description ?? "Module: $($module.Name)"
                        Category = 'Other'
                        MenuPriority = 999
                    }
                }
                
                # Skip hidden modules
                if ($info.Hidden) { continue }
                
                # Get exported functions
                $exportedFunctions = @()
                if ($manifest.FunctionsToExport -and $manifest.FunctionsToExport -ne '*') {
                    $exportedFunctions = $manifest.FunctionsToExport
                } else {
                    # Try to get functions from module
                    try {
                        Import-Module $module.FullName -Force -ErrorAction SilentlyContinue
                        $loadedModule = Get-Module $module.Name
                        if ($loadedModule) {
                            $exportedFunctions = $loadedModule.ExportedFunctions.Keys | Sort-Object
                        }
                    } catch {
                        Write-Verbose "Could not load module $($module.Name): $_"
                    }
                }
                
                # Create module capability object
                $moduleCapability = [PSCustomObject]@{
                    Name = $module.Name
                    DisplayName = $module.Name -replace '([A-Z])', ' $1' -replace '^ ', ''
                    Description = $info.Description
                    Category = $info.Category
                    MenuPriority = $info.MenuPriority
                    Path = $module.FullName
                    Version = $manifest.ModuleVersion ?? '1.0'
                    Functions = $exportedFunctions
                    RequiredModules = $manifest.RequiredModules ?? @()
                    MinPowerShellVersion = $manifest.PowerShellVersion ?? '7.0'
                }
                
                $moduleInfo += $moduleCapability
                
            } catch {
                Write-Verbose "Error processing module $($module.Name): $_"
            }
        }
    }
    
    # Sort by category and priority
    return $moduleInfo | Sort-Object Category, MenuPriority, Name
}

# Function to get module quick actions
function Get-ModuleQuickActions {
    [CmdletBinding()]
    param(
        [string]$ModuleName
    )
    
    $quickActions = @{
        'StartupExperience' = @(
            @{
                Name = 'Launch Enhanced UI'
                Function = 'Start-InteractiveMode'
                Description = 'Start the enhanced interactive experience'
            }
            @{
                Name = 'Configuration Manager'
                Function = 'Show-ConfigurationManager'
                Description = 'Visual configuration editor'
            }
            @{
                Name = 'Module Explorer'
                Function = 'Show-ModuleExplorer'
                Description = 'Interactive module browser'
            }
        )
        'SetupWizard' = @(
            @{
                Name = 'Run Intelligent Setup'
                Function = 'Start-IntelligentSetup'
                Description = 'Complete first-time setup wizard'
            }
            @{
                Name = 'Generate Quick Start Guide'
                Function = 'Generate-QuickStartGuide'
                Description = 'Create platform-specific quick start guide'
            }
        )
        'ConfigurationCarousel' = @(
            @{
                Name = 'Switch Configuration'
                Function = 'Switch-ConfigurationSet'
                Description = 'Switch between configuration sets'
            }
            @{
                Name = 'List Configurations'
                Function = 'Get-AvailableConfigurations'
                Description = 'Show all available configurations'
            }
            @{
                Name = 'Edit Configuration'
                Function = 'Edit-Configuration'
                Description = 'Open configuration editor'
            }
        )
        'PatchManager' = @(
            @{
                Name = 'Create Patch'
                Function = 'Invoke-PatchWorkflow'
                Description = 'Create a new patch with Git workflow'
            }
            @{
                Name = 'Create Release'
                Function = 'Invoke-ReleaseWorkflow'
                Description = 'Create a new version release'
            }
            @{
                Name = 'Sync Repository'
                Function = 'Sync-GitBranch'
                Description = 'Sync local repository with remote'
            }
        )
        'BackupManager' = @(
            @{
                Name = 'Create Backup'
                Function = 'New-Backup'
                Description = 'Create a new backup'
            }
            @{
                Name = 'Restore Backup'
                Function = 'Restore-Backup'
                Description = 'Restore from a backup'
            }
            @{
                Name = 'List Backups'
                Function = 'Get-BackupList'
                Description = 'Show all available backups'
            }
        )
        'OpenTofuProvider' = @(
            @{
                Name = 'Initialize Infrastructure'
                Function = 'Initialize-Infrastructure'
                Description = 'Initialize OpenTofu/Terraform'
            }
            @{
                Name = 'Plan Changes'
                Function = 'Plan-Infrastructure'
                Description = 'Plan infrastructure changes'
            }
            @{
                Name = 'Apply Changes'
                Function = 'Apply-Infrastructure'
                Description = 'Apply infrastructure changes'
            }
        )
        'AIToolsIntegration' = @(
            @{
                Name = 'Install Claude Code'
                Function = 'Install-ClaudeCode'
                Description = 'Install Claude Code CLI'
            }
            @{
                Name = 'Install Gemini CLI'
                Function = 'Install-GeminiCLI'
                Description = 'Install Gemini CLI'
            }
            @{
                Name = 'Check AI Tools Status'
                Function = 'Get-AIToolsStatus'
                Description = 'Show status of all AI tools'
            }
        )
        'OrchestrationEngine' = @(
            @{
                Name = 'Run Playbook'
                Function = 'Invoke-PlaybookWorkflow'
                Description = 'Execute an orchestration playbook'
            }
            @{
                Name = 'List Playbooks'
                Function = 'Get-AvailablePlaybooks'
                Description = 'Show all available playbooks'
            }
            @{
                Name = 'Create Playbook'
                Function = 'New-PlaybookDefinition'
                Description = 'Create a new orchestration playbook'
            }
        )
    }
    
    return $quickActions[$ModuleName] ?? @()
}

# Export functions
Export-ModuleMember -Function Get-ModuleCapabilities, Get-ModuleQuickActions