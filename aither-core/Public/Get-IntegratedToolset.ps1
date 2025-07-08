#Requires -Version 7.0

<#
.SYNOPSIS
    Retrieves information about integrated tools and utilities available in the AitherZero platform.

.DESCRIPTION
    Provides a comprehensive inventory of integrated tools, modules, and utilities 
    available in the AitherZero platform, including their status, capabilities, and configuration.

.PARAMETER ToolCategory
    Filter tools by category (Development, Infrastructure, Automation, Security, etc.).

.PARAMETER IncludeStatus
    Include real-time status information for each tool.

.PARAMETER IncludeCapabilities
    Include detailed capability information for each tool.

.EXAMPLE
    Get-IntegratedToolset
    Returns all integrated tools and utilities.
    
.EXAMPLE
    Get-IntegratedToolset -ToolCategory Development -IncludeStatus
    Returns development tools with their current status.

.EXAMPLE
    Get-IntegratedToolset -IncludeCapabilities
    Returns all tools with detailed capability information.

.NOTES
    This function provides unified access to the AitherZero platform's integrated toolset.
#>

function Get-IntegratedToolset {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Development', 'Infrastructure', 'Automation', 'Security', 'Monitoring', 'AI', 'All')]
        [string]$ToolCategory = 'All',
        
        [Parameter()]
        [switch]$IncludeStatus,
        
        [Parameter()]
        [switch]$IncludeCapabilities
    )
    
    begin {
        Write-CustomLog -Message "Retrieving integrated toolset information..." -Level "INFO"
    }
    
    process {
        try {
            # Define integrated tools by category
            $integratedTools = @{
                Development = @(
                    @{
                        Name = "PatchManager"
                        Version = "3.0"
                        Description = "Advanced Git workflow automation with atomic operations"
                        Module = "PatchManager"
                        Capabilities = @("Git workflow", "PR automation", "Atomic operations", "Branch management")
                    },
                    @{
                        Name = "DevEnvironment"
                        Version = "2.1"
                        Description = "Development environment management and configuration"
                        Module = "DevEnvironment"
                        Capabilities = @("Environment setup", "Tool installation", "Configuration management")
                    },
                    @{
                        Name = "TestingFramework"
                        Version = "1.5"
                        Description = "Unified testing framework with Pester integration"
                        Module = "TestingFramework"
                        Capabilities = @("Unit testing", "Integration testing", "Test reporting")
                    },
                    @{
                        Name = "AIToolsIntegration"
                        Version = "1.0"
                        Description = "AI development tools management (Claude Code, Gemini, etc.)"
                        Module = "AIToolsIntegration"
                        Capabilities = @("AI tool installation", "Tool management", "Integration support")
                    }
                )
                
                Infrastructure = @(
                    @{
                        Name = "OpenTofuProvider"
                        Version = "2.0"
                        Description = "OpenTofu/Terraform infrastructure deployment"
                        Module = "OpenTofuProvider"
                        Capabilities = @("Infrastructure deployment", "State management", "Plan/Apply operations")
                    },
                    @{
                        Name = "LabRunner"
                        Version = "3.0"
                        Description = "Lab automation and infrastructure orchestration"
                        Module = "LabRunner"
                        Capabilities = @("Lab automation", "Script execution", "Infrastructure orchestration")
                    },
                    @{
                        Name = "ISOManager"
                        Version = "2.0"
                        Description = "ISO management and customization"
                        Module = "ISOManager"
                        Capabilities = @("ISO download", "ISO customization", "Autounattend generation")
                    }
                )
                
                Automation = @(
                    @{
                        Name = "OrchestrationEngine"
                        Version = "1.0"
                        Description = "Advanced workflow and playbook execution"
                        Module = "OrchestrationEngine"
                        Capabilities = @("Workflow execution", "Playbook management", "Conditional logic", "Parallel processing")
                    },
                    @{
                        Name = "ParallelExecution"
                        Version = "1.5"
                        Description = "Parallel task execution with runspace management"
                        Module = "ParallelExecution"
                        Capabilities = @("Parallel processing", "Runspace management", "Task scheduling")
                    },
                    @{
                        Name = "BackupManager"
                        Version = "1.8"
                        Description = "Backup and maintenance operations"
                        Module = "BackupManager"
                        Capabilities = @("File backup", "Maintenance automation", "Cleanup operations")
                    }
                )
                
                Security = @(
                    @{
                        Name = "SecureCredentials"
                        Version = "1.2"
                        Description = "Enterprise-grade credential management"
                        Module = "SecureCredentials"
                        Capabilities = @("Credential storage", "Encryption", "Access control")
                    },
                    @{
                        Name = "SecurityAutomation"
                        Version = "1.0"
                        Description = "Security automation and compliance"
                        Module = "SecurityAutomation"
                        Capabilities = @("Security automation", "Compliance checking", "Vulnerability assessment")
                    }
                )
                
                Monitoring = @(
                    @{
                        Name = "SystemMonitoring"
                        Version = "1.0"
                        Description = "System performance monitoring and alerting"
                        Module = "SystemMonitoring"
                        Capabilities = @("Performance monitoring", "Alerting", "Metrics collection")
                    },
                    @{
                        Name = "ProgressTracking"
                        Version = "2.0"
                        Description = "Visual progress tracking for long-running operations"
                        Module = "ProgressTracking"
                        Capabilities = @("Progress visualization", "ETA calculation", "Multi-operation tracking")
                    }
                )
                
                AI = @(
                    @{
                        Name = "Claude Code"
                        Version = "Latest"
                        Description = "Anthropic's Claude AI for development assistance"
                        Module = "AIToolsIntegration"
                        Capabilities = @("Code assistance", "Code review", "Documentation generation")
                    },
                    @{
                        Name = "Gemini CLI"
                        Version = "Latest"
                        Description = "Google's Gemini AI command-line interface"
                        Module = "AIToolsIntegration"
                        Capabilities = @("AI assistance", "Code generation", "Analysis")
                    }
                )
            }
            
            # Filter by category
            $toolsToReturn = @()
            if ($ToolCategory -eq 'All') {
                $integratedTools.Values | ForEach-Object { $toolsToReturn += $_ }
            } else {
                $toolsToReturn = $integratedTools[$ToolCategory]
            }
            
            # Enhance with status information if requested
            if ($IncludeStatus) {
                foreach ($tool in $toolsToReturn) {
                    $tool.Status = Get-ToolStatus -ToolName $tool.Name -ModuleName $tool.Module
                }
            }
            
            # Filter capabilities if not requested
            if (-not $IncludeCapabilities) {
                foreach ($tool in $toolsToReturn) {
                    $tool.Remove('Capabilities')
                }
            }
            
            Write-CustomLog -Message "Retrieved $($toolsToReturn.Count) integrated tools" -Level "SUCCESS"
            return $toolsToReturn
            
        } catch {
            Write-CustomLog -Message "Failed to retrieve integrated toolset: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}

# Helper function to get tool status
function Get-ToolStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolName,
        
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )
    
    process {
        try {
            # Check if module is available
            $module = Get-Module -Name $ModuleName -ListAvailable -ErrorAction SilentlyContinue
            if (-not $module) {
                return @{
                    Available = $false
                    Loaded = $false
                    Status = "Not Available"
                    LastChecked = Get-Date
                }
            }
            
            # Check if module is loaded
            $loadedModule = Get-Module -Name $ModuleName -ErrorAction SilentlyContinue
            $isLoaded = $null -ne $loadedModule
            
            return @{
                Available = $true
                Loaded = $isLoaded
                Status = if ($isLoaded) { "Loaded" } else { "Available" }
                Version = $module.Version.ToString()
                LastChecked = Get-Date
            }
            
        } catch {
            return @{
                Available = $false
                Loaded = $false
                Status = "Error: $($_.Exception.Message)"
                LastChecked = Get-Date
            }
        }
    }
}