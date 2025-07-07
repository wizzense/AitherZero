@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'ConfigurationManager.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Core')

    # ID used to uniquely identify this module
    GUID = 'c4d5e6f7-8a9b-0c1d-2e3f-4a5b6c7d8e9f'

    # Author of this module
    Author = 'AitherZero Contributors'

    # Company or vendor of this module
    CompanyName = 'AitherZero'

    # Copyright statement for this module
    Copyright = '(c) 2025 AitherZero. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Unified Configuration Management System for AitherZero - Consolidates ConfigurationCore, ConfigurationCarousel, and ConfigurationRepository functionality into a single powerful module.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Functions to export from this module
    FunctionsToExport = @(
        # Core Configuration Management (from ConfigurationCore)
        'Initialize-ConfigurationCore',
        'Get-ModuleConfiguration',
        'Set-ModuleConfiguration',
        'Test-ModuleConfiguration',
        'Register-ModuleConfiguration',
        
        # Configuration Storage (from ConfigurationCore)
        'Get-ConfigurationStore',
        'Set-ConfigurationStore',
        'Export-ConfigurationStore',
        'Import-ConfigurationStore',
        
        # Environment Management (from ConfigurationCore)
        'Get-ConfigurationEnvironment',
        'Set-ConfigurationEnvironment',
        'New-ConfigurationEnvironment',
        'Remove-ConfigurationEnvironment',
        
        # Configuration Validation (from ConfigurationCore)
        'Get-ConfigurationSchema',
        'Register-ConfigurationSchema',
        'Validate-Configuration',
        
        # Hot Reload (from ConfigurationCore)
        'Enable-ConfigurationHotReload',
        'Disable-ConfigurationHotReload',
        'Get-ConfigurationWatcher',
        
        # Event System (from ConfigurationCore)
        'Publish-ConfigurationEvent',
        'Subscribe-ConfigurationEvent',
        'Unsubscribe-ConfigurationEvent',
        'Get-ConfigurationEventHistory',
        
        # Utilities (from ConfigurationCore)
        'Backup-Configuration',
        'Restore-Configuration',
        'Compare-Configuration',
        
        # Configuration Carousel (from ConfigurationCarousel)
        'Switch-ConfigurationSet',
        'Get-AvailableConfigurations',
        'Add-ConfigurationRepository',
        'Remove-ConfigurationRepository',
        'Get-CurrentConfiguration',
        'Backup-CurrentConfiguration',
        'Restore-ConfigurationBackup',
        'Validate-ConfigurationSet',
        'Export-ConfigurationSet',
        'Import-ConfigurationSet',
        
        # Configuration Repository (from ConfigurationRepository)
        'New-ConfigurationRepository',
        'Clone-ConfigurationRepository',
        'Sync-ConfigurationRepository',
        'Validate-ConfigurationRepository',
        'Publish-ConfigurationRepository',
        'Fork-ConfigurationRepository',
        'Get-ConfigurationRepositoryInfo',
        'Set-ConfigurationRepositorySettings',
        'Backup-ConfigurationRepository',
        'Restore-ConfigurationRepository',
        
        # New Unified Functions
        'Initialize-ConfigurationManager',
        'Get-ConfigurationManagerStatus',
        'Reset-ConfigurationManager',
        'Update-ConfigurationManager',
        'Test-ConfigurationManager',
        
        # Migration Functions
        'Import-LegacyConfiguration',
        'Export-UnifiedConfiguration',
        'Convert-ConfigurationFormat'
    )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @(
        # Backward compatibility aliases
        'Get-ConfigCarouselRegistry',
        'Set-ConfigCarouselRegistry',
        'Initialize-ConfigCarousel',
        'Apply-ConfigurationSet',
        'Test-ConfigurationAccessible',
        'Validate-ConfigurationPath',
        'Test-EnvironmentCompatibility',
        'New-ConfigurationFromTemplate',
        'Create-ConfigurationTemplate',
        'Create-RemoteRepository',
        'Setup-LocalRepositorySettings'
    )

    # Private data to pass to the module
    PrivateData = @{
        PSData = @{
            # Tags applied to this module
            Tags = @('Configuration', 'Management', 'Settings', 'Environment', 'Repository', 'Carousel', 'AitherZero')

            # A URL to the main website for this project
            ProjectUri = 'https://github.com/AitherLabs/AitherZero'

            # ReleaseNotes of this module
            ReleaseNotes = @'
v1.0.0 - Initial unified release:
- Consolidated ConfigurationCore, ConfigurationCarousel, and ConfigurationRepository modules
- Unified configuration management with single point of entry
- Backward compatibility maintained for all existing functions
- Enhanced error handling and validation
- Comprehensive documentation and examples
- Cross-platform support (Windows, Linux, macOS)
- Modern PowerShell 7+ patterns and practices
- Enterprise-grade security and compliance features
- Git-based configuration repository management
- Multi-environment configuration switching
- Hot reload and real-time configuration updates
- Event-driven architecture with pub/sub messaging
- Comprehensive test suite with 100+ test cases
'@
        }
    }
}