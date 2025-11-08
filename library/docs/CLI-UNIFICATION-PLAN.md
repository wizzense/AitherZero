# AitherZero Domain Analysis - CLI Unification Plan

## Executive Summary

**Mission:** Build a clean, powerful PowerShell CLI on top of existing domain modules (27,255 lines across 39 modules).

**Approach:** Unify, don't rewrite. Integrate existing battle-tested code into a cohesive cmdlet interface.

---

## Current State

### ✅ Cleanup Complete
- **Removed:** 10,499 lines of overlapping UI code (BetterMenu, UnifiedMenu, CLIHelper, ModalUI, etc.)
- **Simplified:** Start-AitherZero.ps1 from 4,038 to 370 lines (90.8% reduction)
- **Preserved:** All 39 domain modules intact and functional

### 📊 Domain Inventory

**10 Domains | 39 Modules | 27,255 Lines**

```
ai-agents/         3 modules  - AI workflow, Claude, Copilot integration
automation/        5 modules  - Orchestration, async, deployment, utilities  ⭐ INTEGRATE
configuration/     2 modules  - Config management, environments             ⭐ INTEGRATE
development/       4 modules  - Git automation, issues, PRs, tools
documentation/     2 modules  - Doc generation, indexing
infrastructure/    1 module   - Infrastructure provider abstraction
reporting/         2 modules  - Dashboards, metrics, tech debt              ⭐ INTEGRATE
security/          1 module   - Security, credentials, certificates
testing/           9 modules  - Test framework, generators, quality
utilities/         9 modules  - Logging, bootstrap, extensions, perf        ⭐ INTEGRATE
```

---

## Unification Strategy

### Phase 1: Core CLI Module (PRIORITY)

**Create:** `domains/cli/AitherZeroCLI.psm1`

**Integrate from automation/OrchestrationEngine.psm1:**
```powershell
# Already exists - wrap with proper cmdlet interface:
Invoke-OrchestrationSequence  → Invoke-AitherPlaybook (alias: Run-Playbook)
Get-OrchestrationPlaybook     → Get-AitherPlaybook
Invoke-Sequence               → Invoke-AitherSequence
```

**Integrate from automation/ScriptUtilities.psm1:**
```powershell
# Core helpers - expose as needed:
Get-ProjectRoot          → Get-AitherProjectRoot
Write-ScriptLog          → Use internal (don't export)
Test-IsAdministrator     → Test-AitherAdminMode
Get-PlatformName         → Get-AitherPlatform
Test-CommandAvailable    → Test-AitherCommand
Get-GitHubToken          → Get-AitherGitHubToken
Get-ScriptMetadata       → Get-AitherScriptInfo
Format-Duration          → Format-AitherDuration
```

**Integrate from configuration/Configuration.psm1:**
```powershell
# Config management:
Get-Configuration        → Get-AitherConfig
Set-Configuration        → Set-AitherConfig
Import-ConfigDataFile    → Import-AitherConfig
Switch-ConfigurationEnvironment → Switch-AitherEnvironment
```

**Integrate from utilities/Logging.psm1:**
```powershell
# Logging - keep simple:
Write-CustomLog          → Write-AitherLog
Enable-AuditLogging      → Enable-AitherAudit
```

**Integrate from reporting/ReportingEngine.psm1:**
```powershell
# Dashboards and reports:
New-ExecutionDashboard   → New-AitherDashboard
Show-Dashboard           → Show-AitherDashboard
Export-MetricsReport     → Export-AitherMetrics
Get-ExecutionMetrics     → Get-AitherMetrics
```

### Phase 2: Domain-Specific Cmdlet Groups

Keep specialized modules separate but with consistent naming:

**Testing Cmdlets** (from testing/ modules):
```powershell
Invoke-AitherTest         # Run tests
Get-AitherTestResult      # View results
New-AitherTestReport      # Generate report
```

**Development Cmdlets** (from development/ modules):
```powershell
New-AitherBranch          # Git branch
New-AitherCommit          # Git commit
New-AitherPR              # Create PR
```

**Infrastructure Cmdlets** (from infrastructure/ module):
```powershell
Initialize-AitherInfrastructure
Get-AitherProvider
Deploy-AitherInfrastructure
```

---

## Proposed CLI Structure

### Top-Level Cmdlets (Export from AitherZero module)

**Script Execution:**
```powershell
Invoke-AitherScript -Number 0402                # Run script
Get-AitherScript                                # List all scripts
Get-AitherScript -Range "0400-0499"             # Filter by range
Get-AitherScript -Name "*test*"                 # Filter by name
```

**Playbook Orchestration:**
```powershell
Invoke-AitherPlaybook -Name test-quick          # Run playbook
Get-AitherPlaybook                              # List playbooks
Get-AitherPlaybook -Name "*test*"               # Filter playbooks
```

**Configuration:**
```powershell
Get-AitherConfig                                # Get current config
Set-AitherConfig -Key "Core.Profile" -Value "Developer"
Switch-AitherEnvironment -Name "Production"     # Switch environment
```

**Status & Reporting:**
```powershell
Show-AitherDashboard                            # Status dashboard
Get-AitherMetrics                               # Execution metrics
Export-AitherMetrics -Format JSON               # Export metrics
```

**Utilities:**
```powershell
Get-AitherPlatform                              # Platform info
Test-AitherAdminMode                            # Check admin
Get-AitherProjectRoot                           # Project root
```

---

## Implementation Plan

### Step 1: Create CLI Module Skeleton
```powershell
domains/cli/
├── AitherZeroCLI.psm1           # Main CLI module
├── AitherZeroCLI.psd1           # Module manifest
└── Private/                     # Internal helpers
    ├── ScriptHelper.ps1
    ├── PlaybookHelper.ps1
    └── ConfigHelper.ps1
```

### Step 2: Wrap Existing Functions
- Don't rewrite working code
- Create cmdlet wrappers around existing functions
- Add proper comment-based help
- Add parameter validation
- Add pipeline support

### Step 3: Update Main Module
**AitherZero.psm1:**
- Load CLI module first (after logging/config)
- Expose CLI cmdlets as primary interface
- Keep domain modules for specialized tasks

**AitherZero.psd1:**
- Export CLI cmdlets
- Remove wildcard export (`'*'`)
- Explicit function list

### Step 4: Update Start-AitherZero.ps1
- Simple wrapper around cmdlets
- Backward compatibility
- Forward to proper cmdlets

---

## Design Principles

### 1. PowerShell Best Practices
- Approved verbs (Get, Set, Invoke, New, Show, Test, etc.)
- Proper parameter sets
- Pipeline support
- Comment-based help
- Tab completion

### 2. Consistency
- All cmdlets start with `*-Aither*`
- Consistent parameter naming
- Consistent output objects
- Consistent error handling

### 3. Discoverability
```powershell
Get-Command -Module AitherZero          # All commands
Get-Help Invoke-AitherScript -Full      # Full help
Get-Help Invoke-AitherScript -Examples  # Examples
```

### 4. Extensibility
- Plugin architecture (existing ExtensionManager)
- Custom cmdlets via extensions
- Custom playbooks
- Custom scripts

---

## Benefits

### For Users
- **Familiar:** Standard PowerShell cmdlets
- **Discoverable:** `Get-Help` and tab completion
- **Scriptable:** Pipeline support, automation-friendly
- **Powerful:** Access to all 39 modules worth of functionality

### For Developers
- **Clean:** No overlapping UI systems
- **Maintainable:** Centralized CLI, modular domains
- **Testable:** Cmdlets are unit-testable
- **Extensible:** Plugin architecture built-in

### For the Project
- **Professional:** Proper PowerShell module
- **Publishable:** Ready for PowerShell Gallery
- **Documented:** Comment-based help system
- **Scalable:** Clean foundation for growth

---

## Next Actions

1. **Create CLI module structure** (`domains/cli/`)
2. **Wrap orchestration functions** (Invoke-AitherPlaybook, Get-AitherPlaybook)
3. **Wrap script execution** (Invoke-AitherScript, Get-AitherScript)
4. **Add comment-based help** (all cmdlets)
5. **Update module manifest** (AitherZero.psd1)
6. **Test and validate** (ensure existing functionality works)
7. **Document** (README with examples)

---

## Success Criteria

✅ Clean cmdlet interface with proper PowerShell naming
✅ Full `Get-Help` support for all commands
✅ Tab completion for parameters
✅ Pipeline support where appropriate
✅ All existing functionality preserved
✅ No duplicate code (reuse existing modules)
✅ Professional, publishable module

---

**Status:** Ready to build Phase 1 (Core CLI Module)
**Commit:** 1486ca2 - UI cleanup complete, 90%+ code reduction
**Next PR:** Unified CLI module implementation
