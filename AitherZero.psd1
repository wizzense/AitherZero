@{
    ModuleVersion = '1.0.0.0'
    GUID = 'a7d4e8f1-2b3c-4d5e-6f7a-8b9c0d1e2f3a'
    Author = 'AitherZero Team'
    Description = 'AitherZero Automation Platform - Infrastructure automation with number-based orchestration'
    PowerShellVersion = '7.0'

    # Root module - main initialization script
    RootModule = 'AitherZero.psm1'

    # No NestedModules - we load them in the RootModule instead to ensure proper exports

    # Functions to export from all nested modules
    FunctionsToExport = @(
        # From RootModule (AitherZero.psm1)
        'Invoke-AitherScript',

        # From Logging modules
        'Write-CustomLog', 'Write-ConfigLog', 'Write-UILog', 'Write-TestingLog',
        'Write-InfraLog', 'Write-AuditLog', 'Enable-AuditLogging',

        # From Configuration
        'Get-Configuration', 'Set-Configuration', 'Get-ModuleConfiguration',

        # From BetterMenu
        'Show-BetterMenu',

        # From UserInterface
        'Show-UIMenu', 'Show-UIProgress', 'Show-UINotification', 'Show-UIWizard',
        'Initialize-AitherUI', 'Show-UIBorder', 'Write-UIText',

        # From CLIHelper (Modern CLI Features)
        'Show-ModernHelp', 'Show-CommandCard', 'Format-CLIOutput', 'Show-VersionInfo',
        'Show-CLICommand', 'Get-CLIEquivalent', 'Enable-CLILearningMode', 'Disable-CLILearningMode', 'Test-CLILearningMode',
        'Search-AitherZeroResources', 'Get-RecentActions', 'Add-RecentAction', 'Get-ScriptMetadata',
        'Invoke-QuickJump', 'Show-InlineHelp', 'Test-Prerequisites', 'Show-PrerequisiteStatus',
        'Get-ExecutionHistory', 'Add-ExecutionHistory', 'Show-ExecutionHistory',
        'Export-CommandHistory', 'Switch-AitherZeroProfile', 'Get-AitherZeroProfile',
        'Get-AllAutomationScripts', 'Get-AllPlaybooks',
        'Invoke-SmartSearchMenu', 'Invoke-RecentActionsMenu', 'Invoke-QuickJumpMenu',
        'Invoke-ProfileSwitcherMenu', 'Invoke-CommandExportMenu',

        # From InteractiveUI (Config-driven Interactive System)
        'Start-InteractiveUI', 'Show-MainMenu', 'Show-CategoryMenu',
        'Show-BrowseScriptsMenu', 'Show-BrowsePlaybooksMenu',
        'Invoke-ScriptWithChecks', 'Invoke-PlaybookWithChecks',

        # From GitAutomation
        'New-FeatureBranch', 'New-ConventionalCommit', 'Sync-GitRepository',

        # From TestingFramework (Legacy)
        'Invoke-BulletproofTest', 'New-TestReport', 'Show-TestTrends',

        # From AitherTestFramework (New)
        'Initialize-TestFramework', 'Register-TestSuite', 'Invoke-TestCategory', 'Clear-TestCache',

        # From ReportingEngine
        'New-ExecutionDashboard', 'Update-ExecutionDashboard', 'Export-MetricsReport',

        # From OrchestrationEngine
        'Invoke-OrchestrationSequence', 'Invoke-Sequence', 'Get-OrchestrationPlaybook',

        # From Infrastructure
        'Initialize-Infrastructure', 'Get-InfrastructureProvider',

        # From DocumentationEngine
        'Initialize-DocumentationEngine', 'New-ModuleDocumentation', 'New-ProjectDocumentation',
        'Test-DocumentationQuality', 'Get-DocumentationCoverage',

        # From ProjectIndexer
        'Initialize-ProjectIndexer', 'New-ProjectIndexes', 'New-DirectoryIndex',
        'Get-DirectoryContent', 'Test-ContentChanged', 'Get-IndexerConfig',

        # From QualityValidator
        'Test-ErrorHandling', 'Test-LoggingImplementation', 'Test-TestCoverage',
        'Test-UIIntegration', 'Test-GitHubActionsIntegration', 'Test-PSScriptAnalyzerCompliance',
        'Invoke-QualityValidation', 'Format-QualityReport',

        # Wildcard for any additional functions
        '*'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @('az', 'seq')

    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('Automation', 'Infrastructure', 'DevOps', 'OpenTofu', 'Terraform', 'Orchestration')
            ProjectUri = 'https://github.com/wizzense/AitherZero'
            LicenseUri = 'https://github.com/wizzense/AitherZero/blob/main/LICENSE'
            ReleaseNotes = 'Consolidated module loading system for improved reliability'
        }
    }
}