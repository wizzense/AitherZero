[![Build status](https://ci.appveyor.com/api/projects/status/gjg8b430d230q51h/branch/master?svg=true)](https://ci.appveyor.com/project/PowerShell/xdismfeature/branch/master)

# xDismFeature

The **xDismFeature** module is a part of the Windows PowerShell Desired State Configuration (DSC) Resource Kit, which is a collection of DSC Resources produced by the PowerShell Team.
This module enables or disables Windows optional features that specifically need to be handled by DISM.exe.
The **xDismFeature** module contains a single resource, **xDismFeature**.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Contributing

Please read the DSC Resources [contributing guidelines](https://github.com/PowerShell/DscResource.Kit/blob/master/CONTRIBUTING.md) if you would like to contribute.

## Description

The **xDismFeature** module contains the **xDismFeature** DSC Resource.
This DSC module enables the install and uninstall of features that require the use of DISM.EXE 

## Resources

### xDismFeatureConsoleSetup

*   **Ensure**: An enumerated value (Present, Absent) to indicate if the feature is or is not installed.

*   **Name**: KEY - The name of the feature to be installed.

*   **Source**: (Optional) Source for features with packages removed. Setting source will also make dism act in "/LimitAccess", or offline-mode.

## Versions

### Unreleased

### 1.2.0.0

* xDismFeature: Resource no longer includes the Source parameter when it is not specified
* Converted appveyor.yml to install Pester from PSGallery instead of from Chocolatey.

### 1.1.0.0

* Remove UTF8 BOM
* Added source parameter for offline use

### 1.0.0

*   Initial release with the following resources 
    *   xDismFeature 

## Examples

### Enable the Single Instance Storage feature on Windows Server

```powershell

    Configuration SIS-Limited
    {
        Import-DscResource -Module xDismFeature
        Node 'NodeName'
        {
            Ensure = 'Present'
            Name = 'SIS-Limited'
        }

    }
    
    Configuration SIS-Limited 
    { 
        Import-DscResource -Module xDismFeature 
     
        Node 'NodeName' 
        { 
            Ensure = 'Present' 
            Name = 'SIS-Limited' 
        } 
    }
```

### Disable the Single Instance Storage feature on Windows Server.

```powershell
    
Configuration SIS-Limited
{
    Import-DscResource -Module xDismFeature
    Node 'NodeName'
    {
        Ensure = 'Absent'
        Name = 'SIS-Limited'
    }
}

Configuration SIS-Limited 
{ 
    Import-DscResource -Module xDismFeature 

    Node 'NodeName' 
    { 
        Ensure = 'Absent' 
        Name = 'SIS-Limited' 
    } 
}

```
