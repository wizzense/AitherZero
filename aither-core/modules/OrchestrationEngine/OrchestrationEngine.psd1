@{
    RootModule = 'OrchestrationEngine.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'c1d2e3f4-6a7b-8c9d-0e1f-2a3b4c5d6e7f'
    Author = 'AitherZero Team'
    CompanyName = 'AitherZero'
    Copyright = '(c) 2025 AitherZero. All rights reserved.'
    Description = 'Orchestration Engine for AitherZero - advanced workflow and playbook execution with conditional logic'
    
    PowerShellVersion = '7.0'
    
    RequiredModules = @()
    
    FunctionsToExport = @(
        'Invoke-PlaybookWorkflow',
        'New-PlaybookDefinition',
        'Import-PlaybookDefinition',
        'Export-PlaybookDefinition',
        'Get-PlaybookStatus',
        'Stop-PlaybookWorkflow',
        'Resume-PlaybookWorkflow',
        'Get-AvailablePlaybooks',
        'Validate-PlaybookDefinition',
        'New-ConditionalStep',
        'New-ParallelStep',
        'New-ScriptStep'
    )
    
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    PrivateData = @{
        PSData = @{
            Tags = @('AitherZero', 'Orchestration', 'Workflow', 'Playbook', 'Automation', 'Conditional')
            ProjectUri = 'https://github.com/wizzense/AitherZero'
            ReleaseNotes = 'Initial release of Orchestration Engine module'
        }
    }
}