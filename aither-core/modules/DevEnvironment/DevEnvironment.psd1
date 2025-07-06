#
# Module manifest for DevEnvironment
#

@{
    RootModule = 'DevEnvironment.psm1'
    ModuleVersion = '1.0.0'
    GUID = '12345678-1234-1234-1234-123456789012'
    Author = 'AitherZero Contributors'
    CompanyName = 'Aitherium'
    Copyright = '(c) 2025 Aitherium. All rights reserved.'
    Description = 'Development environment setup and management for Aitherium Infrastructure Automation'

    PowerShellVersion = '7.0'
      FunctionsToExport = @(
        # Core Environment Functions
        'Initialize-DevEnvironment',
        'Initialize-DevelopmentEnvironment',
        'Get-DevEnvironmentStatus',
        'Test-DevEnvironment',
        'Resolve-ModuleImportIssues',
        'Optimize-PlatformEnvironment',
        
        # VS Code Integration
        'Initialize-VSCodeWorkspace',
        'Update-VSCodeSettings',
        'Install-VSCodeExtensions',
        'New-VSCodeWorkspaceFile',
        'Test-VSCodeIntegration',
        
        # AI Tools Dependencies
        'Install-ClaudeCodeDependencies',
        'Install-GeminiCLIDependencies',
        'Install-CodexCLIDependencies',
        'Install-ClaudeRequirementsSystem',
        'Test-ClaudeRequirementsSystem',
        
        # Git Integration
        'Install-PreCommitHook',
        'Remove-PreCommitHook',
        'Test-PreCommitHook',
        
        # Legacy Support
        'Set-DevelopmentEnvironment',
        'Test-DevelopmentSetup',
        'Remove-ProjectEmojis',
        'Set-PatchManagerAliases'
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