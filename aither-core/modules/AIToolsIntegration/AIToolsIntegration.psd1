@{
    RootModule = 'AIToolsIntegration.psm1'
    ModuleVersion = '1.0.0'
    GUID = '8a2b4c6d-1e3f-4a5b-8c9d-0e1f2a3b4c5d'
    Author = 'AitherZero Team'
    CompanyName = 'AitherZero'
    Copyright = '(c) 2025 AitherZero. All rights reserved.'
    Description = 'AI Tools Integration module for AitherZero - handles installation and configuration of AI development tools'
    
    PowerShellVersion = '7.0'
    
    RequiredModules = @()
    
    FunctionsToExport = @(
        'Install-ClaudeCode',
        'Install-GeminiCLI',
        'Install-CodexCLI',
        'Test-AIToolsInstallation',
        'Get-AIToolsStatus',
        'Configure-AITools',
        'Update-AITools',
        'Remove-AITools'
    )
    
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    PrivateData = @{
        PSData = @{
            Tags = @('AitherZero', 'AI', 'Tools', 'Claude', 'Gemini', 'Codex', 'Automation')
            ProjectUri = 'https://github.com/wizzense/AitherZero'
            ReleaseNotes = 'Initial release of AI Tools Integration module'
        }
    }
}