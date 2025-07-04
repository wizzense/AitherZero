@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'ModuleCommunication.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Core')

    # ID used to uniquely identify this module
    GUID = 'a2b3c4d5-e6f7-8901-bcde-f23456789012'

    # Author of this module
    Author = 'AitherZero Team'

    # Company or vendor of this module
    CompanyName = 'AitherZero'

    # Copyright statement for this module
    Copyright = '(c) 2025 AitherZero. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Provides scalable inter-module communication through pub/sub messaging, API registry, and event-driven architecture for the AitherZero platform'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Modules that must be imported into the global environment prior to importing this module
    # RequiredModules = @()
    # Note: Logging module is a core dependency and should be loaded by the main script, not as a circular dependency

    # Functions to export from this module
    FunctionsToExport = @(
        # Message Bus Functions
        'Send-ModuleMessage',
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
        'Send-ModuleEvent',
        'Register-ModuleEventHandler',
        'Unsubscribe-ModuleEvent',
        'Get-ModuleEvents',
        'Clear-EventHistory',
        
        # Performance & Monitoring
        'Get-CommunicationMetrics',
        'Reset-CommunicationMetrics',
        'Enable-MessageTracing',
        'Disable-MessageTracing',
        
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
    AliasesToExport = @()

    # Private data to pass to the module
    PrivateData = @{
        PSData = @{
            # Tags applied to this module
            Tags = @('Communication', 'Messaging', 'PubSub', 'Events', 'API', 'Integration', 'AitherZero')

            # A URL to the main website for this project
            ProjectUri = 'https://github.com/AitherLabs/AitherZero'

            # ReleaseNotes of this module
            ReleaseNotes = 'Initial release of ModuleCommunication - Scalable inter-module communication for AitherZero platform'
        }
    }
}