@{
    # Module manifest for SemanticVersioning compatibility
    RootModule = 'SemanticVersioning.psm1'
    ModuleVersion = '2.0.0'
    GUID = 'b9f8c3d5-1e2f-4a6b-9c8d-7e4f2a5b8c9d'
    Author = 'AitherZero Development Team'
    CompanyName = 'AitherLabs'
    Copyright = '2025 AitherLabs. All rights reserved.'
    Description = 'COMPATIBILITY SHIM: Backward compatibility module for SemanticVersioning. This module has been consolidated into the new unified UtilityManager module. Please migrate to the new UtilityManager module.'
    
    PowerShellVersion = '7.0'
    
    RequiredModules = @()
    
    FunctionsToExport = @(
        'Get-NextSemanticVersion',
        'Parse-ConventionalCommits',
        'Get-CommitTypeImpact',
        'New-VersionTag',
        'Get-VersionHistory',
        'Update-ProjectVersion',
        'Get-ReleaseNotes',
        'Test-SemanticVersion',
        'Compare-SemanticVersions',
        'Get-VersionBump'
    )
    
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    PrivateData = @{
        PSData = @{
            Tags = @('SemanticVersioning', 'ConventionalCommits', 'Release', 'Automation', 'PowerShell', 'Compatibility', 'Deprecated')
            LicenseUri = 'https://github.com/AitherLabs/AitherZero/blob/main/LICENSE'
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