@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'SetupWizard.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # ID used to uniquely identify this module
    GUID = 'f1e2d3c4-b5a6-9788-9c0d-1e2f3a4b5c6d'

    # Author of this module
    Author = 'AitherZero Contributors'

    # Company or vendor of this module
    CompanyName = 'AitherZero'

    # Copyright statement for this module
    Copyright = '(c) 2025 AitherZero Team. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Enhanced setup wizard module for AitherZero with intelligent platform detection, installation profiles, and progress tracking'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Start-IntelligentSetup',
        'Generate-QuickStartGuide',
        'Edit-Configuration',
        'Review-Configuration'
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
            Tags = @('AitherZero', 'Setup', 'Wizard', 'Installation', 'Configuration')

            # A URL to the license for this module.
            LicenseUri = ''

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/wizzense/AitherZero'

            # A URL to an icon representing this module.
            IconUri = ''

            # Release notes for this module
            ReleaseNotes = 'Initial release of enhanced setup wizard with intelligent platform detection and installation profiles'

            # Prerelease string of this module
            # Prerelease = ''

            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            RequireLicenseAcceptance = $false

            # External dependent modules of this module
            # ExternalModuleDependencies = @()
        }
    }
}