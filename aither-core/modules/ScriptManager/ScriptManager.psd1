@{
    RootModule = 'ScriptManager.psm1'
    ModuleVersion = '1.0.0'
    GUID = '453a5212-2be4-40bf-acf7-d53952b1981c'
    Author = 'Aitherium Contributors'
    CompanyName = 'Aitherium'
    Copyright = '(c) 2025 Aitherium. All rights reserved.'
    Description = 'Module for ScriptManager functionality in Aitherium Infrastructure Automation'

    PowerShellVersion = '7.0'

    FunctionsToExport = @(
        'Invoke-OneOffScript',
        'Get-ScriptRepository',
        'Start-ScriptExecution',
        'Get-ScriptTemplate'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()

    PrivateData = @{
        PSData = @{
            Tags = @('OpenTofu', 'Automation', 'ScriptManager')
            ProjectUri = ''
            LicenseUri = ''
            ReleaseNotes = 'Initial manifest creation by Fix-TestFailures.ps1'
        }
    }
}
