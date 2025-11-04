# ISO Customization Module

## Overview

This module provides ISO customization capabilities for Windows and Linux operating system images. It integrates with the ISO download automation (0180_Download-OSISOs.ps1) to provide end-to-end ISO management.

## Planned Features

### 1. ISO Extraction and Mounting
- Mount ISOs on Windows (using PowerShell Mount-DiskImage)
- Extract ISO contents on Linux (using 7z or mount)
- Verify ISO integrity (checksum validation)

### 2. Windows ISO Customization
- **Driver Injection**: Add hardware drivers (DISM)
- **Update Integration**: Integrate Windows updates
- **Unattend.xml**: Configure automated installation
- **Remove Components**: Strip unnecessary features
- **Add Software**: Include applications in image
- **Registry Tweaks**: Pre-configure Windows settings

### 3. Linux ISO Customization
- **Kickstart/Preseed**: Automated installation configs
- **Package Injection**: Add packages to installer
- **Custom Repositories**: Configure package sources
- **Post-install Scripts**: Automation hooks

### 4. ISO Repackaging
- Create bootable ISOs from modified content
- Generate hybrid ISOs (BIOS + UEFI)
- Multi-boot ISO creation

### 5. Validation and Testing
- Boot validation (check bootability)
- Checksum generation
- Size optimization
- Compatibility testing

## Configuration Structure

```powershell
Infrastructure.ISOCustomization = @{
    Enabled = $true
    WorkingDirectory = 'C:/iso_work'
    
    # Windows customization
    Windows = @{
        DriverPaths = @('C:/drivers/network', 'C:/drivers/storage')
        UpdatesPath = 'C:/updates/windows'
        UnattendTemplate = 'Templates/unattend.xml'
        RemoveComponents = @('Internet-Explorer-Optional', 'WindowsMediaPlayer')
        AddSoftware = @()
    }
    
    # Linux customization
    Linux = @{
        KickstartTemplate = 'Templates/kickstart.cfg'
        PreseedTemplate = 'Templates/preseed.cfg'
        PackagesToAdd = @()
        PostInstallScripts = @()
    }
    
    # Tools configuration
    Tools = @{
        DISM = 'C:/Windows/System32/dism.exe'
        OSCDIMG = 'C:/Program Files (x86)/Windows Kits/10/Assessment and Deployment Kit/Deployment Tools/amd64/Oscdimg/oscdimg.exe'
        MKISOFS = 'mkisofs'
        GENISOIMAGE = 'genisoimage'
    }
}
```

## Scripts to Implement

### Core Scripts (0190-0199 range)

1. **0190_Extract-ISO.ps1**
   - Extract ISO contents to working directory
   - Verify ISO integrity
   - Prepare for customization

2. **0191_Inject-Drivers.ps1**
   - Add drivers to Windows ISOs (DISM)
   - Support for both WinPE and Windows images

3. **0192_Integrate-Updates.ps1**
   - Apply Windows updates to ISO
   - Service the image with latest patches

4. **0193_Configure-Unattend.ps1**
   - Generate or modify unattend.xml
   - Configure automated Windows installation

5. **0194_Add-Software.ps1**
   - Inject software into Windows ISO
   - Configure auto-install on first boot

6. **0195_Customize-LinuxISO.ps1**
   - Modify kickstart/preseed files
   - Add packages to Linux installers

7. **0196_Create-BootableISO.ps1**
   - Repack modified contents into bootable ISO
   - Generate BIOS and UEFI compatible images

8. **0197_Validate-ISO.ps1**
   - Verify ISO bootability
   - Generate checksums
   - Test compatibility

9. **0198_Create-MultibootISO.ps1**
   - Combine multiple ISOs
   - Create GRUB-based multi-boot menu

10. **0199_Manage-ISOLibrary.ps1**
    - List, organize, cleanup ISO files
    - Track customization history

## Module Structure

```
domains/infrastructure/
  ├── ISOManager.psm1        # Core ISO operations
  └── ISOCustomizer.psm1     # Customization functions

automation-scripts/
  ├── 0190_Extract-ISO.ps1
  ├── 0191_Inject-Drivers.ps1
  ├── 0192_Integrate-Updates.ps1
  ├── 0193_Configure-Unattend.ps1
  ├── 0194_Add-Software.ps1
  ├── 0195_Customize-LinuxISO.ps1
  ├── 0196_Create-BootableISO.ps1
  ├── 0197_Validate-ISO.ps1
  ├── 0198_Create-MultibootISO.ps1
  └── 0199_Manage-ISOLibrary.ps1

Templates/
  ├── unattend.xml
  ├── kickstart.cfg
  └── preseed.cfg
```

## Integration with Download System

The ISO customization scripts will integrate seamlessly with 0180_Download-OSISOs.ps1:

```powershell
# Download and customize workflow
./0180_Download-OSISOs.ps1 -OSType Windows -Distro Server2022
./0190_Extract-ISO.ps1 -ISOPath "C:/iso_share/WindowsServer2022-Eval.iso"
./0191_Inject-Drivers.ps1 -ImagePath "C:/iso_work/extract" -DriverPath "C:/drivers"
./0193_Configure-Unattend.ps1 -ImagePath "C:/iso_work/extract" -Template "Templates/server-unattend.xml"
./0196_Create-BootableISO.ps1 -SourcePath "C:/iso_work/extract" -OutputISO "C:/iso_share/Server2022-Custom.iso"
```

## Requirements

### Windows
- DISM (Windows Deployment Image Servicing and Management)
- Windows ADK (Assessment and Deployment Kit) for oscdimg
- 7-Zip for extraction
- Admin privileges for mounting ISOs

### Linux
- genisoimage or mkisofs for ISO creation
- 7z or mount for extraction
- isolinux/syslinux for bootable ISO creation

## Status

**Current Status**: Specification stage - awaiting user confirmation on required features

**Next Steps**:
1. Confirm required features with user
2. Implement core ISOManager module
3. Create automation scripts for confirmed features
4. Add configuration to config.psd1
5. Create templates for unattend/kickstart/preseed
6. Add comprehensive tests
7. Update documentation

---

*This specification was created based on common ISO customization requirements. Features will be implemented based on user needs.*
