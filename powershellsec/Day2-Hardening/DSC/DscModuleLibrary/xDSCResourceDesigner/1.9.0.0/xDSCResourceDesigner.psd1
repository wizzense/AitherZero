@{
# Version number of this module.
ModuleVersion = '1.9.0.0'

# ID used to uniquely identify this module
GUID = '74951b31-1aa5-472b-9109-738de1bca38f'

# Author of this module
Author = 'Microsoft Corporation'

# Company or vendor of this module
CompanyName = 'Microsoft Corporation'

# Copyright statement for this module
Copyright = '(c) 2015 Microsoft Corporation. All rights reserved.'

# Description of the functionality provided by this module
Description = 'This module is meant to assist with the development and testing of DSC Resources.'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '4.0'

# Minimum version of the common language runtime (CLR) required by this module
CLRVersion = '4.0'

# Script module or binary module file associated with this manifest.
RootModule = 'xDSCResourceDesigner.psm1'

# Functions to export from this module
FunctionsToExport = @('New-xDscResourceProperty',
                        'New-xDscResource',
                        'Update-xDscResource',
                        'Test-xDscResource',
                        'Test-xDscSchema',
                        'Import-xDscSchema')

# Cmdlets to export from this module
CmdletsToExport = '*'

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('DesiredStateConfiguration', 'DSC', 'DSCResourceKit', 'DSCResource')

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/PowerShell/xDSCResourceDesigner/blob/master/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/PowerShell/xDSCResourceDesigner'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        ReleaseNotes = '* Fixed issue where using ValidateSet with type string[] would throw an error

'

    } # End of PSData hashtable

} # End of PrivateData hashtable
}

