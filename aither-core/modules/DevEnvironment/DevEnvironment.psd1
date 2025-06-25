#
# Module manifest for DevEnvironment
#

@{
    RootModule = 'DevEnvironment.psm1'
    ModuleVersion = '1.0.0'
    GUID = '12345678-1234-1234-1234-123456789012'
    Author = 'Aitherium Contributors'
    CompanyName = 'Aitherium'
    Copyright = '(c) 2025 Aitherium. All rights reserved.'
    Description = 'Development environment setup and management for Aitherium Infrastructure Automation'

    PowerShellVersion = '7.0'
      FunctionsToExport = @(
        'Install-PreCommitHook',
        'Remove-PreCommitHook',
        'Test-PreCommitHook',
        'Set-DevelopmentEnvironment',
        'Test-DevelopmentSetup',
        'Remove-ProjectEmojis',
        'Initialize-DevelopmentEnvironment',
        'Resolve-ModuleImportIssues',
        'Initialize-DevEnvironment',
        'Test-DevEnvironment',
        'Get-DevEnvironmentStatus'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
      RequiredModules = @()

    PrivateData = @{
        PSData = @{
            Tags = @('Development', 'Git', 'Hooks', 'Environment')
            ProjectUri = 'https://github.com/Aitherium/AitherLabs'
            ReleaseNotes = 'Initial release of DevEnvironment module'
        }
    }
}
