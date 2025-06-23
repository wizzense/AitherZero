@{
    # Module manifest for BackupManager
    RootModule = 'BackupManager.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'f8d7c6b5-4e3d-2c1b-0a9e-8f7e6d5c4b3a'
    Author = 'OpenTofu Lab Automation Team'
    CompanyName = 'OpenTofu Lab Automation'
    Copyright = '(c) 2025 OpenTofu Lab Automation Team. All rights reserved.'
    Description = 'Comprehensive backup management module for OpenTofu Lab Automation project'
    
    # Minimum version of the PowerShell engine required
    PowerShellVersion = '5.1'
    
    # Functions to export from this module
    FunctionsToExport = @(
        'Invoke-BackupConsolidation',
        'Invoke-PermanentCleanup',
        'New-BackupExclusion',
        'Get-BackupStatistics',
        'Invoke-BackupMaintenance'
    )
    
    # Cmdlets to export from this module
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @()
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            Tags = @('Backup', 'Maintenance', 'OpenTofu', 'Automation')
            LicenseUri = ''
            ProjectUri = ''
            IconUri = ''
            ReleaseNotes = 'Initial release of BackupManager module'
        }
    }
    
    # HelpInfo URI of this module
    HelpInfoURI = ''
    
    # Default prefix for commands exported from this module
    DefaultCommandPrefix = ''
}
