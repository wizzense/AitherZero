@{
    # Module manifest for LicenseManager module
    RootModule = 'LicenseManager.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'f1e2d3c4-b5a6-7890-abcd-ef1234567890'
    Author = 'AitherZero Contributors'
    CompanyName = 'AitherZero'
    Copyright = '(c) 2025 AitherZero. All rights reserved.'
    Description = 'License and feature management for AitherZero with tier-based access control'
    PowerShellVersion = '7.0'
    
    # Functions to export
    FunctionsToExport = @(
        'Get-LicenseStatus',
        'Set-License',
        'Test-FeatureAccess',
        'Get-AvailableFeatures',
        'Clear-License',
        'Get-FeatureTier',
        'Test-ModuleAccess',
        'Get-LicenseInfo'
    )
    
    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('License', 'Features', 'Access Control', 'Monetization')
            LicenseUri = 'https://github.com/wizzense/AitherZero/LICENSE'
            ProjectUri = 'https://github.com/wizzense/AitherZero'
            ReleaseNotes = 'Initial release of license management module'
            Licensing = @{
                Tier = 'free'
                Feature = 'core'
                RequiresLicense = $false
            }
        }
    }
    
    # Dependencies
    RequiredModules = @(
        @{ModuleName = 'Logging'; ModuleVersion = '2.0.0'; GUID = 'B5D8F9A1-C2E3-4F6A-8B9C-1D2E3F4A5B6C'}
    )
}