@{
    RootModule = 'SecureCredentials.psm1'
    ModuleVersion = '1.0.0'
    GUID = '7B8E9F10-2C4D-5E6F-8A9B-1C2D3E4F5A6B'
    Author = 'AitherZero Development Team'
    CompanyName = 'AitherZero'
    Copyright = '(c) 2025 AitherZero. All rights reserved.'
    Description = 'Generalized secure credential management module for enterprise-wide use across AitherZero infrastructure automation'
    PowerShellVersion = '7.0'
    RequiredModules = @()
    FunctionsToExport = @(
        'New-SecureCredential',
        'Get-SecureCredential',
        'Remove-SecureCredential',
        'Test-SecureCredential',
        'Export-SecureCredential',
        'Import-SecureCredential'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Security', 'Credentials', 'Enterprise', 'AitherZero')
            ProjectUri = 'https://github.com/wizzense/AitherZero'
            RequireLicenseAcceptance = $false
        }
    }
}