@{
    RootModule = 'ConfigurationRepository.psm1'
    ModuleVersion = '2.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author = 'AitherZero Contributors'
    CompanyName = 'AitherZero'
    Copyright = '(c) 2025 AitherZero. All rights reserved.'
    Description = 'COMPATIBILITY SHIM: Backward compatibility module for ConfigurationRepository. This module has been consolidated into the new unified ConfigurationManager. Please migrate to the new ConfigurationManager module.'
    
    PowerShellVersion = '7.0'
    
    RequiredModules = @()
    
    FunctionsToExport = @(
        'New-ConfigurationRepository',
        'Clone-ConfigurationRepository',
        'Sync-ConfigurationRepository',
        'Validate-ConfigurationRepository'
    )
    
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    PrivateData = @{
        PSData = @{
            Tags = @('AitherZero', 'Configuration', 'Repository', 'Git', 'Management', 'Compatibility', 'Deprecated')
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