@{
    RootModule = 'OpenTofuProvider.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-78ab-9012-123456789abc'
    Author = 'Aitherium Infrastructure Automation'
    CompanyName = 'Aitherium'
    Copyright = '(c) 2025 Aitherium. All rights reserved.'
    Description = 'PowerShell module for secure OpenTofu infrastructure automation with Taliesins Hyper-V provider integration'

    PowerShellVersion = '7.0'
    RequiredModules = @(
        @{
            ModuleName = 'Logging'
            ModuleVersion = '2.0.0'
            GUID = 'B5D8F9A1-C2E3-4F6A-8B9C-1D2E3F4A5B6C'
        }
    )

    FunctionsToExport = @(
        'Install-OpenTofuSecure',
        'Initialize-OpenTofuProvider',
        'Test-OpenTofuSecurity',
        'New-LabInfrastructure',
        'Get-TaliesinsProviderConfig',
        'Set-SecureCredentials',
        'Test-InfrastructureCompliance',
        'Export-LabTemplate',
        'Import-LabConfiguration'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()

    PrivateData = @{
        PSData = @{
            Tags = @('OpenTofu', 'Terraform', 'Infrastructure', 'Security', 'HyperV', 'Automation')
            LicenseUri = ''
            ProjectUri = 'https://github.com/wizzense/opentofu-lab-automation'
            ReleaseNotes = 'Initial release with comprehensive security features and Taliesins integration'
        }
    }
}
