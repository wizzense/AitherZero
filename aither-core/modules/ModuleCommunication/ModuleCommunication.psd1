@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'ModuleCommunication.psm1'

    # Version number of this module.
    ModuleVersion = '2.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Core')

    # ID used to uniquely identify this module
    GUID = 'a2b3c4d5-e6f7-8901-bcde-f23456789012'

    # Author of this module
    Author = 'AitherZero Contributors'

    # Company or vendor of this module
    CompanyName = 'AitherZero'

    # Copyright statement for this module
    Copyright = '(c) 2025 AitherZero. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Enterprise-grade inter-module communication with pub/sub messaging, API registry, event-driven architecture, security features, circuit breaker patterns, and comprehensive monitoring for the AitherZero platform'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Modules that must be imported into the global environment prior to importing this module
    # RequiredModules = @()
    # Note: Logging module is a core dependency and should be loaded by the main script, not as a circular dependency

    # Functions to export from this module
    FunctionsToExport = @(
        # Message Bus Functions
        'Submit-ModuleMessage',
        'Register-ModuleMessageHandler',
        'Unsubscribe-ModuleMessage',
        'Get-MessageSubscriptions',
        'Clear-MessageQueue',
        
        # Channel Management
        'New-MessageChannel',
        'Remove-MessageChannel',
        'Get-MessageChannels',
        'Test-MessageChannel',
        
        # API Registry Functions
        'Register-ModuleAPI',
        'Unregister-ModuleAPI',
        'Invoke-ModuleAPI',
        'Get-ModuleAPIs',
        'Test-ModuleAPI',
        
        # Middleware Functions
        'Add-APIMiddleware',
        'Remove-APIMiddleware',
        'Get-APIMiddleware',
        
        # Event System (Enhanced)
        'Submit-ModuleEvent',
        'Register-ModuleEventHandler',
        'Unsubscribe-ModuleEvent',
        'Get-ModuleEvents',
        'Clear-EventHistory',
        
        # Performance & Monitoring
        'Get-CommunicationMetrics',
        'Reset-CommunicationMetrics',
        'Enable-MessageTracing',
        'Disable-MessageTracing',
        
        # Security Functions
        'Enable-CommunicationSecurity',
        'New-AuthenticationToken',
        'Revoke-AuthenticationToken',
        
        # Circuit Breaker Functions
        'Get-CircuitBreakerStatus',
        'Reset-CircuitBreaker',
        
        # Utilities
        'Test-ModuleCommunication',
        'Get-CommunicationStatus',
        'Start-MessageProcessor',
        'Stop-MessageProcessor',
        
        # Backward Compatibility Aliases
        'Publish-ModuleMessage',
        'Subscribe-ModuleMessage', 
        'Publish-ModuleEvent',
        'Subscribe-ModuleEvent'
    )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @(
        'Send-ModuleMessage',
        'Send-ModuleEvent',
        'Publish-ModuleMessage',
        'Subscribe-ModuleMessage',
        'Publish-ModuleEvent',
        'Subscribe-ModuleEvent'
    )

    # Private data to pass to the module
    PrivateData = @{
        PSData = @{
            # Tags applied to this module
            Tags = @('Communication', 'Messaging', 'PubSub', 'Events', 'API', 'Integration', 'Security', 'CircuitBreaker', 'Monitoring', 'AitherZero')

            # A URL to the main website for this project
            ProjectUri = 'https://github.com/AitherLabs/AitherZero'

            # ReleaseNotes of this module
            ReleaseNotes = 'v2.0.0 - Major update with security features, circuit breaker patterns, enhanced error handling, retry logic, comprehensive testing, and enterprise-grade monitoring capabilities'
        }
    }
}