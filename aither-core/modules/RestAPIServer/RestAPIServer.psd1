@{
    # Module metadata
    RootModule = 'RestAPIServer.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'f7e8d9c0-1234-5678-9abc-def012345678'
    Author = 'AitherZero Contributors'
    CompanyName = 'AitherZero'
    Copyright = '(c) 2025 AitherZero. All rights reserved.'
    Description = 'REST API server for AitherZero external system integration and automation'
    
    # PowerShell version compatibility
    PowerShellVersion = '7.0'
    
    # Required modules
    RequiredModules = @()
    
    # Functions to export
    FunctionsToExport = @(
        'Start-AitherZeroAPI',
        'Stop-AitherZeroAPI',
        'Get-APIStatus',
        'Register-APIEndpoint',
        'Unregister-APIEndpoint',
        'Get-APIEndpoints',
        'Set-APIConfiguration',
        'Get-APIConfiguration',
        'Test-APIConnection',
        'Export-APIDocumentation',
        'Enable-APIWebhooks',
        'Disable-APIWebhooks',
        'Send-WebhookNotification',
        'Get-WebhookSubscriptions',
        'Add-WebhookSubscription',
        'Remove-WebhookSubscription'
    )
    
    # Cmdlets to export
    CmdletsToExport = @()
    
    # Variables to export
    VariablesToExport = @()
    
    # Aliases to export
    AliasesToExport = @()
    
    # File extensions
    FileList = @()
    
    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('REST', 'API', 'Integration', 'Webhooks', 'Automation', 'AitherZero')
            LicenseUri = ''
            ProjectUri = ''
            IconUri = ''
            ReleaseNotes = 'Initial release of REST API server for AitherZero external integrations'
        }
    }
}