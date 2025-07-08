@{
    # Module manifest for StartupExperience module
    RootModule = 'StartupExperience.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'e4f5d6c7-b8a9-4321-9876-543210fedcba'
    Author = 'AitherZero Contributors'
    CompanyName = 'AitherZero'
    Copyright = '(c) 2025 AitherZero. All rights reserved.'
    Description = 'Enhanced startup experience with interactive configuration management, module discovery, and rich terminal UI'
    PowerShellVersion = '7.0'

    # Functions to export
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
            Tags = @('Configuration', 'Interactive', 'UI', 'Startup', 'Terminal')
            LicenseUri = 'https://github.com/wizzense/AitherZero/LICENSE'
            ProjectUri = 'https://github.com/wizzense/AitherZero'
            ReleaseNotes = 'Initial release of enhanced startup experience module'
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
