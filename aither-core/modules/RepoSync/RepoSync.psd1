@{
    RootModule = 'RepoSync.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'e3b6c8a9-4d2f-4a1e-8c7b-9f3e2d1a0b5c'
    Author = 'AitherZero Team'
    CompanyName = 'Aitherium'
    Copyright = '(c) 2025 Aitherium. All rights reserved.'
    Description = 'Repository synchronization module for managing bidirectional sync between repositories'
    PowerShellVersion = '7.0'
    
    FunctionsToExport = @(
        'Sync-ToAitherLab',
        'Sync-FromAitherLab', 
        'Get-SyncStatus'
    )
    
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    RequiredModules = @()
    
    PrivateData = @{
        PSData = @{
            Tags = @('Git', 'Sync', 'Repository', 'AitherZero')
            ProjectUri = 'https://github.com/yourusername/AitherZero'
            ReleaseNotes = 'Initial release of RepoSync module'
        }
    }
}
