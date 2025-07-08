@{
    RootModule = 'ConfigurationManager.psm1'
    ModuleVersion = '1.0.0'
    GUID = '7e8a9b2c-4d5e-6f7a-8b9c-0d1e2f3a4b5c'
    Author = 'AitherZero Project'
    CompanyName = 'AitherZero'
    Copyright = '(c) AitherZero Project. All rights reserved.'
    Description = 'Unified configuration management module that consolidates all configuration subsystems including ConfigurationCore, ConfigurationCarousel, and ConfigurationRepository'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Test-ConfigurationManager'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    RequiredModules = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Configuration', 'Management', 'Infrastructure', 'Automation')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = 'Consolidated configuration management module for AitherZero infrastructure automation'
        }
    }
}
