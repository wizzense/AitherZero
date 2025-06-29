@{
    RootModule = 'ConfigurationRepository.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-5e6f-7a8b-9c0d-1e2f3a4b5c6d'
    Author = 'AitherZero Team'
    CompanyName = 'AitherZero'
    Copyright = '(c) 2025 AitherZero. All rights reserved.'
    Description = 'Configuration Repository Manager for AitherZero - handles Git-based configuration management'
    
    PowerShellVersion = '7.0'
    
    RequiredModules = @()
    
    FunctionsToExport = @(
        'New-ConfigurationRepository',
        'Clone-ConfigurationRepository',
        'Sync-ConfigurationRepository',
        'Validate-ConfigurationRepository',
        'Publish-ConfigurationRepository',
        'Fork-ConfigurationRepository',
        'Get-ConfigurationRepositoryInfo',
        'Set-ConfigurationRepositorySettings',
        'Backup-ConfigurationRepository',
        'Restore-ConfigurationRepository'
    )
    
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    PrivateData = @{
        PSData = @{
            Tags = @('AitherZero', 'Configuration', 'Git', 'Repository', 'Management')
            ProjectUri = 'https://github.com/wizzense/AitherZero'
            ReleaseNotes = 'Initial release of Configuration Repository Manager module'
        }
    }
}