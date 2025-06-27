# Kicker Bootstrap Consolidation Plan

## Current State
- `kicker-git.ps1` (root) - Modern bootstrap with CoreApp integration ✅ MAIN ENTRY POINT
- `kicker-bootstrap-enhanced.ps1` (root) - Enhanced error handling version
- `core-runner/kicker-bootstrap.ps1` - Legacy bootstrap script

## Recommended Actions

### 1. Keep kicker-git.ps1 as Main Entry Point
- This is already your most feature-complete bootstrap
- Has CoreApp orchestration integration
- Cross-platform PowerShell 5.1/7.x support
- Modern error handling and logging

### 2. Consolidate Features from kicker-bootstrap-enhanced.ps1
- Extract any useful enhanced error handling features
- Merge them into kicker-git.ps1
- Delete kicker-bootstrap-enhanced.ps1

### 3. Deprecate core-runner/kicker-bootstrap.ps1
- This appears to be legacy code
- Move to deprecated/ folder or delete entirely
- Update any references to point to kicker-git.ps1

### 4. Update Documentation
- Ensure README points to kicker-git.ps1 as the main bootstrap
- Update any scripts that reference the old bootstrap scripts

## Final Structure
```
# Main Bootstrap (Web Installation)
bootstrap-launcher.ps1          # Minimal launcher → downloads kicker-git.ps1
kicker-git.ps1                  # MAIN BOOTSTRAP ENTRY POINT

# Development Utilities
Quick-Setup.ps1                 # Local development setup
Start-CoreApp.ps1              # CoreApp initialization
tools/Profile-AutoSetup.ps1    # PowerShell profile integration

# Deprecated (remove)
kicker-bootstrap-enhanced.ps1   # DELETE (merge features into kicker-git.ps1)
core-runner/kicker-bootstrap.ps1 # DELETE (legacy)
```

## Benefits
- ✅ Single source of truth for bootstrap
- ✅ kicker-git.ps1 remains the main entry point
- ✅ Eliminates confusion between similar scripts
- ✅ Reduces maintenance overhead
- ✅ Cleaner repository structure
