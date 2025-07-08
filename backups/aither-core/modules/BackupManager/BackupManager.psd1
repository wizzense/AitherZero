@{
    RootModule = 'BackupManager.psm1'
    ModuleVersion = '2.0.0'
    GUID = 'a8f1b2c3-d4e5-f6a7-b8c9-d0e1f2a3b4c5'
    Author = 'AitherZero Project'
    CompanyName = 'AitherZero'
    Copyright = '(c) 2024 AitherZero Project. All rights reserved.'
    Description = 'Comprehensive backup management and maintenance capabilities for the AitherZero project'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Get-BackupStatistics',
        'Invoke-BackupMaintenance',
        'Invoke-PermanentCleanup',
        'Invoke-BackupConsolidation',
        'New-BackupExclusion',
        'Invoke-AdvancedBackup',
        'Restore-BackupData',
        'Start-AutomatedBackup'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    RequiredModules = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Backup', 'Maintenance', 'FileManagement', 'AitherZero')
            ProjectUri = ''
            ReleaseNotes = 'Initial release of BackupManager module'
        }
    }
}
