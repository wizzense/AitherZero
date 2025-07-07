@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'ProgressTracking.psm1'

    # Version number of this module.
    ModuleVersion = '2.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Core')

    # ID used to uniquely identify this module
    GUID = 'e7f3d9a2-4b5c-4d8e-9f6a-1b2c3d4e5f6a'

    # Author of this module
    Author = 'AitherZero Contributors'

    # Company or vendor of this module
    CompanyName = 'AitherZero'

    # Copyright statement for this module
    Copyright = '(c) 2025 AitherZero. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'COMPATIBILITY SHIM: Backward compatibility module for ProgressTracking. This module has been consolidated into the new unified UtilityManager module. Please migrate to the new UtilityManager module.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Start-ProgressOperation',
        'Update-ProgressOperation',
        'Complete-ProgressOperation',
        'Get-ProgressStatus',
        'Stop-ProgressOperation',
        'Add-ProgressWarning',
        'Add-ProgressError',
        'Start-MultiProgress',
        'Update-MultiProgress',
        'Complete-MultiProgress',
        'Show-ProgressSummary',
        'Get-ProgressHistory',
        'Clear-ProgressHistory',
        'Export-ProgressReport',
        'Test-ProgressOperationActive'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('Progress', 'Tracking', 'Monitoring', 'Visualization', 'Operations', 'AitherZero', 'Compatibility', 'Deprecated')

            # A URL to the license for this module.
            # LicenseUri = ''

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/AitherLabs/AitherZero'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
v2.0.0 - COMPATIBILITY SHIM RELEASE:
- This module has been consolidated into the new unified UtilityManager
- All functions are preserved with deprecation warnings
- Automatic forwarding to the new UtilityManager module
- Migration guide available in module documentation
- DEPRECATED: Please migrate to UtilityManager module for future compatibility
'@

            # Prerelease string of this module
            # Prerelease = ''

            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            # RequireLicenseAcceptance = $false

            # External dependent modules of this module
            # ExternalModuleDependencies = @()

        } # End of PSData hashtable

    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''
}