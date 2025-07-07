@{
    # Module manifest for UtilityServices - Unified Utility Services Platform
    RootModule = 'UtilityServices.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'f7a8b9c0-1d2e-3f4a-5b6c-7d8e9f0a1b2c'
    Author = 'AitherZero Development Team'
    CompanyName = 'AitherLabs'
    Copyright = '2025 AitherLabs. All rights reserved.'
    Description = 'Unified utility services platform providing semantic versioning, progress tracking, testing orchestration, and script management with integrated APIs and shared patterns'
    
    PowerShellVersion = '7.0'
    
    RequiredModules = @()
    
    # Unified function exports consolidating all utility services
    FunctionsToExport = @(
        # === SEMANTIC VERSIONING SERVICES ===
        'Get-NextSemanticVersion',
        'Parse-ConventionalCommits', 
        'Get-CommitTypeImpact',
        'New-VersionTag',
        'Get-VersionHistory',
        'Update-ProjectVersion',
        'Get-ReleaseNotes',
        'Test-SemanticVersion',
        'Compare-SemanticVersions',
        'Get-VersionBump',
        
        # === PROGRESS TRACKING SERVICES ===
        'Start-ProgressOperation',
        'Update-ProgressOperation', 
        'Complete-ProgressOperation',
        'Get-ProgressStatus',
        'Stop-ProgressOperation',
        'Add-ProgressWarning',
        'Add-ProgressError',
        'Start-MultiProgress',
        'Update-MultiProgress',
        'Complete-MultiProgress',
        'Show-ProgressSummary',
        'Get-ProgressHistory',
        'Clear-ProgressHistory',
        'Export-ProgressReport',
        'Test-ProgressOperationActive',
        
        # === TESTING FRAMEWORK SERVICES ===
        'Invoke-UnifiedTestExecution',
        'Get-DiscoveredModules',
        'New-TestExecutionPlan',
        'Get-TestConfiguration', 
        'Invoke-ParallelTestExecution',
        'Invoke-SequentialTestExecution',
        'New-TestReport',
        'Export-VSCodeTestResults',
        'Publish-TestEvent',
        'Subscribe-TestEvent',
        'Get-TestEvents',
        'Register-TestProvider',
        'Get-RegisteredTestProviders',
        'Invoke-SimpleTestRunner',
        'Test-ModuleStructure',
        'Initialize-TestEnvironment',
        'Import-ProjectModule',
        'Invoke-PesterTests',
        'Invoke-PytestTests',
        'Invoke-SyntaxValidation',
        'Invoke-ParallelTests',
        'Invoke-BulletproofTest',
        'Start-TestSuite',
        'Write-TestLog',
        'New-ModuleTest',
        'Invoke-BulkTestGeneration',
        'Get-ModuleAnalysis',
        
        # === SCRIPT MANAGEMENT SERVICES ===
        'Register-OneOffScript',
        'Invoke-OneOffScript', 
        'Get-ScriptRepository',
        'Start-ScriptExecution',
        'Get-ScriptTemplate',
        'Test-OneOffScript',
        
        # === INTEGRATED UTILITY SERVICES ===
        'Start-IntegratedOperation',
        'New-VersionedTestSuite',
        'Invoke-ProgressAwareExecution',
        'Get-UtilityServiceStatus',
        'Start-UtilityDashboard',
        'Export-UtilityReport',
        'Initialize-UtilityServices',
        'Test-UtilityIntegration',
        'Get-UtilityMetrics',
        'Reset-UtilityServices',
        
        # === CONFIGURATION AND EVENT MANAGEMENT ===
        'Get-UtilityConfiguration',
        'Set-UtilityConfiguration',
        'Reset-UtilityConfiguration',
        'Get-UtilityEvents',
        'Clear-UtilityEvents',
        'Publish-UtilityEvent',
        'Subscribe-UtilityEvent'
    )
    
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    PrivateData = @{
        PSData = @{
            Tags = @('Utilities', 'SemanticVersioning', 'ProgressTracking', 'Testing', 'ScriptManagement', 'Integration', 'Automation', 'PowerShell', 'AitherZero')
            LicenseUri = 'https://github.com/AitherLabs/AitherZero/blob/main/LICENSE'
            ProjectUri = 'https://github.com/AitherLabs/AitherZero'
            ReleaseNotes = 'UtilityServices v1.0.0 - Unified utility services platform consolidating SemanticVersioning, ProgressTracking, TestingFramework, and ScriptManager with integrated APIs and shared patterns'
        }
    }
}