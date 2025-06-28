# BackupManager Module

Comprehensive backup management module for the OpenTofu Lab Automation project, following project maintenance standards and integrating with the unified maintenance system.

## Overview

The BackupManager module consolidates all backup-related functionality into a single, well-structured PowerShell module that provides:

- **Backup file consolidation** - Centrally manages all backup files
- **Permanent cleanup** - Removes problematic files and prevents their recreation
- **Statistics and analysis** - Provides insights into backup file distribution
- **Integration with unified maintenance** - Seamlessly works with existing project tools
- **Cross-platform compatibility** - Works on Windows, Linux, and macOS

## Installation

The module is automatically available when you import it:

```powershell
Import-Module "/pwsh/modules/BackupManager/" -Force
```

## Functions

### Invoke-BackupMaintenance

Main function that orchestrates all backup management tasks.

```powershell
# Quick maintenance
Invoke-BackupMaintenance -ProjectRoot "." -Mode "Quick"

# Full maintenance with auto-fixes
Invoke-BackupMaintenance -ProjectRoot "." -Mode "Full" -AutoFix

# Emergency cleanup (destructive)
Invoke-BackupMaintenance -ProjectRoot "." -Mode "Emergency" -AutoFix
```

**Modes:**
- **Quick**: Basic consolidation and health check
- **Full**: Consolidation, permanent cleanup, and exclusion updates
- **Emergency**: Aggressive cleanup including duplicate workflows

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

## Usage Examples

### Quick Cleanup

```powershell
# Import module
Import-Module "/pwsh/modules/BackupManager/" -Force

# Run comprehensive maintenance
Invoke-BackupMaintenance -ProjectRoot "." -Mode "Full" -AutoFix
```

### Analysis Before Cleanup

```powershell
# Get current situation
$stats = Get-BackupStatistics -ProjectRoot "." -IncludeDetails

# Review recommendations
$stats.Recommendations

# Act on findings
if ($stats.TotalFiles -gt 50) {
    Invoke-BackupConsolidation -ProjectRoot "." -Force
}
```

### Emergency Cleanup

```powershell
# For development environments only - this is destructive!
Invoke-BackupMaintenance -ProjectRoot "." -Mode "Emergency" -AutoFix
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

## Best Practices

1. **Always run statistics first** to understand what will be affected
2. **Use Force parameter carefully** - review changes before applying
3. **Emergency mode is destructive** - only use in development environments
4. **Integrate with unified maintenance** for consistent project management
5. **Regular maintenance** prevents backup file accumulation

## Contributing

When adding new functions:

1. Place public functions in `Public/` directory
2. Follow existing parameter patterns and error handling
3. Include comprehensive help documentation
4. Test with both LabRunner and standalone scenarios
5. Update this README with new functionality

## Version History

- **1.0.0**: Initial release with core backup management functionality

## Related

- Unified Maintenance System(../../scripts/maintenance/)
- LabRunner Module(../LabRunner/)
- CodeFixer Module(../CodeFixer/)
- Project Maintenance Standards(../../.github/instructions/maintenance-standards.instructions.md)
