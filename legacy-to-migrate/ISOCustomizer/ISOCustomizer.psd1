@{
    RootModule        = 'ISOCustomizer.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'A1B2C3D4-E5F6-7890-ABCD-EF1234567890'
    Author            = 'AitherZero Development Team'
    CompanyName       = 'AitherZero'
    Copyright         = '(c) 2025 AitherZero. All rights reserved.'
    Description       = 'Enterprise-grade ISO customization and autounattend file generation module for automated lab deployments'
    PowerShellVersion = '7.0'
    RequiredModules   = @()
    FunctionsToExport = @(
        'New-CustomISO',
        'New-AutounattendFile',
        'Get-AutounattendTemplate',
        'Get-BootstrapTemplate',
        'Get-KickstartTemplate'
    )
CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags                     = @('ISO', 'Customization', 'Autounattend', 'Windows', 'Deployment', 'AitherZero')
            ProjectUri               = 'https://github.com/wizzense/AitherZero'
            RequireLicenseAcceptance = $false
        }
    }
}