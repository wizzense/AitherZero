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
        # From CLI Module (NEW - Primary Interface)
        'Invoke-AitherScript', 'Get-AitherScript', 'Invoke-AitherSequence',
        'Invoke-AitherPlaybook', 'Get-AitherPlaybook',
        'Get-AitherConfig', 'Set-AitherConfig', 'Switch-AitherEnvironment',
        'Get-AitherEnvironment', 'Set-AitherEnvironment', 'Set-AitherEnvVariable',
        'New-AitherDeploymentArtifact', 'New-AitherUnattendXml', 'New-AitherBrewfile',
        'Show-AitherDashboard', 'Get-AitherMetrics', 'Export-AitherMetrics',
        'Get-AitherPlatform', 'Test-AitherAdmin', 'Get-AitherVersion', 'Test-AitherCommand',
        'Write-AitherLog',

        # From EnvironmentConfig Module (NEW)
        'Get-EnvironmentConfiguration', 'Set-EnvironmentConfiguration',
        'Get-WindowsLongPathStatus', 'Enable-WindowsLongPathSupport',
        'Get-WindowsDeveloperModeStatus', 'Enable-WindowsDeveloperMode',
        'Update-EnvironmentVariable', 'Add-PathEntries', 'Add-ShellIntegration',

        # From DeploymentArtifacts Module (NEW)
        'New-WindowsUnattendXml', 'New-WindowsRegistryFile',
        'New-LinuxCloudInitConfig', 'New-LinuxShellScript',
        'New-MacOSBrewfile', 'New-Dockerfile', 'New-DeploymentArtifacts',

        # From Logging modules
        'Write-CustomLog', 'Write-ConfigLog', 'Write-TestingLog',
        'Write-InfraLog', 'Write-AuditLog', 'Enable-AuditLogging',

        # From Configuration
        'Import-ConfigDataFile', 'Get-Configuration', 'Set-Configuration', 'Get-ModuleConfiguration',
        'Get-MergedConfiguration',

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
        'Test-CIEnvironment', 'Export-OrchestrationResult',
        'Invoke-AitherWorkflow', 'Test-AitherAll', 'Invoke-AitherDeploy', 'Get-AitherConfig',

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

        # From ScriptUtilities (Automation helpers)
        'Get-ProjectRoot', 'Write-ScriptLog', 'Test-IsAdministrator', 'Get-PlatformName',
        'Test-CommandAvailable', 'Get-GitHubToken', 'Invoke-WithRetry', 'Test-GitRepository',
        'Get-ScriptMetadata', 'Format-Duration', 'Test-FeatureOrPrompt',

        # From Security modules
        'Invoke-SSHCommand', 'Test-SSHConnection', 'ConvertFrom-SecureStringSecurely',
        
        # From Encryption
        'Protect-String', 'Unprotect-String', 'Protect-File', 'Unprotect-File', 
        'New-EncryptionKey', 'Get-DataHash',
        
        # From LicenseManager
        'New-License', 'Test-License', 'Get-LicenseFromGitHub', 'Get-LicenseKey', 'Find-License',

        # Wildcard for any additional functions
        '*'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @('az', 'seq', 'az-script', 'az-playbook', 'az-config', 'az-dashboard', 'az-metrics',
                        'azw', 'aztest', 'azdeploy', 'azconfig')

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