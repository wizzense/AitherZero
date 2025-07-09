@{
    # Module manifest for SemanticVersioning
    RootModule = 'SemanticVersioning.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'b9f8c3d5-1e2f-4a6b-9c8d-7e4f2a5b8c9d'
    Author = 'AitherZero Development Team'
    CompanyName = 'AitherLabs'
    Copyright = '2025 AitherLabs. All rights reserved.'
    Description = 'Semantic versioning engine with conventional commit parsing and intelligent version management'

    PowerShellVersion = '7.0'

    RequiredModules = @()

    FunctionsToExport = @(
        'Get-NextSemanticVersion',
        'ConvertFrom-ConventionalCommits',
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
            Tags = @('SemanticVersioning', 'ConventionalCommits', 'Release', 'Automation', 'PowerShell')
            LicenseUri = 'https://github.com/AitherLabs/AitherZero/blob/main/LICENSE'
            ProjectUri = 'https://github.com/AitherLabs/AitherZero'
            ReleaseNotes = 'Semantic Versioning Engine v1.0.0 - Intelligent version management with conventional commits'
        }
    }
}
