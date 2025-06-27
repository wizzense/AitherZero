# Bootstrap Script Consolidation Plan

## Current State Analysis
You have 6 different bootstrap/setup scripts serving overlapping purposes. This creates confusion and maintenance overhead.

## Recommended Consolidation

### Keep These (3 Scripts):

1. **`bootstrap-launcher.ps1`** - Minimal web launcher
   - Keep for one-liner installations
   - Smallest possible footprint for web downloads

2. **`kicker-git.ps1`** - Primary bootstrap (rename to `bootstrap.ps1`)
   - This is your main bootstrap script
   - Handles all installation scenarios
   - Cross-platform and feature-complete

3. **`Quick-Setup.ps1`** - Development environment setup
   - Keep for local development workflow
   - Focused on module importing and env setup

### Consolidate These Into Existing Scripts:

4. **`kicker-bootstrap-enhanced.ps1`** → Merge into `kicker-git.ps1`
   - The enhanced features should be the default in the main bootstrap
   - No need for a separate "enhanced" version

5. **`Start-CoreApp.ps1`** → Merge functionality into `Quick-Setup.ps1`
   - CoreApp initialization can be an option in Quick-Setup
   - Add a `-StartCoreApp` parameter to Quick-Setup

6. **`Profile-AutoSetup.ps1`** → Keep as separate utility
   - This serves a different purpose (PowerShell profile integration)
   - Consider moving to `tools/` directory

## Proposed File Structure

```
# Web Installation
bootstrap-launcher.ps1          # Minimal web launcher

# Main Bootstrap
bootstrap.ps1                   # Renamed from kicker-git.ps1

# Development
Quick-Setup.ps1                 # Enhanced with CoreApp options

# Utilities
tools/Profile-AutoSetup.ps1     # PowerShell profile integration
```

## Implementation Steps

1. Enhance `kicker-git.ps1` with features from `kicker-bootstrap-enhanced.ps1`
2. Rename `kicker-git.ps1` to `bootstrap.ps1`
3. Add CoreApp functionality to `Quick-Setup.ps1`
4. Move `Profile-AutoSetup.ps1` to `tools/` directory
5. Remove redundant scripts
6. Update documentation and README

## Benefits

- ✅ Clearer purpose for each script
- ✅ Reduced maintenance overhead
- ✅ Less confusion for users
- ✅ Cleaner repository structure
- ✅ Easier documentation
