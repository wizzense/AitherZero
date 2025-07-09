@{
    RootModule = 'UtilityServices.psm1'
    ModuleVersion = '1.0.0'
    GUID = '8a9b0c1d-2e3f-4a5b-6c7d-8e9f0a1b2c3d'
    Author = 'AitherZero Project'
    CompanyName = 'AitherZero'
    Copyright = '(c) AitherZero Project. All rights reserved.'
    Description = 'Utility services integration and testing module that provides comprehensive validation and testing for utility modules including SemanticVersioning, ProgressTracking, TestingFramework, and ScriptManager'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Test-UtilityIntegration',
        'Initialize-SemanticVersioningService',
        'Initialize-ProgressTrackingService', 
        'Initialize-TestingFrameworkService',
        'Initialize-ScriptManagerService',
        'Subscribe-UtilityEvent',
        'Publish-UtilityEvent',
        'Get-UtilityConfiguration',
        'Set-UtilityConfiguration',
        'Get-UtilityServiceStatus',
        'Get-UtilityMetrics',
        'Export-UtilityReport'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    RequiredModules = @(
        @{ModuleName = 'Logging'; ModuleVersion = '2.1.0'; GUID = 'B5D8F9A1-C2E3-4F6A-8B9C-1D2E3F4A5B6C'}
    )
    PrivateData = @{
        PSData = @{
            Tags = @('Utility', 'Services', 'Integration', 'Testing', 'Automation')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = 'Utility services integration testing module for AitherZero infrastructure automation'
        }
    }
}
