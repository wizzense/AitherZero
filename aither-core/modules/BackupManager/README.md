# BackupManager Module v2.0

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
| Unit Tests | ❌ FAIL | 18/20 | 75% | 5.1s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
Enterprise-grade backup management system for the AitherZero project, providing comprehensive automation, security, and disaster recovery capabilities.

## Overview

The BackupManager v2.0 module provides a complete backup ecosystem with modern enterprise features:

### Core Features
- **Advanced Backup Operations** - Compression, encryption, and deduplication
- **Automated Backup Scheduling** - Enterprise-grade scheduling with monitoring
- **Backup Consolidation** - Centralized management of scattered backup files
- **Disaster Recovery** - Complete restoration and verification capabilities
- **Retention Management** - Intelligent lifecycle and cleanup policies
- **Security Integration** - AES encryption and secure credential management
- **Cross-platform Support** - Windows, Linux, and macOS compatibility
- **Performance Optimization** - Parallel processing and storage efficiency

## Installation

The module is automatically available when you import it:

```powershell
Import-Module "/pwsh/modules/BackupManager/" -Force
```

## Core Functions

### 🚀 Invoke-AdvancedBackup

Enterprise-grade backup operations with modern features.

```powershell
# Basic advanced backup with compression
Invoke-AdvancedBackup -SourcePath "./src" -BackupPath "./backups/daily" -CompressionLevel 6

# Secure backup with encryption and deduplication
Invoke-AdvancedBackup -SourcePath "./data" -BackupPath "./secure-backups" -EnableEncryption -EnableDeduplication -VerifyIntegrity

# High-performance backup with parallel processing
Invoke-AdvancedBackup -SourcePath "./large-dataset" -BackupPath "./backups" -MaxConcurrency 8 -CompressionLevel 9
```

**Features:**
- **Compression**: 0-9 levels using modern algorithms
- **Encryption**: AES encryption for sensitive data
- **Deduplication**: Storage optimization through file deduplication
- **Verification**: Integrity checking and validation
- **Parallel Processing**: Multi-threaded operations for performance

### 🔄 Start-AutomatedBackup

Enterprise scheduling and monitoring system.

```powershell
# Daily automated backups with monitoring
Start-AutomatedBackup -SourcePaths @("./src", "./config") -BackupPath "./automated-backups" -Schedule Daily -EnableMonitoring -RetentionDays 30

# Secure automated backups with encryption
Start-AutomatedBackup -SourcePaths @("./sensitive-data") -BackupPath "./secure-auto" -Schedule Hourly -EnableEncryption -NotificationEmail "admin@company.com"
```

**Capabilities:**
- **Flexible Scheduling**: Hourly, Daily, Weekly, Monthly, Custom
- **Health Monitoring**: Automated health checks and alerts
- **Retention Policies**: Intelligent cleanup and space management
- **Cross-Platform**: Windows Task Scheduler and Linux/macOS cron integration

### 🔄 Restore-BackupData

Complete disaster recovery and restoration system.

```powershell
# Basic restoration
Restore-BackupData -BackupPath "./backups/2024-01-15" -RestorePath "./restored-data"

# Selective restoration with verification
Restore-BackupData -BackupPath "./backups/latest" -RestorePath "./restored" -SelectiveRestore @("*.config", "*.json") -VerifyRestore

# Encrypted backup restoration
Restore-BackupData -BackupPath "./secure-backups" -RestorePath "./restored" -EncryptionKey $secureKey -VerifyRestore
```

### 📊 Invoke-BackupMaintenance

Comprehensive maintenance orchestration.

```powershell
# Quick maintenance
Invoke-BackupMaintenance -Mode "Quick"

# Full maintenance with statistics
Invoke-BackupMaintenance -Mode "Full" -AutoFix

# Statistics-only mode
Invoke-BackupMaintenance -Mode "Statistics" -OutputFormat "JSON"
```

**Modes:**
- **Quick**: Basic consolidation and health check
- **Full**: Complete maintenance with cleanup and statistics
- **Cleanup**: Focus on retention and cleanup operations
- **Statistics**: Comprehensive analysis and reporting

### Invoke-BackupConsolidation

Consolidates scattered backup files into a centralized location.

```powershell
# Consolidate all backup files
Invoke-BackupConsolidation -ProjectRoot "." -Force

# Consolidate with custom exclusions
Invoke-BackupConsolidation -ProjectRoot "." -ExcludePaths @("special/*") -Force
```

**Features:**
- Automatically excludes git, node_modules, and existing backup directories
- Organizes files by date and original location
- Handles naming conflicts with timestamps
- Provides detailed progress reporting

### Invoke-PermanentCleanup

Permanently removes problematic files and creates prevention rules.

```powershell
# Standard cleanup
Invoke-PermanentCleanup -ProjectRoot "." -CreatePreventionRules -Force

# Custom problematic patterns
$patterns = @("*.corrupt", "*-duplicate-*")
Invoke-PermanentCleanup -ProjectRoot "." -ProblematicPatterns $patterns -Force
```

**Targets:**
- Duplicate backup files (*.bak.bak, *.backup.backup)
- Corrupted or incomplete files
- OS-generated files (Thumbs.db, .DS_Store)
- Legacy and deprecated files
- Test artifacts that shouldn't persist

### Get-BackupStatistics

Analyzes backup files and provides comprehensive statistics.

```powershell
# Basic statistics
Get-BackupStatistics -ProjectRoot "."

# Detailed analysis with file list
Get-BackupStatistics -ProjectRoot "." -IncludeDetails
```

**Provides:**
- File counts and sizes
- Age distribution
- File type breakdown
- Directory distribution
- Actionable recommendations

### New-BackupExclusion

Updates configuration files to exclude backup files from validation and version control.

```powershell
# Update standard configuration files
New-BackupExclusion -ProjectRoot "." 

# Add custom patterns
New-BackupExclusion -ProjectRoot "." -Patterns @("*.temp", "*.cache")
```

**Updates:**
- `.gitignore` - Excludes from version control
- `.PSScriptAnalyzerSettings.psd1` - Excludes from linting
- `Pester.config.ps1` - Excludes from test discovery

## Integration with Unified Maintenance

To integrate BackupManager with the project's unified maintenance system:

```powershell
./scripts/maintenance/integrate-backup-manager.ps1 -Mode "Full" -Force
```

After integration, backup management is automatically included when running:

```powershell
./scripts/maintenance/unified-maintenance.ps1 -Mode "All"
```

## 🎯 Enterprise Workflow Examples

### Daily Operations Workflow

```powershell
# 1. Morning backup health check
$healthCheck = Invoke-BackupMaintenance -Mode "Statistics" -OutputFormat "JSON" | ConvertFrom-Json
Write-Host "Backup Health: $($healthCheck.Statistics.TotalFiles) files, Last Success: $($healthCheck.LastSuccess)"

# 2. Automated daily backup with monitoring
Start-AutomatedBackup `
    -SourcePaths @("./src", "./configs", "./docs") `
    -BackupPath "./daily-backups" `
    -Schedule Daily `
    -EnableMonitoring `
    -EnableEncryption `
    -RetentionDays 30 `
    -CompressionLevel 6

# 3. Weekly full maintenance
if ((Get-Date).DayOfWeek -eq "Sunday") {
    Invoke-BackupMaintenance -Mode "Full" -AutoFix
}
```

### Disaster Recovery Workflow

```powershell
# 1. Create secure backup before major changes
Invoke-AdvancedBackup `
    -SourcePath "./production-data" `
    -BackupPath "./disaster-recovery/$(Get-Date -Format 'yyyy-MM-dd-HH-mm')" `
    -EnableEncryption `
    -EnableDeduplication `
    -VerifyIntegrity `
    -CompressionLevel 9

# 2. Test restoration to verify backup integrity
Restore-BackupData `
    -BackupPath "./disaster-recovery/latest" `
    -RestorePath "./test-restore" `
    -VerifyRestore `
    -EncryptionKey $secureKey

# 3. Clean up test restoration
Remove-Item "./test-restore" -Recurse -Force
```

### Development Environment Setup

```powershell
# 1. Setup automated development backups
Start-AutomatedBackup `
    -SourcePaths @("./src", "./tests", "./.vscode") `
    -BackupPath "./dev-backups" `
    -Schedule Hourly `
    -RetentionDays 7 `
    -CompressionLevel 3

# 2. Daily cleanup and consolidation
Invoke-BackupMaintenance -Mode "Quick" -AutoFix

# 3. Weekly statistics review
$stats = Get-BackupStatistics -ProjectRoot "." -IncludeDetails
$stats | ConvertTo-Json | Out-File "./reports/backup-stats.json"
```

### Emergency Recovery Procedures

```powershell
# CRITICAL: System failure recovery
# 1. Identify latest good backup
$backups = Get-ChildItem "./backups" | Sort-Object LastWriteTime -Descending

# 2. Restore critical systems first
Restore-BackupData `
    -BackupPath $backups[0].FullName `
    -RestorePath "./emergency-restore" `
    -SelectiveRestore @("*.config", "*.json", "*.ps1") `
    -VerifyRestore `
    -OverwriteExisting

# 3. Verify system integrity
Test-Path "./emergency-restore/critical-config.json" | Should -Be $true
```

## File Organization

```
pwsh/modules/BackupManager/
├── BackupManager.psd1          # Module manifest
├── BackupManager.psm1          # Module loader
├── Public/                     # Exported functions
│   ├── Invoke-BackupMaintenance.ps1
│   ├── Invoke-BackupConsolidation.ps1
│   ├── Invoke-PermanentCleanup.ps1
│   ├── Get-BackupStatistics.ps1
│   └── New-BackupExclusion.ps1
└── Private/                    # Internal functions (future)
```

## Configuration

The module uses these default settings:

- **Backup root**: `backups/consolidated-backups/`
- **Archive path**: `archive/`
- **Max backup age**: 30 days
- **Default exclusions**: Git, node_modules, VS Code, existing backups

## Backup File Patterns

The module recognizes these backup patterns:

- `*.bak`, `*.backup`, `*.old`, `*.orig`, `*~`
- `*backup*`, `*-backup-*`
- `*.bak.*`, `*.backup.*`

## Error Handling

All functions include comprehensive error handling with:

- Try-catch blocks for all operations
- Detailed error messages with context
- Integration with LabRunner logging when available
- Graceful fallback to standard PowerShell logging

## Logging Integration

When LabRunner module is available:

```powershell
Import-Module "/pwsh/modules/LabRunner/" -Force
Import-Module "/pwsh/modules/BackupManager/" -Force

# BackupManager will automatically use Write-CustomLog
Invoke-BackupMaintenance -ProjectRoot "." -Mode "Full"
```

## 🏆 Best Practices & Security Guidelines

### Backup Strategy Best Practices

#### 1. **3-2-1 Backup Rule Implementation**
```powershell
# 3 copies of data: Original + 2 backups
Invoke-AdvancedBackup -SourcePath "./data" -BackupPath "./local-backup" -EnableDeduplication
Invoke-AdvancedBackup -SourcePath "./data" -BackupPath "./offsite-backup" -EnableEncryption -CompressionLevel 9
```

#### 2. **Tiered Backup Schedule**
```powershell
# Hourly: Critical data only
Start-AutomatedBackup -SourcePaths @("./critical") -Schedule Hourly -RetentionDays 3

# Daily: Full development environment
Start-AutomatedBackup -SourcePaths @("./src", "./config") -Schedule Daily -RetentionDays 30

# Weekly: Complete system state
Start-AutomatedBackup -SourcePaths @("./") -Schedule Weekly -RetentionDays 90 -EnableEncryption
```

#### 3. **Security-First Approach**
```powershell
# Always encrypt sensitive data
$secureKey = ConvertTo-SecureString "YourSecurePassword" -AsPlainText -Force
Invoke-AdvancedBackup -SourcePath "./sensitive" -BackupPath "./secure" -EnableEncryption -EncryptionKey $secureKey

# Use exclusion rules to prevent credential leakage
New-BackupExclusion -Patterns @("*.key", "*.pfx", "credentials.json", ".env") -Force
```

### Performance Optimization

#### 1. **Large Dataset Handling**
```powershell
# Optimize for large files with high compression and parallelism
Invoke-AdvancedBackup `
    -SourcePath "./large-dataset" `
    -BackupPath "./optimized-backup" `
    -CompressionLevel 9 `
    -MaxConcurrency 8 `
    -EnableDeduplication
```

#### 2. **Network-Attached Storage**
```powershell
# Lower compression for network storage to reduce CPU overhead
Invoke-AdvancedBackup `
    -SourcePath "./data" `
    -BackupPath "\\network-storage\backups" `
    -CompressionLevel 3 `
    -MaxConcurrency 2
```

### Monitoring and Alerting

#### 1. **Health Monitoring Setup**
```powershell
# Enable comprehensive monitoring
Start-AutomatedBackup `
    -SourcePaths @("./production") `
    -BackupPath "./monitored-backups" `
    -EnableMonitoring `
    -NotificationEmail "ops-team@company.com" `
    -MaxBackupSize 50.0 `
    -Schedule Daily
```

#### 2. **Custom Health Checks**
```powershell
# Daily health validation script
$stats = Get-BackupStatistics -ProjectRoot "." -IncludeDetails
if ($stats.TotalFiles -eq 0) {
    Send-MailMessage -To "admin@company.com" -Subject "ALERT: No backup files found"
}
```

### Disaster Recovery Planning

#### 1. **Recovery Time Objectives (RTO)**
```powershell
# Critical systems: < 1 hour recovery
# - Keep uncompressed backups for fastest restore
# - Use local storage for critical data
Invoke-AdvancedBackup -SourcePath "./critical" -BackupPath "./fast-restore" -CompressionLevel 0

# Standard systems: < 4 hour recovery
# - Balanced compression and performance
Invoke-AdvancedBackup -SourcePath "./standard" -BackupPath "./balanced-restore" -CompressionLevel 6
```

#### 2. **Regular Disaster Recovery Testing**
```powershell
# Monthly DR test procedure
$testRestorePath = "./dr-test-$(Get-Date -Format 'yyyy-MM')"
Restore-BackupData -BackupPath "./production-backup" -RestorePath $testRestorePath -VerifyRestore

# Validate critical services
Test-Path "$testRestorePath/critical-service.exe" | Should -Be $true
```

### Integration Guidelines

#### 1. **CI/CD Pipeline Integration**
```powershell
# Pre-deployment backup
Invoke-AdvancedBackup `
    -SourcePath "./deployment-ready" `
    -BackupPath "./pre-deploy-backups/$(Get-Date -Format 'yyyy-MM-dd-HH-mm')" `
    -EnableEncryption `
    -VerifyIntegrity

# Post-deployment verification
$verifyResult = Restore-BackupData -BackupPath "./latest-backup" -RestorePath "./verify" -VerifyRestore
if (-not $verifyResult.VerificationResult.Success) {
    throw "Backup verification failed - deployment rollback required"
}
```

#### 2. **Compliance and Audit Requirements**
```powershell
# Generate audit trail
$auditReport = @{
    Timestamp = Get-Date
    BackupInventory = Get-BackupStatistics -ProjectRoot "." -IncludeDetails
    RetentionCompliance = Test-RetentionCompliance
    SecurityScan = Test-BackupSecurity
}
$auditReport | ConvertTo-Json -Depth 10 | Out-File "./compliance/backup-audit-$(Get-Date -Format 'yyyy-MM').json"
```

### Common Pitfalls to Avoid

❌ **Don't:**
- Store backups on the same drive as source data
- Use weak encryption or store keys with backups
- Skip verification of backup integrity
- Ignore backup failure notifications
- Mix production and development backup schedules

✅ **Do:**
- Test restoration procedures regularly
- Monitor backup performance and adjust accordingly
- Use separate storage locations for different backup tiers
- Implement automated health checks
- Document disaster recovery procedures
- Regularly review and update retention policies

## Contributing

When adding new functions:

1. Place public functions in `Public/` directory
2. Follow existing parameter patterns and error handling
3. Include comprehensive help documentation
4. Test with both LabRunner and standalone scenarios
5. Update this README with new functionality

## 📊 Version History

### v2.0.0 - Enterprise Enhancement Release
- **🚀 NEW**: Advanced backup operations with compression, encryption, and deduplication
- **🚀 NEW**: Automated backup scheduling and monitoring system  
- **🚀 NEW**: Complete disaster recovery and restoration capabilities
- **🚀 NEW**: Performance optimization with parallel processing
- **✨ Enhanced**: Cross-platform compatibility and security features
- **✨ Enhanced**: Comprehensive testing framework with 57 test cases
- **✨ Enhanced**: Enterprise-grade documentation and best practices
- **🔧 Fixed**: Integration issues and improved error handling
- **🔧 Fixed**: PowerShell 7+ compatibility and modern syntax

### v1.0.0 - Initial Release  
- Basic backup management functionality
- File consolidation and cleanup operations
- Statistics and analysis capabilities

## Related

- Unified Maintenance System(../../scripts/maintenance/)
- LabRunner Module(../LabRunner/)
- CodeFixer Module(../CodeFixer/)
- Project Maintenance Standards(../../.github/instructions/maintenance-standards.instructions.md)