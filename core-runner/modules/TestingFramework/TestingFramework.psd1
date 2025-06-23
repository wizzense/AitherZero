@{
    RootModule = 'TestingFramework.psm1'
    ModuleVersion = '2.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author = 'OpenTofu Lab Automation Team'
    CompanyName = 'OpenTofu Lab Automation'
    Copyright = '(c) 2025 OpenTofu Lab Automation. All rights reserved.'
    Description = 'Enhanced unified testing framework serving as central orchestrator for all testing activities with module integration, parallel execution, and comprehensive reporting'

    PowerShellVersion = '7.0'

    RequiredModules = @()

    FunctionsToExport = @(
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
        'Invoke-PesterTests',
        'Invoke-PytestTests',
        'Invoke-SyntaxValidation',
        'Invoke-ParallelTests'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()

    PrivateData = @{
        PSData = @{
            Tags = @('Testing', 'Framework', 'Orchestrator', 'Parallel', 'Integration', 'VS Code', 'CI/CD', 'OpenTofu', 'Automation')
            LicenseUri = ''
            ProjectUri = ''
            IconUri = ''
            ReleaseNotes = 'Version 2.0.0 - Enhanced unified testing framework with module integration, parallel execution, comprehensive reporting, event system, and VS Code/GitHub Actions integration'
        }
    }
}
