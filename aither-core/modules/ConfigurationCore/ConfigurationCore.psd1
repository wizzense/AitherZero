@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'ConfigurationCore.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Core')

    # ID used to uniquely identify this module
    GUID = 'f8a9b7c6-5d4e-3c2b-1a0f-9e8d7c6b5a4f'

    # Author of this module
    Author = 'AitherZero Team'

    # Company or vendor of this module
    CompanyName = 'AitherZero'

    # Copyright statement for this module
    Copyright = '(c) 2025 AitherZero. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Unified configuration management system for the AitherZero platform. Provides centralized configuration storage, validation, and environment-specific overlays.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Modules that must be imported into the global environment prior to importing this module
    # RequiredModules = @()
    # Note: Logging module is a core dependency and should be loaded by the main script, not as a circular dependency

    # Functions to export from this module
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
        
        # Utilities
        'Merge-Configuration',
        'Compare-Configuration',
        'Backup-Configuration',
        'Restore-Configuration'
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
            Tags = @('Configuration', 'Management', 'Settings', 'Environment', 'AitherZero')

            # A URL to the main website for this project
            ProjectUri = 'https://github.com/AitherLabs/AitherZero'

            # ReleaseNotes of this module
            ReleaseNotes = 'Initial release of ConfigurationCore - Unified configuration management for AitherZero platform'
        }
    }
}