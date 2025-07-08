# ISOManager Module v2.0

## Test Status
- **Last Run**: 2025-07-08 18:34:12 UTC
- **Status**: ✅ PASSING (11/11 tests)
- **Coverage**: 0%
- **Platform**: ✅ Windows ✅ Linux ✅ macOS
- **Dependencies**: ✅ All resolved

## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.4s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ❌ FAIL | 43/49 | 0% | 3.6s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 10/10 | 0% | 1s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 0.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
Enterprise-grade ISO download, management, and organization module with advanced storage optimization, modern download capabilities, and
comprehensive integrity validation for automated lab infrastructure deployment.

## Features

### 🚀 Core Capabilities
- **Automated ISO Downloads**: Support for Windows, Linux, and custom ISO downloads with retry logic
- **Repository Management**: Structured ISO organization with metadata tracking
- **Integrity Validation**: Comprehensive checksum and structure verification
- **Storage Optimization**: Duplicate detection, compression, and automated cleanup
- **Cross-Platform**: Full Windows, Linux, and macOS compatibility

### 🔧 Advanced Features
- **Modern Download Methods**: HttpClient, BITS, and enhanced WebRequest with resume support
- **Retry Logic**: Configurable retry attempts with exponential backoff
- **Progress Tracking**: Real-time download and operation progress
- **Metadata Management**: Automatic metadata extraction and cataloging
- **Storage Analytics**: Space usage tracking and optimization recommendations

## Quick Start

### Basic Repository Setup
```powershell
# Import the module
Import-Module ./aither-core/modules/ISOManager -Force

# Create a new ISO repository
$repoResult = New-ISORepository -RepositoryPath "C:\ISOs" -Name "MyLab-ISOs"

# Download a Windows 11 ISO
$downloadResult = Get-ISODownload -ISOName "Windows11" -DownloadPath "C:\ISOs\Windows" -VerifyIntegrity

# Get repository inventory
$inventory = Get-ISOInventory -RepositoryPath "C:\ISOs" -IncludeMetadata
```

### Advanced Download Options
```powershell
# Download with retry logic and modern HTTP client
Get-ISODownload -ISOName "Ubuntu" -ISOType "Linux" -UseHttpClient -RetryCount 5 -TimeoutSeconds 7200

# Download from custom URL with integrity verification
Get-ISODownload -ISOName "CustomOS" -ISOType "Custom" -CustomURL "https://example.com/custom.iso" -VerifyIntegrity

# Resume interrupted download
Get-ISODownload -ISOName "Windows11" -Force  # Will detect partial file and resume
```

## Function Reference

### Download Management

#### Get-ISODownload
Downloads ISO files from various sources with advanced features.

```powershell
Get-ISODownload -ISOName "Windows11" -Version "latest" -Architecture "x64" -Language "en-US" \
    -ISOType "Windows" -DownloadPath "C:\ISOs" -VerifyIntegrity -RetryCount 3 \
    -RetryDelaySeconds 30 -TimeoutSeconds 3600 -UseHttpClient -ShowProgress
```

**Parameters:**
- `ISOName`: Name of the ISO to download
- `Version`: Version to download (default: "latest")
- `Architecture`: Architecture (x64, x86, ARM64)
- `Language`: Language code (default: "en-US")
- `ISOType`: Windows, Linux, or Custom
- `CustomURL`: Direct download URL for custom ISOs
- `DownloadPath`: Download destination
- `VerifyIntegrity`: Verify checksum after download
- `RetryCount`: Number of retry attempts (default: 3)
- `RetryDelaySeconds`: Delay between retries (default: 30)
- `TimeoutSeconds`: Download timeout (default: 3600)
- `UseHttpClient`: Use modern HttpClient instead of BITS
- `ShowProgress`: Display download progress (default: true)
- `Force`: Overwrite existing files

### Repository Management

#### New-ISORepository
Creates a structured ISO repository with proper organization.

```powershell
New-ISORepository -RepositoryPath "C:\ISOs" -Name "Lab-Repository" \
    -Description "Enterprise Lab ISO Repository" -Force
```

#### Sync-ISORepository
Synchronizes repository metadata and validates contents.

```powershell
Sync-ISORepository -RepositoryPath "C:\ISOs" -UpdateMetadata -ValidateIntegrity -CleanupOrphaned
```

### Inventory Management

#### Get-ISOInventory
Retrieves comprehensive inventory of repository contents.

```powershell
# Basic inventory
$inventory = Get-ISOInventory -RepositoryPath "C:\ISOs"

# Detailed inventory with metadata and integrity checks
$detailedInventory = Get-ISOInventory -RepositoryPath "C:\ISOs" \
    -ISOType "All" -IncludeMetadata -VerifyIntegrity
```

#### Export-ISOInventory / Import-ISOInventory
Export and import inventory data in multiple formats.

```powershell
# Export to JSON
Export-ISOInventory -RepositoryPath "C:\ISOs" -ExportPath "inventory.json" \
    -Format "JSON" -IncludeMetadata -IncludeIntegrity

# Import from CSV
Import-ISOInventory -ImportPath "inventory.csv" -TargetRepositoryPath "D:\NewISOs" \
    -ValidateFiles -CreateMissingDirectories
```

### File Operations

#### Test-ISOIntegrity
Performs comprehensive integrity validation.

```powershell
# Basic integrity check
$integrity = Test-ISOIntegrity -FilePath "C:\ISOs\Windows11.iso"

# Advanced validation with structure and mount tests
$validation = Test-ISOIntegrity -FilePath "C:\ISOs\Windows11.iso" \
    -ExpectedChecksum "ABC123..." -ValidateStructure -ValidateMount -Algorithm "SHA256"
```

#### Remove-ISOFile
Safely removes ISO files with backup and cleanup options.

```powershell
# Safe removal with backup
Remove-ISOFile -FilePath "C:\ISOs\old.iso" -BackupBeforeRemove \
    -RemoveMetadata -RemoveEmptyDirectories

# Force removal without backup
Remove-ISOFile -FilePath "C:\ISOs\old.iso" -Force
```

#### Get-ISOMetadata
Extracts comprehensive metadata from ISO files.

```powershell
# Basic metadata
$metadata = Get-ISOMetadata -FilePath "C:\ISOs\Windows11.iso"

# Detailed metadata with volume information
$detailedMetadata = Get-ISOMetadata -FilePath "C:\ISOs\Windows11.iso" \
    -IncludeVolumeInfo -IncludeFileList
```

### Storage Optimization

#### Optimize-ISOStorage
Advanced storage optimization with multiple strategies.

```powershell
# Basic optimization
Optimize-ISOStorage -RepositoryPath "C:\ISOs" -MaxSizeGB 500 -RetentionDays 90

# Comprehensive optimization
Optimize-ISOStorage -RepositoryPath "C:\ISOs" -MaxSizeGB 1000 -RetentionDays 60 \
    -RemoveDuplicates -CompressOldFiles -ArchiveOldFiles -Force

# Dry run to see what would be optimized
Optimize-ISOStorage -RepositoryPath "C:\ISOs" -RemoveDuplicates -DryRun
```

## Supported ISO Sources

### Windows ISOs
- Windows 11 (latest, specific versions)
- Windows 10 (multiple versions)
- Windows Server 2025/2022/2019
- Custom Windows builds

### Linux Distributions
- Ubuntu (Desktop and Server)
- CentOS/RHEL
- Debian
- Fedora
- openSUSE
- Custom Linux distributions

### Custom Sources
- Direct URL downloads
- FTP/HTTP sources
- Enterprise custom builds

## Repository Structure

```
ISO-Repository/
├── Windows/                 # Windows ISO files
├── Linux/                   # Linux distribution ISOs
├── Custom/                  # Custom or third-party ISOs
├── Metadata/               # ISO metadata and catalogs
│   ├── *.metadata.json    # Individual file metadata
│   └── inventory-*.json   # Inventory exports
├── Logs/                   # Operation logs
│   ├── sync-results-*.json
│   └── storage-optimization-*.json
├── Temp/                   # Temporary download files
├── Archive/                # Archived old files
├── Backup/                 # File backups
├── repository.config.json  # Repository configuration
├── README.md              # Repository documentation
└── .gitignore             # Version control exclusions
```

## Configuration Examples

### Repository Configuration
```json
{
  "Name": "Enterprise-Lab-Repository",
  "Description": "Enterprise Lab ISO Repository",
  "Path": "C:\\ISOs",
  "Created": "2025-01-01T00:00:00Z",
  "Version": "2.0.0",
  "Structure": {
    "Windows": "C:\\ISOs\\Windows",
    "Linux": "C:\\ISOs\\Linux",
    "Custom": "C:\\ISOs\\Custom",
    "Metadata": "C:\\ISOs\\Metadata"
  },
  "Configuration": {
    "MaxSizeGB": 1000,
    "RetentionDays": 90,
    "AutoOptimize": true,
    "VerifyIntegrity": true
  },
  "Statistics": {
    "TotalISOs": 25,
    "WindowsISOs": 15,
    "LinuxISOs": 8,
    "CustomISOs": 2,
    "TotalSizeGB": 487.3,
    "LastSynced": "2025-01-01T12:00:00Z"
  }
}
```

### Download Configuration
```powershell
# Configure global download settings
$downloadConfig = @{
    RetryCount = 5
    RetryDelaySeconds = 60
    TimeoutSeconds = 7200
    UseHttpClient = $true
    VerifyIntegrity = $true
    ShowProgress = $true
}

# Apply to download
Get-ISODownload -ISOName "Windows11" @downloadConfig
```

## Integration Examples

### With ISOCustomizer Module
```powershell
# Download and customize Windows ISO
$downloadResult = Get-ISODownload -ISOName "Windows11" -VerifyIntegrity
if ($downloadResult.Status -eq 'Completed') {
    # Use ISOCustomizer to modify the ISO
    Invoke-ISOCustomization -ISOPath $downloadResult.FilePath -ConfigPath "custom-config.json"
}
```

### With Deployment Modules
```powershell
# Automated deployment workflow
$inventory = Get-ISOInventory -RepositoryPath "C:\ISOs" -ISOType "Windows"
$latestWindows = $inventory | Where-Object { $_.Name -like "*Windows11*" } | Sort-Object Modified -Descending | Select-Object -First 1

# Deploy using OpenTofuProvider
Invoke-InfrastructureDeployment -ISOPath $latestWindows.FilePath -DeploymentTemplate "lab-template.tf"
```

### Automation Scripts
```powershell
# Daily maintenance script
function Invoke-DailyISOMaintenace {
    param([string]$RepositoryPath)

    # Sync repository
    $syncResult = Sync-ISORepository -RepositoryPath $RepositoryPath -UpdateMetadata -ValidateIntegrity

    # Optimize storage if needed
    if ($syncResult.Statistics.TotalSizeGB -gt 800) {
        Optimize-ISOStorage -RepositoryPath $RepositoryPath -MaxSizeGB 700 -RemoveDuplicates -ArchiveOldFiles
    }

    # Export inventory for backup
    Export-ISOInventory -RepositoryPath $RepositoryPath -ExportPath "daily-inventory-$(Get-Date -Format 'yyyy-MM-dd').json" -IncludeMetadata
}
```

## Troubleshooting

### Common Issues

#### Download Failures
```powershell
# Check network connectivity
Test-NetConnection -ComputerName "download.microsoft.com" -Port 443

# Verify with different download method
Get-ISODownload -ISOName "Windows11" -UseHttpClient:$false  # Use BITS instead

# Check available disk space
Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DeviceID -eq "C:" }
```

#### Repository Issues
```powershell
# Repair corrupted repository
$repoPath = "C:\ISOs"
if (-not (Test-Path (Join-Path $repoPath "repository.config.json"))) {
    New-ISORepository -RepositoryPath $repoPath -Force
}

# Fix metadata inconsistencies
Sync-ISORepository -RepositoryPath $repoPath -UpdateMetadata -CleanupOrphaned
```

#### Performance Issues
```powershell
# Monitor repository size
$inventory = Get-ISOInventory -RepositoryPath "C:\ISOs"
$totalSize = ($inventory | Measure-Object -Property Size -Sum).Sum / 1GB
Write-Host "Repository size: $([math]::Round($totalSize, 2)) GB"

# Optimize for performance
Optimize-ISOStorage -RepositoryPath "C:\ISOs" -RemoveDuplicates -CompressOldFiles -DryRun
```

### Log Analysis
```powershell
# Check recent logs
$logPath = Join-Path "C:\ISOs" "Logs"
Get-ChildItem $logPath -Filter "*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# Analyze sync results
$latestSync = Get-Content (Join-Path $logPath "sync-results-*.json") | ConvertFrom-Json
Write-Host "Last sync: $($latestSync.TotalISOs) files, $($latestSync.Errors.Count) errors"
```

## Advanced Topics

### Custom Download Sources
```powershell
# Add custom Linux distribution
# Modify Private/Get-LinuxISOUrl.ps1 to add new distributions
$customDistros = @{
    'AlmaLinux' = @{
        'latest' = @{
            'x64' = 'https://repo.almalinux.org/almalinux/9/isos/x86_64/AlmaLinux-9-latest-x86_64-dvd.iso'
        }
    }
}
```

### Storage Policies
```powershell
# Implement custom storage policy
function Invoke-CustomStoragePolicy {
    param($RepositoryPath, $PolicyConfig)

    $inventory = Get-ISOInventory -RepositoryPath $RepositoryPath

    # Apply retention policy
    $cutoffDate = (Get-Date).AddDays(-$PolicyConfig.RetentionDays)
    $oldFiles = $inventory | Where-Object { $_.Modified -lt $cutoffDate }

    foreach ($file in $oldFiles) {
        if ($PolicyConfig.ArchiveOldFiles) {
            # Move to archive
        } elseif ($PolicyConfig.DeleteOldFiles) {
            Remove-ISOFile -FilePath $file.FilePath -Force
        }
    }
}
```

### Monitoring and Alerts
```powershell
# Set up repository monitoring
function Test-RepositoryHealth {
    param($RepositoryPath)

    $issues = @()

    # Check repository structure
    $requiredDirs = @('Windows', 'Linux', 'Metadata', 'Logs')
    foreach ($dir in $requiredDirs) {
        if (-not (Test-Path (Join-Path $RepositoryPath $dir))) {
            $issues += "Missing directory: $dir"
        }
    }

    # Check disk space
    $drive = Split-Path $RepositoryPath -Qualifier
    $disk = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $drive }
    $freeSpaceGB = $disk.FreeSpace / 1GB

    if ($freeSpaceGB -lt 50) {
        $issues += "Low disk space: $([math]::Round($freeSpaceGB, 2)) GB remaining"
    }

    return $issues
}
```

## Contributing

To contribute to the ISOManager module:

1. Fork the repository
2. Create a feature branch
3. Add comprehensive tests
4. Update documentation
5. Submit a pull request

### Running Tests
```powershell
# Run module tests
Invoke-Pester ./aither-core/modules/ISOManager/tests/ISOManager.Tests.ps1

# Run integration tests
./tests/Run-Tests.ps1 -Module ISOManager
```

## License

This module is part of the AitherZero project and follows the project's licensing terms.

---

**Note**: This module requires PowerShell 7.0+ and integrates with the AitherZero logging system. For production use, ensure proper network
access and sufficient storage space for ISO repositories.