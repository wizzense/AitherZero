@{
    RootModule = 'ConfigurationCarousel.psm1'
    ModuleVersion = '1.0.0'
    GUID = '9b3c5d7e-2f4a-5b6c-9d0e-1f2a3b4c5d6e'
    Author = 'AitherZero Contributors'
    CompanyName = 'AitherZero'
    Copyright = '(c) 2025 AitherZero. All rights reserved.'
    Description = 'Configuration Carousel module for AitherZero - manages multiple configuration sets and environments'

    PowerShellVersion = '7.0'

    RequiredModules = @()

    FunctionsToExport = @(
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
        'New-ConfigurationEnvironment',
        'Set-ConfigurationEnvironment'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()

    PrivateData = @{
        PSData = @{
            Tags = @('AitherZero', 'Configuration', 'Environment', 'Management', 'Carousel')
            ProjectUri = 'https://github.com/wizzense/AitherZero'
            ReleaseNotes = 'Initial release of Configuration Carousel module'
        }
    }
}
