@{
    RootModule = 'PSScriptAnalyzerIntegration.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'b7c8d9e0-f1a2-3b4c-5d6e-7f8901234567'
    Author = 'AitherZero Contributors'
    CompanyName = 'Aitherium'
    Copyright = '(c) 2025 Aitherium. All rights reserved.'
    Description = 'PSScriptAnalyzer integration module providing automated code quality analysis, directory-level auditing, bug tracking, and automated remediation workflows for the AitherZero PowerShell framework'

    PowerShellVersion = '7.0'

    RequiredModules = @('PSScriptAnalyzer')

    FunctionsToExport = @(
        # Core Analysis Functions
        'Start-DirectoryAudit',
        'Get-AnalysisStatus',
        'Invoke-PSScriptAnalyzerScan',
        'Get-PSScriptAnalyzerResults',
        
        # Status Management Functions
        'New-StatusFile',
        'Update-StatusFile',
        'Get-StatusSummary',
        'Export-StatusReport',
        
        # Bug Tracking Functions
        'New-BugzFile',
        'Update-BugzFile',
        'Get-BugzSummary',
        'Export-BugzReport',
        'Add-BugzEntry',
        'Remove-BugzEntry',
        'Set-BugzStatus',
        
        # GitHub Integration Functions
        'New-GitHubIssueFromFinding',
        'Get-GitHubIssuesForFindings',
        'Update-GitHubIssueStatus',
        'Close-ResolvedGitHubIssues',
        
        # Remediation Functions
        'Invoke-RemediationWorkflow',
        'Get-RemediationSuggestions',
        'Invoke-AutomaticFixes',
        'Test-RemediationSafety',
        
        # Configuration Functions
        'Get-PSScriptAnalyzerConfiguration',
        'Set-PSScriptAnalyzerConfiguration',
        'New-IgnoredException',
        'Remove-IgnoredException',
        'Get-IgnoredRules',
        
        # Reporting Functions
        'New-QualityReport',
        'Export-QualityDashboard',
        'Get-QualityMetrics',
        'Get-QualityTrends',
        
        # Integration Functions
        'Initialize-PSScriptAnalyzerIntegration',
        'Register-QualityProvider',
        'Invoke-QualityGates',
        'Test-QualityThresholds',
        
        # Utility Functions
        'Find-PowerShellFiles',
        'Get-DirectoryStructure',
        'Test-PSScriptAnalyzerAvailability',
        'Get-ModuleQualityScore'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()

    PrivateData = @{
        PSData = @{
            Tags = @('PSScriptAnalyzer', 'CodeQuality', 'Analysis', 'Auditing', 'BugTracking', 'Remediation', 'Security', 'Automation', 'CI/CD', 'Testing')
            LicenseUri = ''
            ProjectUri = ''
            IconUri = ''
            ReleaseNotes = 'Version 1.0.0 - Initial release with comprehensive PSScriptAnalyzer integration, directory-level auditing, bug tracking, and automated remediation workflows'
        }
    }
}