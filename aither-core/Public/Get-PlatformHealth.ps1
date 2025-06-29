#Requires -Version 7.0

<#
.SYNOPSIS
    Performs comprehensive health check of the AitherZero platform.

.DESCRIPTION
    Analyzes the health of all platform components including modules,
    configuration, communication systems, and generates recommendations.

.PARAMETER Quick
    Perform only essential health checks.

.EXAMPLE
    Get-PlatformHealth
    
.EXAMPLE
    Get-PlatformHealth -Quick

.NOTES
    Part of the unified platform API system.
#>

function Get-PlatformHealth {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Quick
    )
    
    process {
        try {
            $health = @{
                Overall = "Healthy"
                Score = 100
                Timestamp = Get-Date
                Checks = @{}
                Issues = @()
                Warnings = @()
                Recommendations = @()
                Categories = @{
                    Core = @{ Status = "Unknown"; Score = 0; Issues = @() }
                    Modules = @{ Status = "Unknown"; Score = 0; Issues = @() }
                    Configuration = @{ Status = "Unknown"; Score = 0; Issues = @() }
                    Communication = @{ Status = "Unknown"; Score = 0; Issues = @() }
                    Integration = @{ Status = "Unknown"; Score = 0; Issues = @() }
                }
            }
            
            # 1. Core system health
            Write-CustomLog -Message "Checking core system health..." -Level "DEBUG"
            try {
                $coreHealth = Test-CoreApplicationHealth
                $health.Checks["CoreApplicationHealth"] = $coreHealth
                
                if ($coreHealth) {
                    $health.Categories.Core.Status = "Healthy"
                    $health.Categories.Core.Score = 100
                } else {
                    $health.Categories.Core.Status = "Degraded"
                    $health.Categories.Core.Score = 50
                    $health.Categories.Core.Issues += "Core application health check failed"
                    $health.Issues += "Core application health check failed"
                    $health.Score -= 20
                }
            } catch {
                $health.Categories.Core.Status = "Critical"
                $health.Categories.Core.Score = 0
                $health.Categories.Core.Issues += "Core health check error: $($_.Exception.Message)"
                $health.Issues += "Core health check error: $($_.Exception.Message)"
                $health.Score -= 40
            }
            
            # 2. Required modules health
            Write-CustomLog -Message "Checking required modules..." -Level "DEBUG"
            $requiredModules = $script:CoreModules | Where-Object { $_.Required }
            $requiredLoaded = 0
            $moduleIssues = @()
            
            foreach ($module in $requiredModules) {
                $isLoaded = $script:LoadedModules.ContainsKey($module.Name)
                $health.Checks["Module_$($module.Name)"] = $isLoaded
                
                if ($isLoaded) {
                    $requiredLoaded++
                } else {
                    $moduleIssues += "Required module '$($module.Name)' is not loaded"
                    $health.Issues += "Required module '$($module.Name)' is not loaded"
                }
            }
            
            if ($requiredLoaded -eq $requiredModules.Count) {
                $health.Categories.Modules.Status = "Healthy"
                $health.Categories.Modules.Score = 100
            } elseif ($requiredLoaded -ge ($requiredModules.Count * 0.7)) {
                $health.Categories.Modules.Status = "Degraded"
                $health.Categories.Modules.Score = 70
                $health.Score -= 15
            } else {
                $health.Categories.Modules.Status = "Critical"
                $health.Categories.Modules.Score = 30
                $health.Score -= 30
            }
            
            $health.Categories.Modules.Issues = $moduleIssues
            
            # 3. Configuration system health
            Write-CustomLog -Message "Checking configuration system..." -Level "DEBUG"
            try {
                if (Get-Module ConfigurationCore -ErrorAction SilentlyContinue) {
                    $configHealth = Test-ConfigurationCore
                    $health.Checks["ConfigurationCore"] = $configHealth
                    
                    if ($configHealth) {
                        $health.Categories.Configuration.Status = "Healthy"
                        $health.Categories.Configuration.Score = 100
                    } else {
                        $health.Categories.Configuration.Status = "Degraded"
                        $health.Categories.Configuration.Score = 60
                        $health.Categories.Configuration.Issues += "Configuration system validation failed"
                        $health.Warnings += "Configuration system validation failed"
                        $health.Score -= 10
                    }
                } else {
                    $health.Categories.Configuration.Status = "Not Available"
                    $health.Categories.Configuration.Score = 0
                    $health.Categories.Configuration.Issues += "ConfigurationCore module not loaded"
                    $health.Warnings += "ConfigurationCore module not loaded - using basic configuration"
                    $health.Score -= 5
                }
            } catch {
                $health.Categories.Configuration.Status = "Error"
                $health.Categories.Configuration.Score = 0
                $health.Categories.Configuration.Issues += "Configuration health check error: $($_.Exception.Message)"
                $health.Issues += "Configuration health check error: $($_.Exception.Message)"
                $health.Score -= 15
            }
            
            # 4. Communication system health
            Write-CustomLog -Message "Checking communication system..." -Level "DEBUG"
            try {
                if (Get-Module ModuleCommunication -ErrorAction SilentlyContinue) {
                    $commHealth = Test-ModuleCommunication
                    $health.Checks["ModuleCommunication"] = $commHealth
                    
                    if ($commHealth) {
                        $health.Categories.Communication.Status = "Healthy"
                        $health.Categories.Communication.Score = 100
                    } else {
                        $health.Categories.Communication.Status = "Degraded"
                        $health.Categories.Communication.Score = 60
                        $health.Categories.Communication.Issues += "Module communication system validation failed"
                        $health.Warnings += "Module communication system validation failed"
                        $health.Score -= 10
                    }
                } else {
                    $health.Categories.Communication.Status = "Not Available"
                    $health.Categories.Communication.Score = 50
                    $health.Categories.Communication.Issues += "ModuleCommunication module not loaded"
                    $health.Warnings += "ModuleCommunication module not loaded - using basic event system"
                    $health.Score -= 5
                }
            } catch {
                $health.Categories.Communication.Status = "Error"
                $health.Categories.Communication.Score = 0
                $health.Categories.Communication.Issues += "Communication health check error: $($_.Exception.Message)"
                $health.Issues += "Communication health check error: $($_.Exception.Message)"
                $health.Score -= 15
            }
            
            # 5. Integration health (only if not Quick mode)
            if (-not $Quick) {
                Write-CustomLog -Message "Checking integration health..." -Level "DEBUG"
                $integrationScore = 0
                $integrationChecks = 0
                
                # Check key integrations
                $keyIntegrations = @{
                    "ConfigurationIntegration" = @('ConfigurationCore', 'ConfigurationCarousel')
                    "OrchestrationIntegration" = @('OrchestrationEngine', 'LabRunner')
                    "DevelopmentIntegration" = @('PatchManager', 'TestingFramework')
                    "ISOWorkflowIntegration" = @('ISOManager', 'ISOCustomizer')
                }
                
                foreach ($integration in $keyIntegrations.GetEnumerator()) {
                    $integrationChecks++
                    $allModulesLoaded = $true
                    
                    foreach ($moduleName in $integration.Value) {
                        if (-not $script:LoadedModules.ContainsKey($moduleName)) {
                            $allModulesLoaded = $false
                            break
                        }
                    }
                    
                    $health.Checks[$integration.Key] = $allModulesLoaded
                    if ($allModulesLoaded) {
                        $integrationScore += 25
                    }
                }
                
                $health.Categories.Integration.Score = $integrationScore
                if ($integrationScore -eq 100) {
                    $health.Categories.Integration.Status = "Optimal"
                } elseif ($integrationScore -ge 75) {
                    $health.Categories.Integration.Status = "Good"
                } elseif ($integrationScore -ge 50) {
                    $health.Categories.Integration.Status = "Partial"
                    $health.Categories.Integration.Issues += "Some module integrations not available"
                } else {
                    $health.Categories.Integration.Status = "Limited"
                    $health.Categories.Integration.Issues += "Most module integrations not available"
                }
            }
            
            # 6. Generate overall assessment
            if ($health.Score -ge 90) {
                $health.Overall = "Excellent"
            } elseif ($health.Score -ge 75) {
                $health.Overall = "Good"
            } elseif ($health.Score -ge 60) {
                $health.Overall = "Fair"
                $health.Recommendations += "Consider loading additional modules for better functionality"
            } elseif ($health.Score -ge 40) {
                $health.Overall = "Poor"
                $health.Recommendations += "Multiple issues detected - run 'Initialize-CoreApplication -Force'"
                $health.Recommendations += "Check module dependencies and paths"
            } else {
                $health.Overall = "Critical"
                $health.Recommendations += "Platform in critical state - immediate attention required"
                $health.Recommendations += "Reinstall or repair AitherZero platform"
            }
            
            # 7. General recommendations
            if ($health.Issues.Count -gt 0) {
                $health.Recommendations += "Run 'Initialize-CoreApplication -Force' to reload failed modules"
                $health.Recommendations += "Check logs for detailed error information"
            }
            
            if ($health.Categories.Modules.Score -lt 100) {
                $health.Recommendations += "Consider using 'Standard' or 'Full' profile for complete functionality"
            }
            
            return $health
            
        } catch {
            Write-CustomLog -Message "Failed to perform platform health check: $($_.Exception.Message)" -Level "ERROR"
            return @{
                Overall = "Error"
                Score = 0
                Timestamp = Get-Date
                Issues = @("Health check failed: $($_.Exception.Message)")
                Recommendations = @("Restart platform and try again", "Check system logs for errors")
            }
        }
    }
}