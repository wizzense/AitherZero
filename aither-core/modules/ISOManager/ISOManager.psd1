@{
    RootModule        = 'ISOManager.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '9F8E7D6C-5B4A-3928-1756-0E9D8C7B6A59'
    Author            = 'AitherZero Development Team'
    CompanyName       = 'AitherZero'
    Copyright         = '(c) 2025 AitherZero. All rights reserved.'
    Description       = 'Enterprise-grade ISO download, management, and organization module for automated lab infrastructure deployment'
    PowerShellVersion = '7.0'
    RequiredModules   = @()
    FunctionsToExport = @(
        'Get-ISODownload',
        'Get-ISOInventory',
        'Get-ISOMetadata',
        'Test-ISOIntegrity',
        'New-ISORepository',
        'Remove-ISOFile',
        'Export-ISOInventory',
        'Import-ISOInventory',
        'Sync-ISORepository'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags                     = @('ISO', 'Download', 'Management', 'Lab', 'Infrastructure', 'AitherZero')
            ProjectUri               = 'https://github.com/wizzense/AitherZero'
            RequireLicenseAcceptance = $false
        }
    }
}