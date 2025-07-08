@{
    # Script module or binary module file associated with this manifest

    RootModule = 'Logging.psm1'

    # Version of this module
    ModuleVersion = '2.1.0'

    # ID used to uniquely identify this module
    GUID = 'B5D8F9A1-C2E3-4F6A-8B9C-1D2E3F4A5B6C'

    # Author of this module
    Author = 'AitherZero Contributors'

    # Company or vendor of this module
    CompanyName = 'Aitherium'

    # Copyright statement for this module
    Copyright = '(c) 2025 Aitherium. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Enterprise-grade centralized logging system for Aitherium Infrastructure Automation with full tracing, performance monitoring, and debugging capabilities.'

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
        'Set-LoggingConfiguration',
        'Write-BulkLog',
        'Test-LoggingPerformance',
        'Import-ProjectModule'
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
Version 2.1.0
- PowerShell 7+ modernization with null-coalescing operators
- Modern environment variable naming (AITHER_*) with LAB_* fallback
- Enhanced exception logging with inner exception chains
- Improved file I/O performance with thread-safe operations
- Added Write-BulkLog for efficient batch logging
- Added Test-LoggingPerformance for performance monitoring
- Performance tracking enabled by default for better insights
- Enhanced Import-ProjectModule with automatic path resolution
- Optimized mutex-based file locking for concurrent scenarios
- Improved error handling with structured error details

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
