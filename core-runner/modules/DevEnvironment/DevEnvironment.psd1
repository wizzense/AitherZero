#
# Module manifest for DevEnvironment
#

@{
    RootModule = 'DevEnvironment.psm1'
    ModuleVersion = '1.0.0'
    GUID = '12345678-1234-1234-1234-123456789012'
    Author = 'OpenTofu Lab Automation Team'
    CompanyName = 'Wizzense'
    Copyright = '(c) 2025 Wizzense. All rights reserved.'
    Description = 'Development environment setup and management for OpenTofu Lab Automation'
    
    PowerShellVersion = '7.0'
      FunctionsToExport = @(
        'Install-PreCommitHook',
        'Remove-PreCommitHook', 
        'Test-PreCommitHook',
        'Set-DevelopmentEnvironment',
        'Test-DevelopmentSetup',
        'Remove-ProjectEmojis',
        'Initialize-DevelopmentEnvironment',
        'Resolve-ModuleImportIssues'
    )
    
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    RequiredModules = @(
        'Logging'
    )
    
    PrivateData = @{
        PSData = @{
            Tags = @('Development', 'Git', 'Hooks', 'Environment')
            ProjectUri = 'https://github.com/wizzense/opentofu-lab-automation'
            ReleaseNotes = 'Initial release of DevEnvironment module'
        }
    }
}
