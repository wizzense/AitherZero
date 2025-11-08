# Playbook Migration Guide

**Version**: 2.0  
**Date**: 2025-11-02  
**Status**: Active

## Overview

This guide helps you migrate from the legacy playbook structure to the new consolidated core playbooks. The consolidation reduces 42 playbooks to ~23 focused core playbooks with improved organization and standardization.

## What Changed?

### Structure
- **Before**: Flat structure with 42 playbooks across multiple categories
- **After**: Organized `core/` directory with 8 category subdirectories
- **Schema**: All new playbooks use v2.0 format with enhanced metadata

### Key Improvements
1. **Reduced Duplication**: 11 testing playbooks → 5 core playbooks
2. **Clear Organization**: Category-based directory structure
3. **Profile Support**: Multiple profiles per playbook for different scenarios
4. **Enhanced Metadata**: Better documentation and requirements
5. **Consistent Naming**: Standardized naming conventions

## Migration Mapping

### Testing Playbooks

| Legacy Playbook | New Playbook | Profile | Notes |
|----------------|--------------|---------|-------|
| test-lightning | test-quick | lightning | Ultra-fast mode |
| test-simple | test-quick | lightning | Same as lightning |
| test-quick | test-quick | standard | Default profile |
| test-validation | test-standard | standard | Pre-commit validation |
| test-comprehensive | test-standard | thorough | More complete |
| comprehensive-validation | test-full | standard | With coverage |
| test-full | test-full | standard | Complete suite |
| test-ci | test-ci | standard | CI/CD optimized |
| workflow-validation | workflow-validation | standard | Kept as-is |
| test-phase1-validation | ⚠️ ARCHIVED | - | Legacy/deprecated |
| test-phase1-production | ⚠️ ARCHIVED | - | Legacy/deprecated |

**Migration Commands:**
```powershell
# Before
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-lightning

# After
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick -PlaybookProfile lightning

# Before
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-comprehensive

# After
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-standard
```

### Git Workflow Playbooks

| Legacy Playbook | New Playbook | Notes |
|----------------|--------------|-------|
| claude-feature-workflow | git-feature | Enhanced with profiles |
| ai-complete-workflow | git-feature | Consolidated |
| ai-git-workflow | git-feature | Merged features |
| claude-commit-workflow | git-commit | Simple commit workflow |
| git-workflow | git-commit | Standardized |
| git-standard-workflow | git-standard | Kept, updated to v2.0 |
| claude-development-workflow | ⚠️ SPLIT | → git-feature + setup playbooks |

**Migration Commands:**
```powershell
# Before
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook claude-feature-workflow

# After
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook git-feature

# Before  
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ai-complete-workflow

# After
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook git-feature
```

### Setup Playbooks

**No changes** - All 4 setup playbooks remain:

| Playbook | Status | Location |
|----------|--------|----------|
| minimal-setup | ✅ Kept | core/setup/ |
| dev-environment | ✅ Kept | core/setup/ |
| full-development | ✅ Kept | core/setup/ |
| ai-development | ✅ Kept | core/setup/ |

These will be moved to `core/setup/` and updated to v2.0 schema.

### Infrastructure Playbooks

| Legacy Playbook | New Playbook | Notes |
|----------------|--------------|-------|
| hyperv-lab-setup | hyperv-lab-setup | Moved to core/infrastructure/ |
| N/A | infrastructure-minimal | NEW - Basic system config |
| N/A | infrastructure-wsl | NEW - WSL2 + Docker |

**New Capabilities:**
```powershell
# Basic system configuration (cross-platform)
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook infrastructure-minimal

# WSL2 development environment (Windows)
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook infrastructure-wsl
```

### Development Tools

**NEW Category** - Separated from setup:

| Playbook | Purpose |
|----------|---------|
| devtools-minimal | Essential: Git, Node, Docker, Python |
| devtools-full | Complete: + VS Code, CLIs, build tools |

**Usage:**
```powershell
# Essential tools
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook devtools-minimal

# Complete toolchain
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook devtools-full
```

### Operations Playbooks

| Legacy Playbook | New Playbook | Notes |
|----------------|--------------|-------|
| github-cicd | ci-pipeline | Consolidated |
| intelligent-ci-cd | ci-pipeline | Merged features |
| ai-assisted-deployment | deployment | Simplified |
| automated-issue-creation | ci-pipeline | Stage within pipeline |
| session-management | session-management | Kept as-is |

### Analysis Playbooks

**No consolidation** - All 4 kept as-is:
- automated-security-review
- claude-code-review
- tech-debt-analysis
- reporting-automation

Will be moved to `core/analysis/` and updated to v2.0.

### AI Workflow Playbooks

| Legacy Playbook | New Playbook | Notes |
|----------------|--------------|-------|
| claude-custom-agent-personas | ai-agent-personas | Renamed |
| claude-multi-agent-orchestration | ai-orchestration | Consolidated |
| claude-sub-agent-delegation | ai-orchestration | Merged |
| claude-intelligent-automation | ai-orchestration | Merged |
| claude-custom-commands | ai-commands | Renamed |

## Step-by-Step Migration

### 1. Update Scripts and Automation

Search your codebase for legacy playbook references:

```powershell
# Find all playbook references
git grep -n "test-lightning\|test-simple\|claude-feature"

# Update to new names
# test-lightning → test-quick -PlaybookProfile lightning
# claude-feature-workflow → git-feature
```

### 2. Update Documentation

Update any documentation that references playbooks:

```powershell
# Find documentation references
git grep -l "test-comprehensive\|ai-complete-workflow" -- "*.md"

# Update with new playbook names and profiles
```

### 3. Update CI/CD Pipelines

GitHub Actions, Azure Pipelines, etc.:

```yaml
# Before
- name: Run Tests
  run: ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-comprehensive

# After
- name: Run Tests
  run: ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-standard
```

### 4. Update Scripts

PowerShell scripts using playbooks:

```powershell
# Before
Invoke-OrchestrationSequence -LoadPlaybook "test-lightning"

# After
Invoke-OrchestrationSequence -LoadPlaybook "test-quick" -PlaybookProfile "lightning"
```

### 5. Test Changes

Validate migration:

```powershell
# Run quick test with new playbook
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick

# Test with profile
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick -PlaybookProfile lightning

# Verify output matches expectations
```

## Breaking Changes

### Removed Playbooks

These playbooks are removed/archived:

- **test-phase1-validation** - Project-specific, archived
- **test-phase1-production** - Project-specific, archived
- **claude-development-workflow** - Split into git-feature + setup playbooks

**Impact**: If you use these, migrate to alternatives:
- Phase1 playbooks → test-standard or test-full
- claude-development-workflow → Use git-feature + dev-environment

### Schema Changes

v2.0 schema changes:

1. **Metadata section**: Now required with standardized fields
2. **Requirements section**: Enhanced with platforms and permissions
3. **Orchestration section**: New structure for stages and profiles
4. **Validation section**: Pre/post conditions support

**Impact**: Custom playbooks need updating to v2.0 format.

### Variable Names

Some variable names changed for consistency:

| Old | New |
|-----|-----|
| NoCoverage | skipCoverage |
| CheckOnly | dryRun |
| AutoFix | autoFix |

**Impact**: Update variable references in scripts.

## Timeline

Migration happens in phases:

### Phase 1: Core Playbooks (Current)
- ✅ Create new core playbooks
- ✅ Document migration path
- 🔄 Update existing playbooks to v2.0

### Phase 2: Deprecation Notices (Week 1-2)
- Add warnings to legacy playbooks
- Redirect to new equivalents
- Update documentation

### Phase 3: Migration Period (Week 3-4)
- Support both old and new simultaneously
- Monitor usage patterns
- Help users migrate

### Phase 4: Archive Legacy (Week 5+)
- Move deprecated playbooks to archive/
- Remove from main listings
- Keep for reference only

## Getting Help

### Common Issues

**Q: My playbook isn't found**
```powershell
# Check available playbooks
./Start-AitherZero.ps1 -Mode List -Target playbooks

# Check core directory
ls orchestration/playbooks/core/*/
```

**Q: Profile not recognized**
```powershell
# List available profiles
$pb = Get-Content ./orchestration/playbooks/core/testing/test-quick.json | ConvertFrom-Json
$pb.orchestration.profiles
```

**Q: Variables not working**
```powershell
# Check variable names in playbook
$pb = Get-Content ./orchestration/playbooks/core/testing/test-quick.json | ConvertFrom-Json
$pb.orchestration.defaultVariables
```

### Support Resources

- 📖 [Core Playbooks README](./core/README.md)
- 📋 [Consolidation Plan](./CONSOLIDATION-PLAN.md)
- 🐛 [Report Issues](https://github.com/wizzense/AitherZero/issues)
- 💬 [Get Help](https://github.com/wizzense/AitherZero/discussions)

## Rollback Plan

If you encounter issues:

1. **Immediate**: Use legacy playbooks (still available)
2. **Report**: Create GitHub issue with details
3. **Document**: Note specific problems
4. **Wait**: Fixes will be prioritized

Legacy playbooks remain available during migration period.

## Feedback

Help improve the migration:

1. **Report issues**: GitHub Issues
2. **Suggest improvements**: GitHub Discussions
3. **Contribute**: Pull requests welcome
4. **Share experience**: Document your migration

## Version History

- **2.0.0** (2025-11-02): Initial migration guide
  - Core playbooks structure
  - Migration mappings
  - Breaking changes documentation
