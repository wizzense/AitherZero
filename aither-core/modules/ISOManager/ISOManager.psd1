@{
    RootModule        = 'ISOManager.psm1'
    ModuleVersion     = '3.0.0'
    GUID              = '9F8E7D6C-5B4A-3928-1756-0E9D8C7B6A59'
    Author = 'AitherZero Contributors'
    CompanyName       = 'AitherZero'
    Copyright         = '(c) 2025 AitherZero. All rights reserved.'
    Description       = 'Comprehensive ISO management module combining download, organization, customization, and autounattend generation with advanced storage optimization and integrity validation for automated lab infrastructure deployment'
    PowerShellVersion = '7.0'
    RequiredModules   = @()
    FunctionsToExport = @(
        # ISO Download & Management
        'Get-ISODownload',
        'Get-ISOInventory',
        'Get-ISOMetadata',
        'Test-ISOIntegrity',
        'New-ISORepository',
        'Remove-ISOFile',
        'Export-ISOInventory',
        'Import-ISOInventory',
        'Sync-ISORepository',
        'Optimize-ISOStorage',

        # ISO Customization & Creation
        'New-CustomISO',
        'New-CustomISOWithProgress',
        'New-AutounattendFile',
        'New-AdvancedAutounattendFile'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags                     = @('ISO', 'Download', 'Management', 'Customization', 'Autounattend', 'Lab', 'Infrastructure', 'AitherZero')
            ProjectUri               = 'https://github.com/wizzense/AitherZero'
            RequireLicenseAcceptance = $false
        }
    }
}
