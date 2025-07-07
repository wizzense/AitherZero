@{
    RootModule        = 'ISOCustomizer.psm1'
    ModuleVersion     = '2.0.0'
    GUID              = 'A1B2C3D4-E5F6-7890-ABCD-EF1234567890'
    Author = 'AitherZero Contributors'
    CompanyName       = 'AitherZero'
    Copyright         = '(c) 2025 AitherZero. All rights reserved.'
    Description       = 'COMPATIBILITY SHIM: Backward compatibility module for ISOCustomizer. This module has been consolidated into the new unified ISOManagement module. Please migrate to the new ISOManagement module.'
    PowerShellVersion = '7.0'
    RequiredModules   = @()
    FunctionsToExport = @(
        'New-CustomISO',
        'New-CustomISOWithProgress',
        'New-AutounattendFile',
        'New-AdvancedAutounattendFile',
        'Test-ISOIntegrity',
        'Get-AutounattendTemplate',
        'Get-BootstrapTemplate',
        'Get-KickstartTemplate'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags                     = @('ISO', 'Customization', 'Autounattend', 'Windows', 'Deployment', 'AitherZero', 'Compatibility', 'Deprecated')
            ProjectUri               = 'https://github.com/wizzense/AitherZero'
            RequireLicenseAcceptance = $false
            ReleaseNotes = @'
v2.0.0 - COMPATIBILITY SHIM RELEASE:
- This module has been consolidated into the new unified ISOManagement
- All functions are preserved with deprecation warnings
- Automatic forwarding to the new ISOManagement module
- Migration guide available in module documentation
- DEPRECATED: Please migrate to ISOManagement module for future compatibility
'@
        }
    }
}