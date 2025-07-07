@{
    # Module manifest for ScriptManager compatibility
    RootModule = 'ScriptManager.psm1'
    ModuleVersion = '2.0.0'
    GUID = 'f7e6d5c4-b3a2-9180-7654-321098fedcba'
    Author = 'AitherZero Contributors'
    CompanyName = 'AitherZero'
    Copyright = '(c) 2025 AitherZero. All rights reserved.'
    Description = 'COMPATIBILITY SHIM: Backward compatibility module for ScriptManager. This module has been consolidated into the new unified UtilityManager module. Please migrate to the new UtilityManager module.'
    PowerShellVersion = '7.0'
    
    RequiredModules = @()
    
    FunctionsToExport = @(
        'Get-ScriptRepository',
        'Get-ScriptTemplate',
        'Invoke-OneOffScript',
        'Start-ScriptExecution'
    )
    
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    PrivateData = @{
        PSData = @{
            Tags = @('Script', 'Management', 'Execution', 'Repository', 'AitherZero', 'Compatibility', 'Deprecated')
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