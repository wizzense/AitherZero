@{
    # Script module or binary module file associated with this manifest

    RootModule = 'Logging.psm1'
    
    # Version of this module
    ModuleVersion = '2.0.0'
    
    # ID used to uniquely identify this module
    GUID = 'B5D8F9A1-C2E3-4F6A-8B9C-1D2E3F4A5B6C'
    
    # Author of this module
    Author = 'OpenTofu Lab Automation Team'
    
    # Company or vendor of this module
    CompanyName = 'Wizzense'
    
    # Copyright statement for this module
    Copyright = '(c) 2025 Wizzense. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'Enterprise-grade centralized logging system for OpenTofu Lab Automation with full tracing, performance monitoring, and debugging capabilities.'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'
    
    # Functions to export from this module
    FunctionsToExport = @(
        'Write-CustomLog',
        'Initialize-LoggingSystem',
        'Start-PerformanceTrace',
        'Stop-PerformanceTrace',
        'Write-TraceLog',
        'Write-DebugContext',
        'Get-LoggingConfiguration',
        'Set-LoggingConfiguration'
    )
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @()
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module to aid discoverability
            Tags = @('Logging', 'Tracing', 'Debug', 'Performance', 'OpenTofu', 'Automation')
            
            # License URI for this module
            LicenseUri = ''
            
            # Project site URI for this module
            ProjectUri = ''
            
            # Release notes of this module
            ReleaseNotes = @'
Version 2.0.0
- Complete rewrite with enterprise-grade features
- Added structured logging with context support
- Added performance tracing capabilities
- Added call stack tracing for debugging
- Added configurable log levels and filtering
- Added log rotation and archiving
- Added multiple output formats (Simple, Structured, JSON)
- Added thread-safe operations
- Added comprehensive error handling
- Added environment variable configuration
- Added session tracking and initialization
- Cross-platform compatible
'@
        }
    }
}
