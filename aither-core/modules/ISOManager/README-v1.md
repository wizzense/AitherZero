# ISOManager Module

## Module Overview

The ISOManager module provides enterprise-grade ISO file management capabilities for the AitherZero infrastructure automation framework. It
handles downloading, organizing, validating, and maintaining an inventory of ISO files from various sources including Microsoft, Linux
distributions, and custom URLs.

### Core Functionality and Use Cases

- **ISO Download Management**: Automated downloading from multiple sources with progress tracking
- **Inventory Management**: Track and organize ISO files with metadata
- **Integrity Verification**: Validate ISO files using checksums and signatures
- **Repository Organization**: Create and maintain structured ISO repositories
- **Multi-Source Support**: Download from Microsoft, Linux distributions, and custom URLs
- **Cross-Platform Compatible**: Works on Windows, Linux, and macOS

### Integration with Infrastructure Automation

- Works seamlessly with ISOCustomizer for creating deployment images
- Integrates with OpenTofuProvider for infrastructure provisioning
- Supports LabRunner for automated lab deployments
- Provides centralized ISO management for entire infrastructure

### Key Features and Capabilities

- BITS transfer support on Windows for reliable downloads
- Automatic retry and resume capabilities
- Metadata tracking (version, architecture, language)
- Export/Import functionality for ISO inventories
- Repository synchronization across environments
- Enterprise-grade validation and integrity checking

## Directory Structure

```
ISOManager/
├── ISOManager.psd1              # Module manifest
├── ISOManager.psm1              # Module script with initialization
├── Public/                      # Exported functions
│   ├── Get-ISODownload.ps1      # Downloads ISO files
│   ├── Get-ISOInventory.ps1     # Lists available ISOs
│   ├── Get-ISOMetadata.ps1      # Retrieves ISO metadata
│   ├── Export-ISOInventory.ps1  # Exports inventory to file
│   ├── Import-ISOInventory.ps1  # Imports inventory from file
│   ├── New-ISORepository.ps1    # Creates ISO repository
│   └── Sync-ISORepository.ps1   # Synchronizes repositories
└── Private/                     # Internal helper functions
    ├── Get-WindowsISOUrl.ps1    # Windows ISO URL resolution
    └── Get-LinuxISOUrl.ps1      # Linux ISO URL resolution
```

## Core Functions

### Get-ISODownload

Downloads ISO files from various sources with progress tracking and validation.

**Parameters:**
- `ISOName` (Mandatory): Name of the ISO to download
- `Version`: Version to download (default: "latest")
- `Architecture`: Architecture type (default: "x64")
- `Language`: Language pack (default: "en-US")
- `ISOType`: Type of ISO (Windows, Linux, Custom)
- `CustomURL`: Custom download URL (required for Custom type)
- `DownloadPath`: Directory to save ISO (default: temp directory)
- `VerifyIntegrity`: Verify ISO integrity after download
- `Force`: Overwrite existing files

**Returns:** PSCustomObject with download details

**Usage Example:**
```powershell
# Download Windows Server 2025
$download = Get-ISODownload -ISOName "WindowsServer2025" `
                           -Version "latest" `
                           -Architecture "x64" `
                           -Language "en-US" `
                           -ISOType "Windows" `
                           -DownloadPath "C:\ISOs" `
                           -VerifyIntegrity

# Download Ubuntu Server
$ubuntu = Get-ISODownload -ISOName "Ubuntu" `
                         -Version "22.04" `
                         -ISOType "Linux" `
                         -DownloadPath "D:\LinuxISOs"

# Download from custom URL
$custom = Get-ISODownload -ISOName "CustomOS" `
                         -ISOType "Custom" `
                         -CustomURL "https://example.com/custom.iso" `
                         -VerifyIntegrity
```

### Get-ISOInventory

Lists all available ISO files in the inventory with their metadata.

**Parameters:**
- `Path`: Path to search for ISOs (default: configured repository)
- `Filter`: Filter criteria (hashtable)
- `IncludeMetadata`: Include detailed metadata

**Returns:** Array of ISO inventory objects

**Usage Example:**
```powershell
# Get all ISOs
$allISOs = Get-ISOInventory

# Get Windows ISOs only
$windowsISOs = Get-ISOInventory -Filter @{Type = 'Windows'}

# Get ISOs with metadata
$detailedISOs = Get-ISOInventory -IncludeMetadata

# Filter by multiple criteria
$filtered = Get-ISOInventory -Filter @{
    Type = 'Windows'
    Architecture = 'x64'
    Version = '2025'
}
```

### Get-ISOMetadata

Retrieves detailed metadata for a specific ISO file.

**Parameters:**
- `FilePath` (Mandatory): Path to the ISO file
- `Quick`: Perform quick scan (basic info only)

**Returns:** PSCustomObject with ISO metadata

**Usage Example:**
```powershell
# Get full metadata
$metadata = Get-ISOMetadata -FilePath "C:\ISOs\Server2025.iso"

# Quick metadata scan
$quickInfo = Get-ISOMetadata -FilePath "D:\ISOs\Ubuntu.iso" -Quick

# Display metadata
$metadata | Format-List
```

### Test-ISOIntegrity

Validates ISO file integrity using checksums and signatures.

**Parameters:**
- `FilePath` (Mandatory): Path to the ISO file
- `ExpectedHash`: Expected checksum value
- `Algorithm`: Hash algorithm (SHA256, SHA1, MD5)

**Returns:** Validation result object

**Usage Example:**
```powershell
# Basic integrity check
$valid = Test-ISOIntegrity -FilePath "C:\ISOs\Windows11.iso"

# Verify against known hash
$verified = Test-ISOIntegrity -FilePath "C:\ISOs\Server2025.iso" `
                             -ExpectedHash "A1B2C3D4..." `
                             -Algorithm SHA256
```

### New-ISORepository

Creates a new structured ISO repository with proper organization.

**Parameters:**
- `Path` (Mandatory): Path for the new repository
- `Name`: Repository name
- `Description`: Repository description
- `Structure`: Organization structure (ByType, ByDate, ByVersion)

**Returns:** Repository information object

**Usage Example:**
```powershell
# Create new repository
$repo = New-ISORepository -Path "E:\ISORepository" `
                         -Name "Lab ISOs" `
                         -Description "ISO files for lab deployments" `
                         -Structure "ByType"

# Repository with custom structure
$customRepo = New-ISORepository -Path "F:\ISOs" `
                               -Structure @{
                                   Windows = @('Server', 'Desktop')
                                   Linux = @('Ubuntu', 'CentOS', 'RHEL')
                                   Tools = @('Utilities', 'Diagnostics')
                               }
```

### Export-ISOInventory

Exports ISO inventory to a file for backup or transfer.

**Parameters:**
- `Path` (Mandatory): Export file path
- `Format`: Export format (JSON, CSV, XML)
- `IncludeHashes`: Include file hashes in export

**Returns:** Export result object

**Usage Example:**
```powershell
# Export to JSON
Export-ISOInventory -Path "C:\Backup\iso-inventory.json" `
                   -Format JSON `
                   -IncludeHashes

# Export to CSV for reporting
Export-ISOInventory -Path ".\iso-report.csv" `
                   -Format CSV
```

### Import-ISOInventory

Imports ISO inventory from a previously exported file.

**Parameters:**
- `Path` (Mandatory): Import file path
- `Merge`: Merge with existing inventory
- `ValidateFiles`: Verify imported files exist

**Returns:** Import result object

**Usage Example:**
```powershell
# Import inventory
$imported = Import-ISOInventory -Path "C:\Backup\iso-inventory.json" `
                               -ValidateFiles

# Merge with existing
Import-ISOInventory -Path ".\new-isos.json" `
                   -Merge `
                   -ValidateFiles
```

### Sync-ISORepository

Synchronizes ISO repositories across different locations.

**Parameters:**
- `SourcePath` (Mandatory): Source repository path
- `DestinationPath` (Mandatory): Destination repository path
- `SyncMode`: Synchronization mode (Mirror, Update, Merge)
- `VerifyIntegrity`: Verify file integrity during sync

**Returns:** Synchronization result object

**Usage Example:**
```powershell
# Mirror repository
Sync-ISORepository -SourcePath "\\server\ISOs" `
                  -DestinationPath "E:\LocalISOs" `
                  -SyncMode Mirror `
                  -VerifyIntegrity

# Update only newer files
Sync-ISORepository -SourcePath "C:\MasterISOs" `
                  -DestinationPath "D:\WorkingISOs" `
                  -SyncMode Update
```

## Workflows

### Setting Up an ISO Repository

```powershell
# 1. Create repository structure
$repository = New-ISORepository -Path "E:\ISOLibrary" `
                               -Name "Enterprise ISOs" `
                               -Structure "ByType"

# 2. Download required ISOs
$isoList = @(
    @{Name='WindowsServer2025'; Type='Windows'},
    @{Name='Windows11Enterprise'; Type='Windows'},
    @{Name='Ubuntu'; Version='22.04'; Type='Linux'},
    @{Name='CentOS'; Version='8'; Type='Linux'}
)

foreach ($iso in $isoList) {
    Get-ISODownload @iso -DownloadPath $repository.Path `
                        -VerifyIntegrity
}

# 3. Generate inventory report
$inventory = Get-ISOInventory -Path $repository.Path
Export-ISOInventory -Path "$($repository.Path)\inventory.json"
```

### Automated ISO Updates

```powershell
function Update-ISOLibrary {
    param(
        [string]$RepositoryPath,
        [string[]]$ISONames
    )

    # Get current inventory
    $current = Get-ISOInventory -Path $RepositoryPath

    foreach ($isoName in $ISONames) {
        # Check if update needed
        $existing = $current | Where-Object Name -eq $isoName

        # Get latest version info
        $latest = Get-ISOMetadata -ISOName $isoName -CheckLatest

        if (-not $existing -or $existing.Version -lt $latest.Version) {
            Write-Host "Updating $isoName to version $($latest.Version)"

            Get-ISODownload -ISOName $isoName `
                           -Version $latest.Version `
                           -DownloadPath $RepositoryPath `
                           -Force
        }
    }

    # Update inventory
    Export-ISOInventory -Path "$RepositoryPath\inventory-$(Get-Date -Format 'yyyyMMdd').json"
}
```

### Multi-Site Repository Sync

```powershell
# Define repository locations
$sites = @(
    @{Name='HQ'; Path='\\hq-server\ISOs'; Primary=$true},
    @{Name='Branch1'; Path='\\branch1\ISOs'},
    @{Name='Branch2'; Path='\\branch2\ISOs'},
    @{Name='DR-Site'; Path='\\dr-site\ISOs'}
)

# Sync from primary to all sites
$primary = $sites | Where-Object Primary -eq $true

foreach ($site in ($sites | Where-Object Primary -ne $true)) {
    Write-Host "Syncing to $($site.Name)..."

    $result = Sync-ISORepository -SourcePath $primary.Path `
                                -DestinationPath $site.Path `
                                -SyncMode Mirror `
                                -VerifyIntegrity

    if ($result.Success) {
        Write-Host "✓ $($site.Name) synchronized: $($result.FilesCopied) files"
    } else {
        Write-Warning "✗ $($site.Name) sync failed: $($result.Error)"
    }
}
```

## Configuration

### Module Configuration

The module uses configuration stored in the project's config system:

```powershell
# Default configuration
$moduleConfig = @{
    # Repository settings
    DefaultRepository = Join-Path $env:USERPROFILE "AitherZero\ISOs"
    RepositoryStructure = "ByType"

    # Download settings
    DefaultDownloadPath = Join-Path $env:TEMP "AitherZero-ISOs"
    EnableBITS = $true
    RetryCount = 3
    RetryDelay = 5

    # Validation settings
    AlwaysVerifyIntegrity = $true
    DefaultHashAlgorithm = "SHA256"

    # Inventory settings
    InventoryFormat = "JSON"
    AutoUpdateInventory = $true
}
```

### Custom Repository Structures

Define custom organizational structures:

```powershell
# By purpose structure
$purposeStructure = @{
    Production = @{
        Windows = @('Server2025', 'Server2022')
        Linux = @('RHEL8', 'Ubuntu-LTS')
    }
    Development = @{
        Windows = @('Windows11', 'WindowsServer-Insider')
        Linux = @('Ubuntu-Latest', 'Fedora')
    }
    Testing = @{
        All = @('*-Preview', '*-Beta')
    }
}

New-ISORepository -Path "D:\ISOs" -Structure $purposeStructure
```

### Download Source Configuration

Configure custom download sources:

```powershell
# Add custom source
Register-ISOSource -Name "InternalMirror" `
                  -BaseURL "https://mirror.company.com/isos" `
                  -Priority 1

# Configure source preferences
Set-ISOSourcePreference -Prefer @('InternalMirror', 'Microsoft', 'Direct')
```

## Templates and Resources

### Inventory Schema

```json
{
  "version": "1.0",
  "generated": "2025-01-06T10:00:00Z",
  "repository": {
    "path": "E:\\ISOLibrary",
    "name": "Enterprise ISOs",
    "structure": "ByType"
  },
  "isos": [
    {
      "name": "WindowsServer2025",
      "type": "Windows",
      "version": "10.0.26100.1",
      "architecture": "x64",
      "language": "en-US",
      "filePath": "E:\\ISOLibrary\\Windows\\WindowsServer2025.iso",
      "fileSize": 5825765376,
      "hash": {
        "algorithm": "SHA256",
        "value": "A1B2C3D4..."
      },
      "downloadDate": "2025-01-05T14:30:00Z",
      "source": "Microsoft",
      "metadata": {
        "edition": "Datacenter",
        "buildNumber": "26100"
      }
    }
  ]
}
```

### URL Patterns

Windows ISO URL patterns:
```
https://software-download.microsoft.com/download/pr/{GUID}/{FILENAME}
```

Linux ISO URL patterns:
```
# Ubuntu
https://releases.ubuntu.com/{VERSION}/ubuntu-{VERSION}-{TYPE}-{ARCH}.iso

# CentOS
https://mirror.centos.org/centos/{VERSION}/isos/{ARCH}/CentOS-{VERSION}-{ARCH}-{TYPE}.iso

# RHEL
https://access.redhat.com/downloads/content/rhel-{VERSION}-{ARCH}-{TYPE}.iso
```

## Best Practices

### ISO Management Guidelines

1. **Repository Organization**
   - Use consistent naming conventions
   - Implement version control
   - Maintain metadata accuracy
   - Regular integrity checks

2. **Storage Optimization**
   - Use deduplication where possible
   - Implement lifecycle policies
   - Archive old versions
   - Monitor disk space

3. **Download Strategy**
   - Schedule downloads during off-hours
   - Use local mirrors when available
   - Implement bandwidth throttling
   - Verify all downloads

### Lab Automation Patterns

1. **ISO Caching**
   ```powershell
   # Implement local caching
   function Get-LabISO {
       param($ISOName)

       $cached = Get-ISOInventory -Filter @{Name = $ISOName}

       if (-not $cached) {
           # Download if not cached
           Get-ISODownload -ISOName $ISOName `
                          -DownloadPath $script:CachePath
       }

       return $cached.FilePath
   }
   ```

2. **Version Management**
   ```powershell
   # Maintain multiple versions
   $versions = @('latest', 'stable', 'previous')

   foreach ($version in $versions) {
       Get-ISODownload -ISOName "WindowsServer" `
                      -Version $version `
                      -DownloadPath ".\ISOs\$version"
   }
   ```

### Performance Considerations

1. **Download Optimization**
   - Use BITS on Windows for reliability
   - Implement parallel downloads for multiple files
   - Configure appropriate timeout values
   - Use compression when transferring over WAN

2. **Inventory Performance**
   - Index large repositories
   - Cache metadata locally
   - Use quick scan for large files
   - Implement lazy loading

3. **Sync Optimization**
   - Use differential sync for large repositories
   - Implement bandwidth throttling
   - Schedule syncs during maintenance windows
   - Use compression for network transfers

## Integration Examples

### With ISOCustomizer Module

```powershell
# Download and customize workflow
Import-Module ISOManager, ISOCustomizer

# Download base ISO
$iso = Get-ISODownload -ISOName "WindowsServer2025" `
                      -DownloadPath "C:\ISOs\Base"

# Track in inventory
$metadata = Get-ISOMetadata -FilePath $iso.FilePath

# Create customized version
$customISO = New-CustomISO -SourceISOPath $iso.FilePath `
                          -OutputISOPath "C:\ISOs\Custom\WS2025-Lab.iso" `
                          -AutounattendConfig $config

# Add custom ISO to inventory
Add-ISOToInventory -FilePath $customISO.OutputISO `
                  -Type "Windows-Custom" `
                  -Metadata @{
                      BaseISO = $metadata.Name
                      CustomizationDate = Get-Date
                      Purpose = "Lab Deployment"
                  }
```

### With LabRunner Module

```powershell
# Automated lab deployment with ISO management
function Deploy-LabWithISO {
    param(
        [string]$LabName,
        [string]$ISOName,
        [string]$ISOVersion = "latest"
    )

    # Ensure ISO is available
    $iso = Get-ISOInventory -Filter @{
        Name = $ISOName
        Version = $ISOVersion
    }

    if (-not $iso) {
        # Download if not available
        $download = Get-ISODownload -ISOName $ISOName `
                                   -Version $ISOVersion
        $iso = Get-ISOInventory -Filter @{Name = $ISOName}
    }

    # Deploy lab using ISO
    $labConfig = @{
        Name = $LabName
        ISOPath = $iso.FilePath
        Nodes = @(
            @{Name='DC01'; Memory='4GB'; Disk='60GB'},
            @{Name='APP01'; Memory='8GB'; Disk='100GB'}
        )
    }

    Start-LabDeployment @labConfig
}
```

### Repository Reporting

```powershell
# Generate comprehensive repository report
function New-ISORepositoryReport {
    param([string]$RepositoryPath)

    $inventory = Get-ISOInventory -Path $RepositoryPath -IncludeMetadata

    $report = [PSCustomObject]@{
        Generated = Get-Date
        Repository = $RepositoryPath
        TotalISOs = $inventory.Count
        TotalSize = ($inventory | Measure-Object -Property FileSize -Sum).Sum
        ByType = $inventory | Group-Object Type | Select-Object Name, Count
        ByVersion = $inventory | Group-Object Version | Select-Object Name, Count
        OldestISO = $inventory | Sort-Object DownloadDate | Select-Object -First 1
        NewestISO = $inventory | Sort-Object DownloadDate -Descending | Select-Object -First 1
        ValidationStatus = $inventory | ForEach-Object {
            Test-ISOIntegrity -FilePath $_.FilePath -Quick
        } | Group-Object Valid
    }

    # Export report
    $report | ConvertTo-Json -Depth 10 |
        Set-Content -Path "$RepositoryPath\repository-report-$(Get-Date -Format 'yyyyMMdd').json"

    # Generate HTML report
    ConvertTo-Html -InputObject $report |
        Set-Content -Path "$RepositoryPath\repository-report.html"

    return $report
}
```

## Troubleshooting

### Common Issues

1. **Download Failures**
   ```powershell
   # Enable detailed logging
   $VerbosePreference = 'Continue'
   $DebugPreference = 'Continue'

   # Test with direct download
   Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing

   # Check BITS service (Windows)
   Get-Service BITS | Start-Service
   ```

2. **Integrity Check Failures**
   ```powershell
   # Manually verify hash
   $hash = Get-FileHash -Path $isoPath -Algorithm SHA256

   # Compare with expected
   $expected = "A1B2C3D4..."
   $hash.Hash -eq $expected
   ```

3. **Repository Sync Issues**
   ```powershell
   # Test connectivity
   Test-Path "\\remote\share"
   Test-NetConnection -ComputerName "remote" -Port 445

   # Check permissions
   Get-Acl "\\remote\share"
   ```

4. **Inventory Corruption**
   ```powershell
   # Rebuild inventory
   $files = Get-ChildItem -Path $repoPath -Filter "*.iso" -Recurse

   $newInventory = foreach ($file in $files) {
       Get-ISOMetadata -FilePath $file.FullName
   }

   Export-ISOInventory -Data $newInventory -Path ".\rebuilt-inventory.json"
   ```

### Diagnostic Commands

```powershell
# Check module configuration
Get-ISOManagerConfig

# Validate repository structure
Test-ISORepository -Path "E:\ISOs"

# Check download sources
Get-ISOSource -ListAll

# Test source connectivity
Test-ISOSource -Name "Microsoft"

# Inventory statistics
Get-ISOInventory | Measure-Object -Property FileSize -Sum -Average -Maximum -Minimum
```

## Module Dependencies

- **PowerShell 7.0+**: Required for cross-platform support
- **Logging Module**: For centralized logging
- **BITS Service** (Windows): For reliable downloads
- **SSL/TLS Support**: For secure downloads

## API Reference

### Private Functions

#### Get-WindowsISOUrl
Resolves download URLs for Windows ISOs based on version and parameters.

#### Get-LinuxISOUrl
Resolves download URLs for Linux distribution ISOs.

### Module Variables

- `$script:ISOInventory`: In-memory cache of ISO inventory
- `$script:DownloadQueue`: Queue for managing multiple downloads
- `$script:RepositoryConfig`: Current repository configuration

## See Also

- [ISOCustomizer Module](../ISOCustomizer/README.md)
- [LabRunner Module](../LabRunner/README.md)
- [OpenTofuProvider Module](../OpenTofuProvider/README.md)
- [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/)
- [Ubuntu Releases](https://releases.ubuntu.com/)