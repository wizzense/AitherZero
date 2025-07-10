function Get-SetupSteps {
    <#
    .SYNOPSIS
        Get setup steps for a specific installation profile
    .DESCRIPTION
        Returns the step definitions and metadata for the specified installation profile
    .PARAMETER Profile
        Installation profile (minimal, developer, full, custom)
    .PARAMETER CustomProfile
        Custom profile definition for advanced scenarios
    .EXAMPLE
        $stepsInfo = Get-SetupSteps -Profile 'developer'
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('minimal', 'developer', 'full', 'custom')]
        [string]$Profile = 'minimal',
        [hashtable]$CustomProfile = @{}
    )

    try {
        # Define base steps that run for all profiles
        $baseSteps = @(
            @{Name = 'Platform Detection'; Function = 'Test-PlatformRequirements'; AllProfiles = $true; Required = $true},
            @{Name = 'PowerShell Version'; Function = 'Test-PowerShellVersion'; AllProfiles = $true; Required = $true},
            @{Name = 'Git Installation'; Function = 'Test-GitInstallation'; AllProfiles = $true; Required = $false},
            @{Name = 'Infrastructure Tools'; Function = 'Test-InfrastructureTools'; AllProfiles = $true; Required = $false},
            @{Name = 'Module Dependencies'; Function = 'Test-ModuleDependencies'; AllProfiles = $true; Required = $true}
        )

        # Enhanced profile definitions with metadata
        $profileDefinitions = @{
            'minimal' = @{
                Name = 'Minimal'
                Description = 'Core AitherZero functionality only'
                TargetUse = @('CI/CD', 'Containers', 'Basic Infrastructure')
                EstimatedTime = '2-3 minutes'
                Steps = @(
                    @{Name = 'Network Connectivity'; Function = 'Test-NetworkConnectivity'; Required = $false},
                    @{Name = 'Security Settings'; Function = 'Test-SecuritySettings'; Required = $false},
                    @{Name = 'Configuration Files'; Function = 'Initialize-Configuration'; Required = $true},
                    @{Name = 'Configuration Review'; Function = 'Review-Configuration'; Required = $false},
                    @{Name = 'Quick Start Guide'; Function = 'Generate-QuickStartGuide'; Required = $false},
                    @{Name = 'Final Validation'; Function = 'Test-SetupCompletion'; Required = $true}
                )
            }
            'developer' = @{
                Name = 'Developer'
                Description = 'Development workstation setup with AI tools'
                TargetUse = @('Development', 'AI Tools', 'VS Code Integration')
                EstimatedTime = '5-8 minutes'
                Steps = @(
                    @{Name = 'Network Connectivity'; Function = 'Test-NetworkConnectivity'; Required = $false},
                    @{Name = 'Node.js Detection'; Function = 'Test-NodeJsInstallation'; Required = $false},
                    @{Name = 'AI Tools Setup'; Function = 'Install-AITools'; Required = $false},
                    @{Name = 'Development Environment'; Function = 'Test-DevEnvironment'; Required = $false},
                    @{Name = 'Security Settings'; Function = 'Test-SecuritySettings'; Required = $false},
                    @{Name = 'Configuration Files'; Function = 'Initialize-Configuration'; Required = $true},
                    @{Name = 'Configuration Review'; Function = 'Review-Configuration'; Required = $false},
                    @{Name = 'Quick Start Guide'; Function = 'Generate-QuickStartGuide'; Required = $false},
                    @{Name = 'Final Validation'; Function = 'Test-SetupCompletion'; Required = $true}
                )
            }
            'full' = @{
                Name = 'Full'
                Description = 'Complete installation with all features'
                TargetUse = @('Production', 'Enterprise', 'Complete Infrastructure')
                EstimatedTime = '8-12 minutes'
                Steps = @(
                    @{Name = 'Network Connectivity'; Function = 'Test-NetworkConnectivity'; Required = $false},
                    @{Name = 'Node.js Detection'; Function = 'Test-NodeJsInstallation'; Required = $false},
                    @{Name = 'AI Tools Setup'; Function = 'Install-AITools'; Required = $false},
                    @{Name = 'Cloud CLIs Detection'; Function = 'Test-CloudCLIs'; Required = $false},
                    @{Name = 'Development Environment'; Function = 'Test-DevEnvironment'; Required = $false},
                    @{Name = 'Security Settings'; Function = 'Test-SecuritySettings'; Required = $false},
                    @{Name = 'License Management'; Function = 'Test-LicenseIntegration'; Required = $false},
                    @{Name = 'Module Communication'; Function = 'Test-ModuleCommunication'; Required = $false},
                    @{Name = 'Configuration Files'; Function = 'Initialize-Configuration'; Required = $true},
                    @{Name = 'Configuration Review'; Function = 'Review-Configuration'; Required = $false},
                    @{Name = 'Quick Start Guide'; Function = 'Generate-QuickStartGuide'; Required = $false},
                    @{Name = 'Final Validation'; Function = 'Test-SetupCompletion'; Required = $true}
                )
            }
            'custom' = @{
                Name = 'Custom'
                Description = 'User-defined custom profile'
                TargetUse = @('Customized Setup')
                EstimatedTime = 'Variable'
                Steps = $CustomProfile.Steps ?? @()
            }
        }

        # Handle custom profile
        if ($CustomProfile.Count -gt 0) {
            $Profile = 'custom'
            $profileDefinitions['custom'] = $CustomProfile
        }

        # Get the profile definition
        $profileDef = $profileDefinitions[$Profile]
        if (-not $profileDef) {
            Write-Warning "Unknown profile '$Profile', falling back to minimal"
            $profileDef = $profileDefinitions['minimal']
        }

        # Combine base steps with profile-specific steps and deduplicate by name
        $combinedSteps = $baseSteps + $profileDef.Steps
        $allSteps = @($combinedSteps | Group-Object Name | ForEach-Object { $_.Group[0] })

        return @{
            Steps = $allSteps
            Profile = $profileDef
            EstimatedSteps = $allSteps.Count
        }

    } catch {
        Write-Error "Failed to get setup steps for profile '$Profile': $_"
        return @{
            Steps = @()
            Profile = @{Name = 'Error'; Description = 'Failed to load profile'}
            EstimatedSteps = 0
        }
    }
}

Export-ModuleMember -Function Get-SetupSteps