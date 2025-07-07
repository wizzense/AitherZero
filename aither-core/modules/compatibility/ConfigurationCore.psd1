@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'ConfigurationCore.psm1'

    # Version number of this module.
    ModuleVersion = '2.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Core')

    # ID used to uniquely identify this module
    GUID = 'f8a9b7c6-5d4e-3c2b-1a0f-9e8d7c6b5a4f'

    # Author of this module
    Author = 'AitherZero Contributors'

    # Company or vendor of this module
    CompanyName = 'AitherZero'

    # Copyright statement for this module
    Copyright = '(c) 2025 AitherZero. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'COMPATIBILITY SHIM: Backward compatibility module for ConfigurationCore. This module has been consolidated into the new unified configuration system. Please migrate to the new ConfigurationManager module.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Functions to export from this module (backward compatibility)
    FunctionsToExport = @(
        # Core Configuration Management
        'Initialize-ConfigurationCore',
        'Get-ModuleConfiguration',
        'Set-ModuleConfiguration',
        'Test-ModuleConfiguration',
        'Register-ModuleConfiguration',
        
        # Configuration Storage
        'Get-ConfigurationStore',
        'Set-ConfigurationStore',
        'Export-ConfigurationStore',
        'Import-ConfigurationStore',
        
        # Environment Management
        'Get-ConfigurationEnvironment',
        'Set-ConfigurationEnvironment',
        'New-ConfigurationEnvironment',
        'Remove-ConfigurationEnvironment',
        
        # Configuration Validation
        'Register-ConfigurationSchema',
        'Validate-Configuration',
        'Get-ConfigurationSchema',
        
        # Hot Reload
        'Enable-ConfigurationHotReload',
        'Disable-ConfigurationHotReload',
        'Get-ConfigurationWatcher',
        
        # Event System
        'Publish-ConfigurationEvent',
        'Subscribe-ConfigurationEvent',
        'Unsubscribe-ConfigurationEvent',
        'Get-ConfigurationEventHistory',
        
        # Utilities
        'Backup-Configuration',
        'Restore-Configuration',
        'Compare-Configuration'
    )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # Private data to pass to the module
    PrivateData = @{
        PSData = @{
            # Tags applied to this module
            Tags = @('Configuration', 'Management', 'Settings', 'Environment', 'AitherZero', 'Compatibility', 'Deprecated')

            # A URL to the main website for this project
            ProjectUri = 'https://github.com/AitherLabs/AitherZero'

            # ReleaseNotes of this module
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