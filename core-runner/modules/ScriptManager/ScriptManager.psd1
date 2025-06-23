@{
    RootModule = 'ScriptManager.psm1'
    ModuleVersion = '1.0.0'
    GUID = '453a5212-2be4-40bf-acf7-d53952b1981c'
    Author = 'OpenTofu Lab Automation Team'
    CompanyName = 'OpenTofu Lab Automation'
    Copyright = '(c) 2025 OpenTofu Lab Automation. All rights reserved.'
    Description = 'Module for ScriptManager functionality in OpenTofu Lab Automation'
    
    PowerShellVersion = '7.0'
    
    FunctionsToExport = @(
        'Invoke-OneOffScript',
        'Register-OneOffScript',
        'Test-OneOffScript'
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
