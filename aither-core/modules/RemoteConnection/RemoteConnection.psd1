@{
    RootModule        = 'RemoteConnection.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '8C9F0A21-3D5E-6F7A-9B0C-2D3E4F5A6B7C'
    Author = 'AitherZero Contributors'
    CompanyName       = 'AitherZero'
    Copyright         = '(c) 2025 AitherZero. All rights reserved.'
    Description       = 'Generalized remote connection management module for enterprise-wide use across AitherZero infrastructure automation'
    PowerShellVersion = '7.0'
    RequiredModules   = @()
    FunctionsToExport = @(
        'New-RemoteConnection',
        'Get-RemoteConnection',
        'Remove-RemoteConnection',
        'Test-RemoteConnection',
        'Connect-RemoteEndpoint',
        'Disconnect-RemoteEndpoint',
        'Invoke-RemoteCommand',
        'Get-ConnectionPoolStatus',
        'Reset-ConnectionPool',
        'Get-ConnectionDiagnosticsReport'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags                     = @('RemoteConnection', 'SSH', 'WinRM', 'Enterprise', 'AitherZero')
            ProjectUri               = 'https://github.com/wizzense/AitherZero'
            RequireLicenseAcceptance = $false
        }
    }
}