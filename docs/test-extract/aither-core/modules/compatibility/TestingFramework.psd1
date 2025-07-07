@{
    # Module manifest for TestingFramework compatibility
    RootModule = 'TestingFramework.psm1'
    ModuleVersion = '2.0.0'
    GUID = 'a9f8e7d6-c5b4-3a29-1857-0e9d8c7b6a58'
    Author = 'AitherZero Contributors'
    CompanyName = 'AitherZero'
    Copyright = '(c) 2025 AitherZero. All rights reserved.'
    Description = 'COMPATIBILITY SHIM: Backward compatibility module for TestingFramework. This module has been consolidated into the new unified UtilityManager module. Please migrate to the new UtilityManager module.'
    PowerShellVersion = '7.0'
    
    RequiredModules = @()
    
    FunctionsToExport = @(
        'Invoke-TestSuite',
        'New-TestCase',
        'Assert-Equal',
        'Assert-True',
        'Assert-False',
        'Assert-Null',
        'Assert-NotNull',
        'Assert-Throws',
        'Get-TestResults',
        'Export-TestResults'
    )
    
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    PrivateData = @{
        PSData = @{
            Tags = @('Testing', 'Framework', 'UnitTest', 'Validation', 'AitherZero', 'Compatibility', 'Deprecated')
            ProjectUri = 'https://github.com/AitherLabs/AitherZero'
            ReleaseNotes = @'
v2.0.0 - COMPATIBILITY SHIM RELEASE:
- This module has been consolidated into the new unified UtilityManager
- All functions are preserved with deprecation warnings
- Automatic forwarding to the new UtilityManager module
- Migration guide available in module documentation
- DEPRECATED: Please migrate to UtilityManager module for future compatibility
'@
        }
    }
}