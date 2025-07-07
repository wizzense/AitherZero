@{
    # Module manifest for StartupExperience compatibility module
    RootModule = 'StartupExperience.psm1'
    ModuleVersion = '2.0.0'
    GUID = 'e4f5d6c7-b8a9-4321-9876-543210fedcba'
    Author = 'AitherZero Contributors'
    CompanyName = 'AitherZero'
    Copyright = '(c) 2025 AitherZero. All rights reserved.'
    Description = 'COMPATIBILITY SHIM: Backward compatibility module for StartupExperience. This module has been consolidated into the new unified SetupManager module. Please migrate to the new SetupManager module.'
    PowerShellVersion = '7.0'
    
    # Functions to export (backward compatibility)
    FunctionsToExport = @(
        'Start-InteractiveMode',
        'Show-ConfigurationManager',
        'Get-ModuleDiscovery',
        'New-ConfigurationProfile',
        'Sync-ConfigurationToGitHub',
        'Get-ConfigurationProfile',
        'Set-ConfigurationProfile',
        'Remove-ConfigurationProfile',
        'Export-ConfigurationProfile',
        'Import-ConfigurationProfile',
        'Show-ModuleExplorer',
        'Get-StartupMode',
        'Clear-ModuleDiscoveryCache',
        'Test-StartupPerformance',
        'Get-UIStatus',
        'Show-UIDebugInfo'
    )
    
    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('Configuration', 'Interactive', 'UI', 'Startup', 'Terminal', 'Compatibility', 'Deprecated')
            LicenseUri = 'https://github.com/wizzense/AitherZero/LICENSE'
            ProjectUri = 'https://github.com/wizzense/AitherZero'
            ReleaseNotes = @'
v2.0.0 - COMPATIBILITY SHIM RELEASE:
- This module has been consolidated into the new unified SetupManager
- All functions are preserved with deprecation warnings
- Automatic forwarding to the new SetupManager module
- Migration guide available in module documentation
- DEPRECATED: Please migrate to SetupManager module for future compatibility
'@
            Licensing = @{
                Tier = 'free'
                Feature = 'core'
                RequiresLicense = $false
            }
        }
    }
    
    # Dependencies
    # RequiredModules = @()
    # Note: Logging and LicenseManager are optional dependencies that will be loaded if available
}