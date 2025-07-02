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
        'Get-StartupMode'
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
    RequiredModules = @(
        @{ModuleName = 'Logging'; ModuleVersion = '2.0.0'; GUID = 'B5D8F9A1-C2E3-4F6A-8B9C-1D2E3F4A5B6C'},
        @{ModuleName = 'LicenseManager'; ModuleVersion = '1.0.0'; GUID = 'f1e2d3c4-b5a6-7890-abcd-ef1234567890'}
    )
}