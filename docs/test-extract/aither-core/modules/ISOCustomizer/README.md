# ISOCustomizer Module

## Module Overview

The ISOCustomizer module provides enterprise-grade ISO customization and autounattend file generation capabilities for the AitherZero infrastructure automation framework. This module enables automated deployment of Windows and Linux systems by creating customized installation media with pre-configured settings, scripts, and drivers.

### Core Functionality and Use Cases

- **Custom ISO Creation**: Mount, modify, and rebuild Windows ISOs with custom configurations
- **Autounattend Generation**: Create unattended installation answer files for Windows deployments
- **Script Injection**: Embed bootstrap scripts and automation tools into installation media
- **Driver Integration**: Add hardware-specific drivers to installation images
- **Multi-Platform Support**: Supports Windows Server 2019/2022/2025, Windows 10/11, and Linux distributions

### Integration with Infrastructure Automation

- Seamlessly integrates with OpenTofu/Terraform workflows for automated VM provisioning
- Works with ISOManager module for ISO inventory management
- Supports LabRunner module for automated lab deployments
- Integrates with centralized logging for deployment tracking

### Key Features and Capabilities

- Cross-platform compatible (Windows primarily, with Linux support)
- Windows ADK/DISM integration for image manipulation
- Template-based autounattend file generation
- Registry modification support for offline images
- Bootstrap script injection for post-installation automation
- Headless mode support for server deployments

## Directory Structure

```
ISOCustomizer/
├── ISOCustomizer.psd1         # Module manifest
├── ISOCustomizer.psm1         # Module script with initialization
├── Public/                    # Exported functions
│   ├── New-CustomISO.ps1      # Creates customized ISO files
│   └── New-AutounattendFile.ps1 # Generates autounattend XML files
├── Private/                   # Internal helper functions
│   ├── ISOHelpers.ps1         # ISO manipulation utilities
│   └── TemplateHelpers.ps1    # Template retrieval functions
└── Templates/                 # XML and script templates
    ├── autounattend-generic.xml    # Generic Windows answer file
    ├── autounattend-headless.xml   # Headless server answer file
    ├── bootstrap.ps1               # Post-installation bootstrap
    └── kickstart.cfg               # Linux kickstart template
```

## Core Functions

### New-CustomISO

Creates a customized ISO file with embedded configurations, scripts, and drivers.

**Parameters:**
- `SourceISOPath` (Mandatory): Path to the source ISO file
- `OutputISOPath` (Mandatory): Path for the output customized ISO
- `ExtractPath`: Temporary directory for ISO extraction (auto-generated if not specified)
- `MountPath`: Temporary directory for WIM mounting (auto-generated if not specified)
- `BootstrapScript`: Path to bootstrap PowerShell script to embed
- `AutounattendFile`: Path to existing autounattend.xml file
- `AutounattendConfig`: Hashtable to generate autounattend.xml dynamically
- `WIMIndex`: Windows image index to modify (default: 3)
- `AdditionalFiles`: Array of files to add to the image
- `DriversPath`: Array of driver directories to integrate
- `RegistryChanges`: Hashtable of registry modifications
- `OscdimgPath`: Path to oscdimg.exe (auto-detected if not specified)
- `Force`: Overwrite existing files
- `KeepTempFiles`: Retain temporary files after completion
- `ValidateOnly`: Validate parameters without creating ISO

**Returns:** PSCustomObject with operation details

**Usage Example:**
```powershell
# Basic ISO customization with autounattend
$config = @{
    ComputerName = 'LAB-SERVER-01'
    AdminPassword = 'P@ssw0rd123!'
    TimeZone = 'Pacific Standard Time'
    EnableRDP = $true
}

$result = New-CustomISO -SourceISOPath "C:\ISOs\Server2025.iso" `
                       -OutputISOPath "C:\ISOs\Server2025-Custom.iso" `
                       -AutounattendConfig $config `
                       -Force

# Advanced customization with drivers and scripts
$customISO = New-CustomISO -SourceISOPath "D:\ISOs\Win11.iso" `
                          -OutputISOPath "D:\ISOs\Win11-Lab.iso" `
                          -BootstrapScript ".\Scripts\lab-setup.ps1" `
                          -DriversPath @("D:\Drivers\Network", "D:\Drivers\Storage") `
                          -AdditionalFiles @(".\Tools\BGInfo.exe|Windows\System32") `
                          -WIMIndex 4 `
                          -Force
```

### New-AutounattendFile

Generates Windows autounattend.xml files for unattended installations.

**Parameters:**
- `Configuration` (Mandatory): Hashtable containing installation settings
- `OutputPath` (Mandatory): Path for the generated autounattend.xml
- `OSType`: Target OS type (Server2025, Server2022, Server2019, Windows11, Windows10, Generic)
- `Edition`: OS edition (Standard, Datacenter, Core, Desktop)
- `TemplatePath`: Custom template path (uses built-in templates if not specified)
- `HeadlessMode`: Generate configuration for headless server deployment
- `Force`: Overwrite existing files

**Configuration Options:**
```powershell
$configuration = @{
    # Localization
    InputLocale = 'en-US'
    SystemLocale = 'en-US'
    UILanguage = 'en-US'
    UserLocale = 'en-US'
    
    # License
    AcceptEula = $true
    ProductKey = 'XXXXX-XXXXX-XXXXX-XXXXX-XXXXX'
    
    # User Data
    FullName = 'Lab Administrator'
    Organization = 'AitherZero Labs'
    
    # Disk Configuration
    DiskID = 0
    EFIPartitionSize = 260  # MB
    MSRPartitionSize = 16   # MB
    PrimaryPartitionSize = 60000  # MB
    
    # Administrator
    AdminPassword = 'SecureP@ssw0rd!'
    AdminPasswordPlainText = $false
    
    # Computer Settings
    ComputerName = 'WIN-LAB-01'
    TimeZone = 'UTC'
    
    # Network
    EnableDHCP = $true
    
    # Features
    EnableRDP = $true
    DisableWindowsDefender = $false
    DisableFirewall = $false
    DisableUAC = $false
    
    # Auto Logon
    AutoLogon = $true
    AutoLogonCount = 3
    
    # Post-Installation
    FirstLogonCommands = @(
        @{
            CommandLine = 'powershell -ExecutionPolicy Bypass -Command "Set-NetFirewallProfile -All -Enabled False"'
            Description = 'Disable Windows Firewall'
        }
    )
    BootstrapScript = 'C:\Windows\bootstrap.ps1'
}
```

**Usage Example:**
```powershell
# Generate autounattend for Windows Server 2025 Datacenter
New-AutounattendFile -Configuration $configuration `
                     -OutputPath ".\autounattend.xml" `
                     -OSType 'Server2025' `
                     -Edition 'Datacenter'

# Generate headless server configuration
New-AutounattendFile -Configuration $configuration `
                     -OutputPath ".\headless-autounattend.xml" `
                     -OSType 'Server2022' `
                     -HeadlessMode `
                     -Force
```

### Get-AutounattendTemplate

Retrieves pre-defined autounattend.xml templates.

**Parameters:**
- `TemplateType`: Type of template (Generic, Headless)

**Returns:** Path to template file or $null if not found

**Usage Example:**
```powershell
$genericTemplate = Get-AutounattendTemplate -TemplateType 'Generic'
$headlessTemplate = Get-AutounattendTemplate -TemplateType 'Headless'
```

### Get-BootstrapTemplate

Retrieves the default bootstrap script template.

**Returns:** Path to bootstrap.ps1 template or $null if not found

**Usage Example:**
```powershell
$bootstrapPath = Get-BootstrapTemplate
if ($bootstrapPath) {
    Copy-Item $bootstrapPath ".\my-bootstrap.ps1"
}
```

### Get-KickstartTemplate

Retrieves the Linux kickstart configuration template.

**Returns:** Path to kickstart.cfg template or $null if not found

**Usage Example:**
```powershell
$kickstartPath = Get-KickstartTemplate
```

## Workflows

### Creating a Custom Windows Server ISO

```powershell
# 1. Define server configuration
$serverConfig = @{
    ComputerName = 'DC-01'
    AdminPassword = 'ComplexP@ssw0rd!'
    TimeZone = 'Eastern Standard Time'
    Organization = 'Contoso Labs'
    EnableRDP = $true
    AutoLogon = $true
    AutoLogonCount = 1
}

# 2. Create custom ISO with embedded configuration
$customISO = New-CustomISO -SourceISOPath "E:\ISOs\WindowsServer2025.iso" `
                          -OutputISOPath "E:\ISOs\WS2025-DC01.iso" `
                          -AutounattendConfig $serverConfig `
                          -BootstrapScript ".\Scripts\domain-controller-setup.ps1" `
                          -Force

# 3. Verify ISO creation
if ($customISO.Success) {
    Write-Host "Custom ISO created: $($customISO.OutputISO)"
    Write-Host "Size: $([math]::Round($customISO.FileSize/1GB, 2)) GB"
}
```

### Multi-VM Lab Deployment Workflow

```powershell
# Define lab VMs
$labVMs = @(
    @{Name='DC01'; Role='DomainController'; IP='192.168.100.10'},
    @{Name='SQL01'; Role='SQLServer'; IP='192.168.100.20'},
    @{Name='WEB01'; Role='WebServer'; IP='192.168.100.30'}
)

foreach ($vm in $labVMs) {
    # Generate VM-specific configuration
    $vmConfig = @{
        ComputerName = $vm.Name
        AdminPassword = 'LabP@ssw0rd123!'
        TimeZone = 'UTC'
        FirstLogonCommands = @(
            @{
                CommandLine = "powershell -Command `"New-NetIPAddress -IPAddress $($vm.IP) -PrefixLength 24 -DefaultGateway 192.168.100.1`""
                Description = "Configure Static IP"
            }
        )
    }
    
    # Create autounattend file
    $autounattendPath = ".\Autounattend\$($vm.Name)-autounattend.xml"
    New-AutounattendFile -Configuration $vmConfig `
                         -OutputPath $autounattendPath `
                         -OSType 'Server2025'
    
    # Create custom ISO
    New-CustomISO -SourceISOPath "D:\ISOs\Server2025.iso" `
                  -OutputISOPath "D:\ISOs\Lab\$($vm.Name).iso" `
                  -AutounattendFile $autounattendPath `
                  -Force
}
```

### Automation Integration Example

```powershell
# Integration with OpenTofu/Terraform
function New-LabInfrastructureISO {
    param(
        [string]$LabName,
        [hashtable]$LabConfig
    )
    
    # Generate bootstrap script dynamically
    $bootstrapContent = @"
# Lab: $LabName
# Generated: $(Get-Date)
Write-Host "Starting lab initialization for $LabName"

# Install required features
Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools

# Configure lab-specific settings
`$labConfig = @'
$($LabConfig | ConvertTo-Json -Depth 10)
'@ | ConvertFrom-Json

# Apply configurations
# ... (additional automation logic)
"@
    
    # Save bootstrap script
    $bootstrapPath = ".\Bootstrap\$LabName-bootstrap.ps1"
    Set-Content -Path $bootstrapPath -Value $bootstrapContent
    
    # Create custom ISO with all configurations
    New-CustomISO -SourceISOPath $LabConfig.SourceISO `
                  -OutputISOPath ".\ISOs\$LabName-deployment.iso" `
                  -BootstrapScript $bootstrapPath `
                  -AutounattendConfig $LabConfig.AutounattendConfig `
                  -DriversPath $LabConfig.Drivers `
                  -Force
}
```

## Configuration

### Module Configuration

The module uses the following configuration structure:

```powershell
# Default paths (can be overridden)
$moduleConfig = @{
    # Temporary directories
    DefaultExtractPath = Join-Path $env:TEMP "ISOExtract"
    DefaultMountPath = Join-Path $env:TEMP "ISOMount"
    
    # Windows ADK paths
    OscdimgPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
    DismPath = "dism.exe"
    
    # Template locations
    TemplateDirectory = Join-Path $PSScriptRoot "Templates"
    
    # Default WIM settings
    DefaultWIMIndex = 3  # Windows Server Datacenter
}
```

### Customization Options

#### Custom Autounattend Templates

Create custom templates by modifying the XML structure:

```xml
<!-- Custom template example -->
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup">
            <!-- Custom branding -->
            <OEMInformation>
                <Manufacturer>AitherZero Labs</Manufacturer>
                <Model>Custom Lab Build</Model>
                <SupportHours>24/7</SupportHours>
            </OEMInformation>
        </component>
    </settings>
</unattend>
```

#### Registry Customization

Apply registry changes to offline images:

```powershell
$registryChanges = @{
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' = @{
        'DoNotConnectToWindowsUpdateInternetLocations' = 1
        'DisableWindowsUpdateAccess' = 1
    }
    'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' = @{
        'fDenyTSConnections' = 0
    }
}

New-CustomISO -SourceISOPath ".\source.iso" `
              -OutputISOPath ".\custom.iso" `
              -RegistryChanges $registryChanges
```

## Templates and Resources

### Autounattend XML Templates

#### Generic Template (autounattend-generic.xml)
- Standard Windows installation
- Basic disk partitioning (EFI/MSR/Primary)
- Administrator account setup
- OOBE bypass settings
- Network location set to Work

#### Headless Template (autounattend-headless.xml)
- Server Core optimized
- Minimal UI interaction
- Remote management enabled
- PowerShell as default shell
- Enhanced security settings

### Bootstrap Script Template (bootstrap.ps1)

The default bootstrap script:
- Downloads latest automation tools from GitHub
- Supports both PowerShell 5.1 and 7+
- Configurable branch selection
- Error handling and logging

### Kickstart Template (kickstart.cfg)

Linux installation automation:
- Partition layout definition
- Package selection
- Post-installation scripts
- Network configuration
- User account creation

## Best Practices

### ISO Management Guidelines

1. **Source ISO Storage**
   - Store source ISOs on fast storage (SSD recommended)
   - Maintain ISO integrity with checksums
   - Use descriptive naming conventions

2. **Customization Strategy**
   - Create base images with common configurations
   - Layer specific customizations on top
   - Document all customizations

3. **Security Considerations**
   - Never store plaintext passwords in templates
   - Use secure credential management
   - Validate ISO signatures
   - Restrict access to custom ISOs

### Lab Automation Patterns

1. **Modular Approach**
   ```powershell
   # Base configuration
   $baseConfig = Get-BaseConfiguration
   
   # Role-specific additions
   $dcConfig = Merge-Configuration $baseConfig (Get-DCConfiguration)
   $sqlConfig = Merge-Configuration $baseConfig (Get-SQLConfiguration)
   ```

2. **Version Control**
   - Track autounattend files in Git
   - Version bootstrap scripts
   - Document configuration changes

3. **Testing Workflow**
   ```powershell
   # Test configuration in VM first
   $testISO = New-CustomISO -SourceISOPath ".\test.iso" `
                           -OutputISOPath ".\test-custom.iso" `
                           -AutounattendConfig $config `
                           -ValidateOnly
   ```

### Performance Considerations

1. **Disk Space Requirements**
   - Source ISO size × 3 (extraction + mounting + output)
   - Additional space for drivers and files
   - SSD recommended for better performance

2. **Memory Usage**
   - DISM operations can be memory intensive
   - Recommend 8GB+ RAM for large images
   - Close unnecessary applications

3. **Optimization Tips**
   - Use `-KeepTempFiles` for iterative development
   - Pre-download drivers to local cache
   - Create ISO templates for common scenarios

### Error Handling

```powershell
try {
    $result = New-CustomISO @params
    if ($result.Success) {
        Write-Log "ISO created successfully"
    }
} catch {
    Write-Log "ISO creation failed: $_" -Level Error
    # Cleanup operations
    if (Test-Path $tempPath) {
        Remove-Item $tempPath -Recurse -Force
    }
}
```

## Integration Examples

### With ISOManager Module

```powershell
# Download and customize in one workflow
Import-Module ISOManager, ISOCustomizer

# Download latest Windows Server ISO
$download = Get-ISODownload -ISOName "WindowsServer2025" `
                           -Version "latest" `
                           -Architecture "x64"

# Customize the downloaded ISO
if ($download.Status -eq 'Completed') {
    $customISO = New-CustomISO -SourceISOPath $download.FilePath `
                              -OutputISOPath ".\CustomServer2025.iso" `
                              -AutounattendConfig $serverConfig
}
```

### With LabRunner Module

```powershell
# Create ISOs for lab automation
$labConfig = Get-LabConfig -ConfigPath ".\labs\test-lab.json"

foreach ($node in $labConfig.Nodes) {
    $isoPath = New-CustomLabISO -NodeConfig $node `
                                -SourceISO $labConfig.BaseISO
    
    # Register ISO with LabRunner
    Register-LabISO -NodeName $node.Name `
                    -ISOPath $isoPath
}

# Start lab deployment
Start-LabAutomation -LabName "test-lab" -UseCustomISOs
```

## Troubleshooting

### Common Issues

1. **"Windows ADK not found"**
   - Install Windows ADK with Deployment Tools
   - Specify custom path with `-OscdimgPath`

2. **"Access denied" errors**
   - Run PowerShell as Administrator
   - Check file permissions
   - Ensure ISO is not mounted

3. **"WIM mount failed"**
   - Clean up orphaned mounts: `dism /cleanup-wim`
   - Verify WIM index exists: `dism /get-wiminfo /wimfile:install.wim`

4. **"Invalid XML" errors**
   - Validate autounattend.xml syntax
   - Check for special characters
   - Use provided templates as base

### Diagnostic Commands

```powershell
# Check DISM health
dism /Online /Cleanup-Image /CheckHealth

# List mounted images
dism /Get-MountedImageInfo

# Cleanup corrupted mounts
dism /Cleanup-Wim

# Validate autounattend XML
[xml]$xml = Get-Content ".\autounattend.xml"
$xml.Validate()
```

## Module Dependencies

- **PowerShell 7.0+**: Required for cross-platform compatibility
- **Windows ADK**: Required for oscdimg.exe and DISM operations
- **Logging Module**: For centralized logging integration
- **.NET Framework**: For XML processing and validation

## See Also

- [ISOManager Module](../ISOManager/README.md)
- [LabRunner Module](../LabRunner/README.md)
- [OpenTofuProvider Module](../OpenTofuProvider/README.md)
- [Windows ADK Documentation](https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install)