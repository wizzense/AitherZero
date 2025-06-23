@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'UnifiedMaintenance.psm1'
    
    # Version number of this module.
    ModuleVersion = '1.0.0'
    
    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')
    
    # ID used to uniquely identify this module
    GUID = 'f47b3c1e-8d2a-4a6b-9c3f-1e2d3c4b5a67'
    
    # Author of this module
    Author = 'OpenTofu Lab Automation Team'
    
    # Company or vendor of this module
    CompanyName = 'OpenTofu Lab Automation'
    
    # Copyright statement for this module
    Copyright = '(c) 2025 OpenTofu Lab Automation. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'Unified maintenance module for OpenTofu Lab Automation project with integrated testing, health monitoring, and PatchManager integration'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'
    
    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @()
    
    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry
    FunctionsToExport = @(
        'Invoke-UnifiedMaintenance',
        'Invoke-AutomatedTestWorkflow', 
        'Invoke-InfrastructureHealth',
        'Invoke-RecurringIssueTracking',
        'Start-ContinuousMonitoring'
    )
    
    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry
    AliasesToExport = @()
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('Maintenance', 'Testing', 'PatchManager', 'Automation', 'OpenTofu', 'Pester', 'pytest')
            
            # A URL to the license for this module.
            LicenseUri = ''
            
            # A URL to the main website for this project.
            ProjectUri = ''
            
            # A URL to an icon representing this module.
            IconUri = ''
            
            # ReleaseNotes of this module
            ReleaseNotes = 'Initial release of UnifiedMaintenance module with comprehensive testing and maintenance automation'
        }
    }
}
