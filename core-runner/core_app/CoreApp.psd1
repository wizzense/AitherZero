@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'CoreApp.psm1'
    
    # Version number of this module.
    ModuleVersion     = '1.0.0'
    
    # ID used to uniquely identify this module
    GUID              = 'a1b2c3d4-e5f6-7890-1234-567890abcdef'
    
    # Author of this module
    Author            = 'wizzense'
    
    # Company or vendor of this module
    CompanyName       = 'wizzense'
    
    # Copyright statement for this module
    Copyright         = '(c) 2025 Wizzense. All rights reserved.'
      # Description of the functionality provided by this module
    Description       = 'Parent orchestration module for OpenTofu Lab Automation - manages all modules and provides unified interface'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'
    
    # Functions to export from this module
    FunctionsToExport = @(
        'Invoke-CoreApplication',
        'Start-LabRunner',
        'Get-CoreConfiguration',
        'Test-CoreApplicationHealth',
        'Write-CustomLog',
        'Get-PlatformInfo',
        'Initialize-CoreApplication',
        'Import-CoreModules',
        'Get-CoreModuleStatus',
        'Invoke-UnifiedMaintenance',
        'Start-DevEnvironmentSetup'
    )
    
    # Cmdlets to export from this module
    CmdletsToExport   = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport   = @()
    
    # List of all modules packaged with this module
    ModuleList        = @()
      # List of all files packaged with this module
    FileList          = @('CoreApp.psm1', 'default-config.json')
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData       = @{
        PSData = @{
            # Tags applied to this module
            Tags         = @('OpenTofu', 'Terraform', 'Lab', 'Automation', 'Infrastructure')
            
            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/wizzense/opentofu-lab-automation/LICENSE'
            
            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/wizzense/opentofu-lab-automation'
            
            # A URL to an icon representing this module.
            IconUri      = ''
            
            # Release notes for this module
            ReleaseNotes = 'Initial release - consolidates lab utilities, runner scripts, and configuration'
        }
    }
}
