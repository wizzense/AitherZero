@{
    RootModule = 'TestingFramework.psm1'
    ModuleVersion = '2.1.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author = 'AitherZero Contributors'
    CompanyName = 'Aitherium'
    Copyright = '(c) 2025 Aitherium. All rights reserved.'
    Description = 'Enhanced unified testing framework serving as central orchestrator for all testing activities with module integration, parallel execution, automated README.md updates, comprehensive reporting, and test generation capabilities'

    PowerShellVersion = '7.0'

    RequiredModules = @()

    FunctionsToExport = @(
        'Invoke-UnifiedTestExecution',
        'Get-DiscoveredModules',
        'New-TestExecutionPlan',
        'Get-TestConfiguration',
        'Invoke-ParallelTestExecution',
        'Invoke-SequentialTestExecution',
        'Invoke-ModuleTestPhase',
        'New-TestReport',
        'Export-VSCodeTestResults',
        'Submit-TestEvent',
        'Register-TestEventHandler',
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
        'Update-ReadmeTestStatus',
        'Start-TestSuite',
        'Write-TestLog',
        'New-ModuleTest',
        'Invoke-BulkTestGeneration',
        'Get-ModuleAnalysis',
        'Update-ReadmeTestStatus',
        'Invoke-AutomatedTestGeneration',
        'Start-TestExecutionMonitoring'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @(
        'Publish-TestEvent',
        'Subscribe-TestEvent'
    )

    PrivateData = @{
        PSData = @{
            Tags = @('Testing', 'Framework', 'Orchestrator', 'Parallel', 'Integration', 'VS Code', 'CI/CD', 'OpenTofu', 'Automation')
            LicenseUri = ''
            ProjectUri = ''
            IconUri = ''
            ReleaseNotes = 'Version 2.1.0 - Enhanced unified testing framework with automated README.md status updates, comprehensive test generation, performance monitoring, integration testing, and advanced reporting capabilities'
        }
    }
}
