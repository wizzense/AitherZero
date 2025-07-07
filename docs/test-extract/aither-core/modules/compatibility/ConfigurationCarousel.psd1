@{
    RootModule = 'ConfigurationCarousel.psm1'
    ModuleVersion = '2.0.0'
    GUID = '9b3c5d7e-2f4a-5b6c-9d0e-1f2a3b4c5d6e'
    Author = 'AitherZero Contributors'
    CompanyName = 'AitherZero'
    Copyright = '(c) 2025 AitherZero. All rights reserved.'
    Description = 'COMPATIBILITY SHIM: Backward compatibility module for ConfigurationCarousel. This module has been consolidated into the new unified ConfigurationManager. Please migrate to the new ConfigurationManager module.'
    
    PowerShellVersion = '7.0'
    
    RequiredModules = @()
    
    FunctionsToExport = @(
        'Switch-ConfigurationSet',
        'Get-AvailableConfigurations',
        'Add-ConfigurationRepository',
        'Remove-ConfigurationRepository',
        'Sync-ConfigurationRepository',
        'Get-CurrentConfiguration',
        'Backup-CurrentConfiguration',
        'Restore-ConfigurationBackup',
        'Validate-ConfigurationSet',
        'Export-ConfigurationSet',
        'Import-ConfigurationSet',
        'New-ConfigurationEnvironment',
        'Set-ConfigurationEnvironment'
    )
    
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    PrivateData = @{
        PSData = @{
            Tags = @('AitherZero', 'Configuration', 'Environment', 'Management', 'Carousel', 'Compatibility', 'Deprecated')
            ProjectUri = 'https://github.com/wizzense/AitherZero'
            ReleaseNotes = @'
v2.0.0 - COMPATIBILITY SHIM RELEASE:
- This module has been consolidated into the new unified ConfigurationManager
- All functions are preserved with deprecation warnings
- Automatic forwarding to the new ConfigurationManager module
- Migration guide available in module documentation
- DEPRECATED: Please migrate to ConfigurationManager module for future compatibility
'@
        }
    }
}