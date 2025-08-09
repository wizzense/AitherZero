# AitherZero AI Coding Agent Instructions

## Project Overview

AitherZero is an infrastructure automation platform with a **number-based orchestration system** (0000-9999) for systematic script execution. The architecture uses a consolidated domain-based module system that loads through a single entry point.

## Essential Architecture Understanding

### Core Module Loading Flow
```
AitherZero.psd1 (Module Manifest)
    └── AitherZero.psm1 (Root Module)
        ├── Sets $env:AITHERZERO_ROOT and $env:AITHERZERO_INITIALIZED
        ├── Starts transcript logging (logs/transcript-*.log)
        ├── Loads critical modules first: Logging, Configuration
        └── Sequentially loads domain modules: experience → development → testing → reporting → automation → infrastructure
```

**Critical**: Always run `./Initialize-AitherEnvironment.ps1` first in new sessions - it loads the module manifest and sets up the environment.

### Number-Based Orchestration System

Scripts in `/automation-scripts/` follow numeric ranges:
- **0000-0099**: Environment prep (PowerShell 7, directories)
- **0100-0199**: Infrastructure (Hyper-V, certificates, networking)  
- **0200-0299**: Dev tools (Git, Node, Python, Docker, VS Code)
- **0400-0499**: Testing & validation
- **0500-0599**: Reporting & metrics
- **0700-0799**: Git automation & AI tools
- **9000-9999**: Maintenance & cleanup

Use the `az` wrapper for script execution: `az 0402` runs unit tests, `az 0404` runs PSScriptAnalyzer.

## Domain Structure (Consolidated Architecture v2.0)

Located in `/domains/` (legacy references may point to `aither-core/`):
- **infrastructure/**: Lab automation, OpenTofu/Terraform, VM management (57 functions)
- **configuration/**: Config management with environment switching (36 functions)  
- **utilities/**: Logging, maintenance, cross-platform helpers (24 functions)
- **security/**: Credentials, certificates (41 functions)
- **experience/**: UI components, menus, wizards (22 functions)
- **automation/**: Orchestration engine, workflows (16 functions)

## Critical Development Patterns

### Module Scope Issues
Functions in scriptblocks may lose module scope. Call directly:
```powershell
# Wrong - may fail in scriptblocks
Show-UISpinner { Write-CustomLog "Processing..." }

# Right - call functions directly  
Write-CustomLog "Processing..."
Show-UISpinner { Start-Process $command }
```

### Cross-Platform Paths
Always check platform variables:
```powershell
$path = if ($IsWindows) { 'C:/temp' } else { "$HOME/.aitherzero/temp" }
```

### Logging Pattern
Check for command availability:
```powershell
if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
    Write-CustomLog -Message "..." -Level 'Information'
} else {
    Write-Verbose "..."
}
```

## Key Commands & Workflows

### Essential Commands
```powershell
# Environment setup (always first)
./Initialize-AitherEnvironment.ps1

# Main interactive entry
./Start-AitherZero.ps1

# Run numbered scripts
az 0402              # Unit tests
az 0404              # PSScriptAnalyzer  
az 0407              # Syntax validation
az 0510 -ShowAll     # Project report

# Git workflow automation
az 0701 -Type feature -Name "my-feature"     # Create branch
az 0702 -Type feat -Message "add feature"    # Commit
az 0703 -Title "Add feature"                 # PR creation
```

### Testing Commands
```powershell
# Run specific test
Invoke-Pester -Path "./tests/unit/Configuration.Tests.ps1" -Output Detailed

# Domain tests with coverage
Invoke-Pester -Path "./tests/domains/configuration" -CodeCoverage "./domains/configuration/*.psm1"

# All tests
Invoke-Pester -Path "./tests"
```

### Orchestration & Playbooks
```powershell
# Run playbook sequences
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick   # Fast validation
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-full    # Complete tests

# Direct sequence execution  
Invoke-OrchestrationSequence -Sequence "0000-0099" -Configuration $Config
```

## Configuration System

Hierarchical config loading:
1. Default values in code
2. `/config.json` file  
3. Playbook variables
4. Command-line parameters

Key sections:
- `Core.Profile`: Minimal, Standard, Developer, Full
- `Automation.MaxConcurrency`: Parallel execution limit  
- `Testing.Profile`: Quick, Standard, Full, CI

## Common Issues & Solutions

### Module Loading Errors
- Ensure `Logging.psm1` loads first (other modules depend on Write-CustomLog)
- `BetterMenu.psm1` must load before `UserInterface.psm1`
- Functions must be in `Export-ModuleMember` lists

### Parameter Errors
- Variables in playbooks shouldn't be script parameters unless accepted
- Use approved PowerShell verbs (`Get-Verb` to check)
- Initialize timing variables before try blocks

### UI Component Issues
- `Write-UIText` requires `[AllowEmptyString()]` for empty messages
- `Show-UIMenu` doesn't have `-UseInteractive` parameter (legacy)

## File Locations to Know

- **Main entry**: `/Start-AitherZero.ps1`
- **Environment setup**: `/Initialize-AitherEnvironment.ps1` 
- **Module manifest**: `/AitherZero.psd1`
- **Scripts**: `/automation-scripts/` (numbered 0000-9999)
- **Config**: `/config.json`
- **Tests**: `/tests/` (organized by domain)
- **Playbooks**: `/orchestration/playbooks/`

## Platform Differences

Use platform checks for Windows-specific features:
- Hyper-V: Windows only
- WSL2: Windows only  
- Certificate Authority: Windows only
- All other tools: Cross-platform (PowerShell 7+)

Check exit codes: 0=success, 1=error, 3010=restart required

## Before Making Changes

1. Run `./Initialize-AitherEnvironment.ps1` 
2. Validate with `az 0404` (PSScriptAnalyzer)
3. Test with appropriate domain tests
4. Check transcript logs in `logs/transcript-*.log` for errors

This consolidated architecture ensures reliable module loading and provides powerful orchestration capabilities through the number-based system.
