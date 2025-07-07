@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'UserExperience.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-abcd-1234567890ef'

    # Author of this module
    Author = 'AitherZero Contributors'

    # Company or vendor of this module
    CompanyName = 'AitherZero'

    # Copyright statement for this module
    Copyright = '(c) 2025 AitherZero Team. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Unified User Experience module for AitherZero providing comprehensive onboarding, setup, and interactive management'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        # Unified User Experience Functions
        'Start-UserExperience',
        'Initialize-UserExperience',
        'Show-WelcomeScreen',
        
        # Setup and Onboarding Functions
        'Start-IntelligentSetup',
        'Start-FirstTimeSetup',
        'Complete-UserOnboarding',
        'Generate-QuickStartGuide',
        'Test-SystemReadiness',
        'Show-SetupProgress',
        
        # Interactive Experience Functions
        'Start-InteractiveMode',
        'Show-MainDashboard',
        'Start-ConfigurationWizard',
        'Show-ModuleExplorer',
        'Start-TaskRunner',
        
        # Configuration Management Functions
        'New-UserProfile',
        'Get-UserProfile',
        'Set-UserProfile',
        'Remove-UserProfile',
        'Export-UserProfile',
        'Import-UserProfile',
        'Sync-UserConfiguration',
        
        # User Interface Functions
        'Initialize-TerminalUI',
        'Reset-TerminalUI',
        'Show-ContextMenu',
        'Show-ProgressIndicator',
        'Get-UserInput',
        'Show-InformationDialog',
        'Show-ConfirmationDialog',
        
        # Experience Customization Functions
        'Set-UserPreferences',
        'Get-UserPreferences',
        'Set-UITheme',
        'Get-UITheme',
        'Enable-ExpertMode',
        'Disable-ExpertMode',
        
        # Help and Guidance Functions
        'Show-UserGuide',
        'Start-TutorialMode',
        'Show-FeatureIntroduction',
        'Get-ContextualHelp',
        'Show-TroubleshootingGuide',
        
        # Performance and Analytics Functions
        'Test-UserExperience',
        'Get-UsageAnalytics',
        'Optimize-UserWorkflow',
        'Generate-UsageReport',
        
        # Legacy Compatibility Functions
        'Edit-Configuration',
        'Review-Configuration',
        'Get-ModuleDiscovery',
        'Clear-ModuleDiscoveryCache',
        'Test-StartupPerformance'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @(
        'Start-UX',
        'Setup-AitherZero',
        'Configure-AitherZero',
        'Show-Dashboard',
        'Interactive-Mode'
    )

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('AitherZero', 'UserExperience', 'Setup', 'Interactive', 'UI', 'Configuration', 'Onboarding')

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/wizzense/AitherZero/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/wizzense/AitherZero'

            # A URL to an icon representing this module.
            IconUri = ''

            # Release notes for this module
            ReleaseNotes = 'Unified User Experience module combining SetupWizard and StartupExperience functionality'

            # Prerelease string of this module
            # Prerelease = ''

            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            RequireLicenseAcceptance = $false

            # External dependent modules of this module
            # ExternalModuleDependencies = @()
            
            # Module Features and Capabilities
            Features = @{
                IntelligentSetup = @{
                    Description = 'Automated platform detection and environment setup'
                    Capabilities = @('PlatformDetection', 'DependencyChecking', 'ConfigurationGeneration')
                }
                InteractiveUI = @{
                    Description = 'Rich terminal-based user interface'
                    Capabilities = @('MenuNavigation', 'ProgressTracking', 'ThemeSupport')
                }
                ConfigurationManagement = @{
                    Description = 'Comprehensive configuration and profile management'
                    Capabilities = @('ProfileSwitching', 'ConfigurationValidation', 'BackupRestore')
                }
                UserGuidance = @{
                    Description = 'Contextual help and user guidance system'
                    Capabilities = @('TutorialMode', 'ContextualHelp', 'QuickStart')
                }
            }
        }
    }
}