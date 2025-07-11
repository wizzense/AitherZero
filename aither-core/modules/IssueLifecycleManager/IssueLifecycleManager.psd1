@{
    # Module manifest for IssueLifecycleManager
    RootModule = 'IssueLifecycleManager.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a8b7c6d5-4e3f-2a1b-9c8d-7e6f5a4b3c2d'
    Author = 'AitherZero Team'
    CompanyName = 'AitherLabs'
    Copyright = '(c) 2025 AitherLabs. All rights reserved.'
    Description = 'Automated GitHub issue lifecycle management with complete audit trail and reporting'
    PowerShellVersion = '7.0'
    
    # Functions to export
    FunctionsToExport = @(
        # Issue Management
        'New-AutomatedIssue',
        'Update-IssueStatus',
        'Close-ResolvedIssue',
        'Get-IssueMetrics',
        'Set-IssueAssignment',
        'Add-IssueDependency',
        'Get-IssueDependencies',
        
        # Lifecycle Automation
        'Start-IssueLifecycleMonitor',
        'Stop-IssueLifecycleMonitor',
        'Get-IssueLifecycleStatus',
        'Invoke-IssueResolutionCheck',
        'Update-IssueFromValidation',
        
        # Reporting
        'Get-IssueResolutionReport',
        'Export-IssueMetrics',
        'Get-IssueAuditTrail',
        'New-IssueLifecycleDashboard',
        
        # Configuration
        'Set-IssueLifecycleConfig',
        'Get-IssueLifecycleConfig',
        'Test-IssueLifecycleHealth'
    )
    
    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('GitHub', 'Issues', 'Automation', 'Lifecycle', 'AitherZero')
            LicenseUri = 'https://github.com/AitherLabs/AitherZero/blob/main/LICENSE'
            ProjectUri = 'https://github.com/AitherLabs/AitherZero'
            ReleaseNotes = 'Initial release of automated issue lifecycle management'
        }
    }
    
    # Required modules
    RequiredModules = @(
        @{ModuleName = 'Logging'; ModuleVersion = '1.0.0'},
        @{ModuleName = 'PSScriptAnalyzerIntegration'; ModuleVersion = '1.0.0'}
    )
}