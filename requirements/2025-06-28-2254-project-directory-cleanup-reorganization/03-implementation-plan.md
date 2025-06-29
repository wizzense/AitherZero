# Implementation Plan: Project Directory Cleanup and Reorganization

**Phase 3: Step-by-Step Implementation Guide**

## Overview

This plan provides a safe, incremental approach to reorganizing the AitherZero project directory while maintaining full backward compatibility and zero downtime.

## Pre-Implementation Checklist

- [ ] Create full backup of repository
- [ ] Ensure all changes are committed
- [ ] Document current file paths for reference
- [ ] Notify team members of upcoming changes
- [ ] Test all critical scripts work before starting

## Stage 1: Foundation Setup (Day 1)

### 1.1 Create New Directory Structure
```powershell
# Create organized directories
New-Item -ItemType Directory -Path @(
    "docs/guides",
    "docs/development",
    "docs/archive/releases",
    "docs/archive/hotfixes", 
    "docs/archive/implementations",
    "docs/api",
    "scripts",
    "logs/current",
    "logs/archive",
    "build/output/windows",
    "build/output/linux",
    "build/temp"
) -Force
```

### 1.2 Create Compatibility Script
```powershell
# Create Invoke-CompatibilityWrapper.ps1
@'
param([string]$OldPath)
$mappings = @{
    "HOTFIX-Launcher.ps1" = "scripts/HOTFIX-Launcher.ps1"
    "Quick-Release.ps1" = "scripts/Quick-Release.ps1"
    # Add more mappings
}
$newPath = $mappings[$OldPath]
Write-Warning "This file has moved to: $newPath"
& (Join-Path $PSScriptRoot $newPath) @args
'@ | Set-Content -Path "Invoke-CompatibilityWrapper.ps1"
```

## Stage 2: Archive Old Documentation (Day 2)

### 2.1 Move HOTFIX Files
```powershell
# Archive HOTFIX documentation
$hotfixFiles = Get-ChildItem -Path . -Filter "HOTFIX-*.md"
foreach ($file in $hotfixFiles) {
    git mv $file.Name "docs/archive/hotfixes/$($file.Name)"
}
```

### 2.2 Move TURBO Files
```powershell
# Archive TURBO documentation
$turboFiles = Get-ChildItem -Path . -Filter "TURBO-*.md"
foreach ($file in $turboFiles) {
    git mv $file.Name "docs/archive/implementations/$($file.Name)"
}
```

### 2.3 Move Implementation Reports
```powershell
# Archive implementation reports
$reports = @(
    "CI-CD-ENHANCEMENT-FINAL-REPORT.md",
    "PR-CONSOLIDATION-IMPLEMENTATION-COMPLETE.md",
    "LAUNCHER-CRISIS-RESOLUTION-COMPLETE.md"
)
foreach ($report in $reports) {
    git mv $report "docs/archive/implementations/$report"
}
```

## Stage 3: Organize Scripts (Day 3)

### 3.1 Move Operational Scripts
```powershell
# Move scripts maintaining git history
$scriptsToMove = @(
    "Quick-Release.ps1",
    "Quick-ModuleCheck.ps1",
    "sync-repos.ps1",
    "Power-AutoMerge.ps1"
)
foreach ($script in $scriptsToMove) {
    git mv $script "scripts/$script"
    # Create compatibility wrapper
    @"
Write-Warning 'This script has moved to scripts/$script'
& `$PSScriptRoot/scripts/$script @args
"@ | Set-Content -Path $script
}
```

### 3.2 Update Script References
```powershell
# Update internal references in moved scripts
$scripts = Get-ChildItem -Path "scripts" -Filter "*.ps1"
foreach ($script in $scripts) {
    $content = Get-Content $script.FullName -Raw
    $content = $content -replace '\$PSScriptRoot/\.\.', '$PSScriptRoot/..'
    Set-Content -Path $script.FullName -Value $content
}
```

## Stage 4: Clean Up Logs (Day 4)

### 4.1 Archive Old Logs
```powershell
# Compress logs older than 7 days
$cutoffDate = (Get-Date).AddDays(-7)
$oldLogs = Get-ChildItem -Path "logs" -Recurse -Filter "*.log" |
    Where-Object { $_.LastWriteTime -lt $cutoffDate }

# Group by month and compress
$oldLogs | Group-Object { $_.LastWriteTime.ToString("yyyy-MM") } |
    ForEach-Object {
        $archiveName = "logs/archive/$($_.Name)-logs.zip"
        Compress-Archive -Path $_.Group.FullName -DestinationPath $archiveName
        Remove-Item $_.Group.FullName
    }
```

### 4.2 Implement Log Rotation
```powershell
# Create log rotation script
@'
param()
$logPath = Join-Path $PSScriptRoot "../logs/current"
$archivePath = Join-Path $PSScriptRoot "../logs/archive"
$cutoffDate = (Get-Date).AddDays(-7)

Get-ChildItem -Path $logPath -Filter "*.log" |
    Where-Object { $_.LastWriteTime -lt $cutoffDate } |
    Move-Item -Destination $archivePath
'@ | Set-Content -Path "scripts/Invoke-LogRotation.ps1"
```

## Stage 5: Documentation Consolidation (Day 5)

### 5.1 Organize User Guides
```powershell
# Move user-facing documentation
git mv "QUICK-START-GUIDE.md" "docs/guides/QUICK-START-GUIDE.md"
git mv "docs/INSTALLATION.md" "docs/guides/INSTALLATION.md"
```

### 5.2 Move Development Docs
```powershell
# Move developer documentation
git mv "docs/TESTING-COMPLETE-GUIDE.md" "docs/development/TESTING-GUIDE.md"
git mv "SYSTEM-UPGRADES-ROADMAP.md" "docs/development/SYSTEM-UPGRADES-ROADMAP.md"
```

### 5.3 Archive Release Notes
```powershell
# Move old release notes
$releaseNotes = Get-ChildItem -Path . -Filter "RELEASE_NOTES_*.md"
foreach ($note in $releaseNotes) {
    git mv $note.Name "docs/archive/releases/$($note.Name)"
}
```

## Stage 6: Update References (Day 6-7)

### 6.1 Update README.md
```powershell
# Update documentation links in README
$readme = Get-Content "README.md" -Raw
$readme = $readme -replace 'QUICK-START-GUIDE\.md', 'docs/guides/QUICK-START-GUIDE.md'
$readme = $readme -replace 'Quick-Release\.ps1', 'scripts/Quick-Release.ps1'
Set-Content -Path "README.md" -Value $readme
```

### 6.2 Update CI/CD Workflows
```powershell
# Update GitHub Actions paths
$workflows = Get-ChildItem -Path ".github/workflows" -Filter "*.yml"
foreach ($workflow in $workflows) {
    $content = Get-Content $workflow.FullName -Raw
    # Update script paths
    $content = $content -replace './Quick-', './scripts/Quick-'
    Set-Content -Path $workflow.FullName -Value $content
}
```

## Stage 7: Validation and Testing (Day 8)

### 7.1 Run Validation Tests
```powershell
# Test all entry points still work
./Start-AitherZero.ps1 -WhatIf
./tests/Run-BulletproofValidation.ps1 -ValidationLevel Quick
./scripts/Quick-ModuleCheck.ps1
```

### 7.2 Verify Git History
```powershell
# Ensure file history is preserved
git log --follow --oneline -- scripts/Quick-Release.ps1
```

### 7.3 Check Compatibility Wrappers
```powershell
# Test old paths still work with warnings
./Quick-Release.ps1 -Type Patch -WhatIf  # Should show warning and redirect
```

## Stage 8: Communication (Day 9)

### 8.1 Update Documentation
- Update README with new structure
- Create MIGRATION.md guide
- Document in CHANGELOG

### 8.2 Team Notification
- Send notification about changes
- Provide migration guide
- Set deprecation timeline (3 months)

## Stage 9: Cleanup (Day 90+)

### 9.1 Remove Compatibility Wrappers
After 3-month transition period:
```powershell
# Remove compatibility wrappers
Remove-Item "Quick-Release.ps1", "HOTFIX-Launcher.ps1" # etc
```

### 9.2 Final Optimization
- Remove empty directories
- Consolidate any remaining fragments
- Update all documentation

## Rollback Plan

If issues arise at any stage:

```powershell
# Full rollback via git
git reset --hard HEAD~1
git clean -fd

# Or selective rollback
git checkout HEAD -- [specific-file]
```

## Success Validation

Run these checks after implementation:

1. **Functionality Test**
   ```powershell
   ./tests/Run-BulletproofValidation.ps1 -ValidationLevel Standard
   ```

2. **Structure Validation**
   ```powershell
   # Should show clean root with only essential files
   Get-ChildItem -Path . -File | Measure-Object
   ```

3. **Documentation Check**
   ```powershell
   # Verify all docs are accessible
   Test-Path "docs/guides/QUICK-START-GUIDE.md"
   ```

## Timeline Summary

- **Day 1**: Foundation setup
- **Day 2**: Archive old documentation  
- **Day 3**: Organize scripts
- **Day 4**: Clean up logs
- **Day 5**: Consolidate documentation
- **Day 6-7**: Update references
- **Day 8**: Validation and testing
- **Day 9**: Communication
- **Day 90+**: Remove compatibility layer

---

*Implementation Plan Complete. Ready to begin execution with PatchManager workflow.*