@{
    # Script module or binary module file associated with this manifest
    RootModule = 'AutomatedIssueManagement.psm1'
    
    # Version number of this module
    ModuleVersion = '1.0.0'
    
    # ID used to uniquely identify this module
    GUID = 'AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE'
    
    # Author of this module
    Author = 'AitherZero CI/CD System'
    
    # Company or vendor of this module
    CompanyName = 'AitherZero Project'
    
    # Copyright statement for this module
    Copyright = '(c) 2024 AitherZero Project. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'Comprehensive automated issue creation and management system for AitherZero CI/CD pipeline. Automatically creates GitHub issues for test failures, PSScriptAnalyzer violations, missing documentation, security issues, and all other CI/CD problems. Provides rich issue templates, duplicate prevention, lifecycle management, and integration with comprehensive dashboards.'
    
    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '7.0'
    
    # Functions to export from this module
    FunctionsToExport = @(
        'Initialize-AutomatedIssueManagement',
        'New-AutomatedIssueFromFailure',
        'New-PesterTestFailureIssues',
        'New-PSScriptAnalyzerIssues',
        'Get-SystemMetadata',
        'New-AutomatedIssueReport'
    )
    
    # Cmdlets to export from this module
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @()
    
    # List of all files packaged with this module
    FileList = @(
        'AutomatedIssueManagement.psm1',
        'AutomatedIssueManagement.psd1'
    )
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module
            Tags = @('CI', 'CD', 'Issues', 'Automation', 'GitHub', 'Testing', 'Quality', 'Monitoring', 'ULTRATHINK')
            
            # A URL to the license for this module
            LicenseUri = 'https://github.com/AitherZero/AitherZero/blob/main/LICENSE'
            
            # A URL to the main website for this project
            ProjectUri = 'https://github.com/AitherZero/AitherZero'
            
            # ReleaseNotes of this module
            ReleaseNotes = @'
v1.0.0 - Initial release - ULTRATHINK Automated Issue Management
- Comprehensive automated issue creation for ALL CI/CD failures
- Automated GitHub issue creation for test failures, PSScriptAnalyzer violations, missing documentation, security issues, and more
- Rich issue templates with full system context and metadata
- Intelligent duplicate issue prevention with signature-based detection
- Issue lifecycle management with automatic updates and resolution
- Integration with comprehensive dashboards and reporting
- System metadata collection for complete environmental context
- Support for Pester test failure analysis and grouping
- PSScriptAnalyzer violation processing with rule-based categorization
- Configurable issue creation limits and severity thresholds
- State tracking and analytics for issue creation patterns
- Multi-format reporting (JSON, HTML, Markdown) for comprehensive analysis
- GitHub API integration with proper authentication and rate limiting
- Template-based issue creation with customizable content and labeling
- Smart grouping of similar failures to prevent issue spam
- Complete CI/CD integration ready for all AitherZero workflows
'@
        }
    }
}