# Tools Directory Cleanup - Migration Guide

**Date**: 2025-11-08  
**Status**: ✅ Complete  
**Impact**: Medium - Script path changes, documentation updates

## Overview

This document describes the reorganization of the `/tools` directory, where utility scripts were migrated to the `automation-scripts/` directory to better integrate with AitherZero's number-based orchestration system.

## Motivation

The tools directory contained a mix of:
1. **Build/infrastructure utilities** - Required by bootstrap and build processes
2. **User-facing automation utilities** - Should be part of the main automation system

This cleanup separates these concerns clearly:
- **tools/** = Build and infrastructure only
- **automation-scripts/** = All user-facing automation (including former tools)

## Benefits

### 1. **Better Discoverability**
Scripts are now discoverable through the main automation system:
```powershell
# Old way (hidden in tools/)
./tools/Setup-GitHooks.ps1

# New way (integrated with aitherzero)
aitherzero 0004
az 0004
./automation-scripts/0004_Setup-GitHooks.ps1
```

### 2. **Orchestration Support**
Moved scripts can now be used in playbooks and sequences:
```powershell
# Can include in playbooks
stages:
  - name: "Environment Setup"
    sequences: ["0004"]  # Setup git hooks
```

### 3. **Consistency**
All scripts follow the same conventions:
- Numbered (0000-9999)
- Metadata headers (Stage, Dependencies, Tags)
- Part of script inventory
- Discoverable in menus and help

### 4. **Clearer Purpose**
The tools/ directory now has a clear, focused purpose:
- Build and packaging (AitherCore)
- Global command installation
- Bootstrap infrastructure

## Script Migrations

### Environment Setup (0000-0099)

| Old Path | New Path | Description |
|----------|----------|-------------|
| `tools/Setup-GitHooks.ps1` | `0004_Setup-GitHooks.ps1` | Git hooks + merge config |
| `tools/setup-git-merge.sh` | *(integrated above)* | Bash merge config merged into 0004 |

**Usage**:
```powershell
# Setup git hooks and merge strategy
aitherzero 0004
```

### Testing & Quality (0400-0499)

| Old Path | New Path | Description |
|----------|----------|-------------|
| `tools/Validate-ModuleManifest.ps1` | `0416_Validate-ModuleManifest.ps1` | Validate .psd1 files |
| `tools/Validate-TestDiscoveryFix.ps1` | `0427_Validate-TestDiscoveryFix.ps1` | Test discovery validation |
| `tools/Get-AutomationTestCoverage.ps1` | `0428_Get-AutomationTestCoverage.ps1` | Test coverage analysis |

**Usage**:
```powershell
# Validate a module manifest
az 0416 -Path ./AitherZero.psd1

# Check test discovery
az 0427

# Get test coverage report
az 0428 -ShowUntested -OutputFormat Html
```

### Issue Management (0800-0899)

| Old Path | New Path | Description |
|----------|----------|-------------|
| `tools/Validate-WorkflowIntegration.ps1` | `0841_Validate-WorkflowIntegration.ps1` | Workflow validation |

**Usage**:
```powershell
# Validate workflow integration
az 0841
```

### Quality & Validation (0900-0999)

| Old Path | New Path | Description |
|----------|----------|-------------|
| `tools/migrate-playbooks-v2.ps1` | `0968_Migrate-PlaybooksV2.ps1` | Playbook migration |

**Usage**:
```powershell
# Migrate v1 playbooks to v2 format
az 0968 -InputPath ./old-playbooks -OutputPath ./new-playbooks
```

## Remaining in tools/

These files stay in tools/ because they're part of the build/bootstrap infrastructure:

| File | Purpose | Used By |
|------|---------|---------|
| `aitherzero-launcher.ps1` | Global launcher script | Global `aitherzero` command |
| `Build-AitherCorePackage.ps1` | AitherCore distribution builder | Release workflows |
| `Install-GlobalCommand.ps1` | Global command installer | `bootstrap.ps1` |
| `BUILD-README.md` | Build documentation | Developers |
| `index.md` | Directory index | Documentation system |

## Breaking Changes

### Script Paths
If you have custom scripts or documentation referencing the old paths, update them:

```bash
# Old references
./tools/Setup-GitHooks.ps1
./tools/Validate-ModuleManifest.ps1 -Path ./config.psd1

# New references  
./automation-scripts/0004_Setup-GitHooks.ps1
./automation-scripts/0416_Validate-ModuleManifest.ps1 -Path ./config.psd1

# Or use the aitherzero command
aitherzero 0004
aitherzero 0416 -Path ./config.psd1
```

### Script Numbers
The scripts now have unique numbers that don't conflict with existing automation scripts:
- 0004 (not 0003 - conflict with Sync-ConfigManifest)
- 0416 (not 0413 or 0414 - conflicts with existing scripts)
- 0428 (not 0426 - conflict with Validate-TestScriptSync)

## Migration Checklist

If you're updating custom code or documentation:

- [ ] Update script paths from `tools/` to `automation-scripts/`
- [ ] Use new script numbers (see table above)
- [ ] Update workflow references (if any)
- [ ] Update documentation that mentions old paths
- [ ] Test custom scripts/workflows with new paths

## Updated Files

### Core Repository Files
- `README.md` - Updated setup instructions
- `config.psd1` - Updated script inventory counts
- `automation-scripts/0405_Validate-ModuleManifests.ps1` - Updated validation script path
- `.github/workflows/validate-manifests.yml` - Updated workflow paths

### Documentation
- `docs/troubleshooting/MODULE_MANIFEST_UNICODE_ISSUES.md` - Updated script references
- `tools/index.md` - Updated to reflect new structure

## Testing

All changes have been validated:

✅ Config validation passes (`0413_Validate-ConfigManifest.ps1`)  
✅ Syntax validation passes (`0407_Validate-Syntax.ps1 -All`)  
✅ Moved scripts execute correctly  
✅ Script inventory accurate (150 unique scripts)  
✅ No duplicate script numbers  
✅ All references updated

## Examples

### Before (Old Structure)
```powershell
# Various ways to call scripts
./tools/Setup-GitHooks.ps1
./tools/Get-AutomationTestCoverage.ps1 -ShowUntested
./tools/Validate-ModuleManifest.ps1 -Path ./AitherZero.psd1

# Not discoverable in menus or playbooks
# Not part of the number-based system
```

### After (New Structure)
```powershell
# Consistent numbering system
aitherzero 0004  # Setup git hooks
aitherzero 0428 -ShowUntested  # Test coverage
aitherzero 0416 -Path ./AitherZero.psd1  # Validate manifest

# Also works with direct paths
./automation-scripts/0004_Setup-GitHooks.ps1
./automation-scripts/0428_Get-AutomationTestCoverage.ps1 -ShowUntested

# Can be used in playbooks
stages:
  - name: "Quality Checks"
    sequences: ["0416", "0427", "0428"]
```

## Summary

This cleanup resulted in:
- 6 scripts moved from tools/ to automation-scripts/
- 1 bash script integrated into PowerShell
- 5 files remaining in tools/ (build/infrastructure only)
- 150 total automation scripts (from 144)
- Better organization and discoverability
- Full integration with orchestration system

The tools/ directory now has a clear, focused purpose: build and infrastructure utilities that support the AitherZero platform itself.

## Questions?

If you encounter issues with the migration:
1. Check this document for the new script paths/numbers
2. Run `aitherzero 0413` to validate config
3. See updated documentation in the respective script headers
4. Open an issue if you find a missed reference

---

**Migration completed**: 2025-11-08  
**Validated by**: Config validation, syntax checks, manual testing  
**Documentation**: This file, README.md, tools/index.md
