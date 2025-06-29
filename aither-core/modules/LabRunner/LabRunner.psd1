@{
    RootModule = 'LabRunner.psm1'
    ModuleVersion = '0.1.0'
    GUID = 'c0000000-0000-4000-8000-000000000001'
    Author = 'Aitherium Contributors'
    Description = 'LabRunner module for Aitherium Infrastructure Automation'

    FunctionsToExport = @(
        'Invoke-LabStep',
        'Invoke-LabDownload',
        'Read-LoggedInput',
        'Invoke-LabWebRequest',
        'Write-CustomLog',
        'Invoke-OpenTofuInstaller',
        'Get-Platform',
        'Invoke-ArchiveDownload',
        'Invoke-LabNpm',
        'Expand-All',
        'Resolve-ProjectPath',
        'Get-GhDownloadArgs',
        'Get-LabConfig',
        'Invoke-ParallelLabRunner',
        'Test-ParallelRunnerSupport',
        'Initialize-StandardParameters',
        'Start-LabAutomation',
        'Get-LabStatus'
    )

    NestedModules = @('Resolve-ProjectPath.psm1')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}