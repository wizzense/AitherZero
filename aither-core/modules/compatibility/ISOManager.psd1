@{
    RootModule        = 'ISOManager.psm1'
    ModuleVersion     = '3.0.0'
    GUID              = '9F8E7D6C-5B4A-3928-1756-0E9D8C7B6A59'
    Author = 'AitherZero Contributors'
    CompanyName       = 'AitherZero'
    Copyright         = '(c) 2025 AitherZero. All rights reserved.'
    Description       = 'COMPATIBILITY SHIM: Backward compatibility module for ISOManager. This module has been consolidated into the new unified ISOManagement module. Please migrate to the new ISOManagement module.'
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
        'Sync-ISORepository',
        'Optimize-ISOStorage'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags                     = @('ISO', 'Download', 'Management', 'Lab', 'Infrastructure', 'AitherZero', 'Compatibility', 'Deprecated')
            ProjectUri               = 'https://github.com/wizzense/AitherZero'
            RequireLicenseAcceptance = $false
            ReleaseNotes = @'
v3.0.0 - COMPATIBILITY SHIM RELEASE:
- This module has been consolidated into the new unified ISOManagement
- All functions are preserved with deprecation warnings
- Automatic forwarding to the new ISOManagement module
- Migration guide available in module documentation
- DEPRECATED: Please migrate to ISOManagement module for future compatibility
'@
        }
    }
}