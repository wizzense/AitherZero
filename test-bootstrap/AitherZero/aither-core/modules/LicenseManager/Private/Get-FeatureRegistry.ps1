function Get-FeatureRegistry {
    <#
    .SYNOPSIS
        Loads the feature registry
    .DESCRIPTION
        Retrieves the feature registry configuration
    #>
    [CmdletBinding()]
    param()
    
    try {
        if ($script:FeatureRegistry) {
            return $script:FeatureRegistry
        }
        
        if (Test-Path $script:FeatureRegistryPath) {
            $script:FeatureRegistry = Get-Content $script:FeatureRegistryPath -Raw | ConvertFrom-Json
            return $script:FeatureRegistry
        }
        
        # Return default registry if file not found
        return @{
            tiers = @{
                free = @{
                    name = "Free Tier"
                    features = @('core', 'development')
                }
                pro = @{
                    name = "Professional"
                    features = @('core', 'development', 'infrastructure', 'ai', 'automation')
                }
                enterprise = @{
                    name = "Enterprise"
                    features = @('core', 'development', 'infrastructure', 'ai', 'automation', 'security', 'monitoring', 'enterprise')
                }
            }
            features = @{
                core = @{
                    tier = 'free'
                    modules = @('Logging', 'TestingFramework', 'ProgressTracking', 'StartupExperience', 'LicenseManager')
                }
                development = @{
                    tier = 'free'
                    modules = @('DevEnvironment', 'PatchManager', 'BackupManager')
                }
            }
            moduleOverrides = @{
                SetupWizard = @{
                    tier = 'free'
                    alwaysAvailable = $true
                }
            }
        }
        
    } catch {
        Write-Warning "Error loading feature registry: $_"
        throw
    }
}