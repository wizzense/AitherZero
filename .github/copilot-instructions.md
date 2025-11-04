# AitherZero AI Coding Agent Instructions

This file provides guidance for GitHub Copilot coding agents working on this repository. It includes architecture details, development patterns, testing procedures, and best practices specific to AitherZero.

## Project Overview

AitherZero is an **infrastructure automation platform** built in PowerShell 7+ with a unique **number-based orchestration system** (0000-9999) for systematic script execution. The platform is:

- **Size**: 525 PowerShell files (457 .ps1, .psm1, .psd1), ~125 automation scripts
- **Type**: Infrastructure automation framework with modular domain architecture
- **Languages**: PowerShell 7.0+, Node.js (for MCP server), minimal Bash
- **Target Runtime**: PowerShell 7.0+ on Windows, Linux, and macOS
- **Architecture**: Domain-based modules (11 domains, 192 exported functions)
- **Key Feature**: Number-based script orchestration (0000-9999) with dependency tracking

The platform consolidates 11 functional domains into a single unified module system that loads through one entry point (`AitherZero.psm1`).

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

**Critical**: For new installations, run `./bootstrap.ps1` to set up the environment. For existing installations, the module is auto-loaded via `Import-Module` or `Start-AitherZero.ps1`.

### Number-Based Orchestration System

Scripts in `/automation-scripts/` follow numeric ranges:
- **0000-0099**: Environment prep (PowerShell 7, directories)
- **0100-0199**: Infrastructure (Hyper-V, certificates, networking)
- **0200-0299**: Dev tools (Git, Node, Python, Docker, VS Code)
- **0400-0499**: Testing & validation
- **0500-0599**: Reporting & metrics
- **0700-0799**: Git automation & AI tools
- **9000-9999**: Maintenance & cleanup

Use the `aitherzero` wrapper for script execution: `aitherzero 0402` runs unit tests, `aitherzero 0404` runs PSScriptAnalyzer.

## Domain Structure (Consolidated Architecture v2.0)

Located in `/domains/` (legacy references may point to `aither-core/`):
- **infrastructure/**: Lab automation, OpenTofu/Terraform, VM management (57 functions)
- **configuration/**: Config management with environment switching (36 functions)
- **utilities/**: Logging, maintenance, cross-platform helpers (24 functions)
- **security/**: Credentials, certificates (41 functions)
- **experience/**: UI components, menus, wizards (22 functions)
- **automation/**: Orchestration engine, workflows (16 functions)

## Critical Development Patterns

### ⚠️ HARD REQUIREMENT: Single-Purpose Scripts with Parameters

**NEVER create duplicate or "alternative" versions of automation scripts!**

❌ **WRONG - Creating separate scripts for behavior variations:**
```
automation-scripts/
├── 0404_Run-PSScriptAnalyzer.ps1
├── 0404_Run-PSScriptAnalyzer-Parallel.ps1    ❌ NEVER DO THIS
├── 0404_Run-PSScriptAnalyzer-Fast.ps1        ❌ NEVER DO THIS  
├── 0410_Run-PSScriptAnalyzer-Fast.ps1        ❌ WRONG - Just another version
└── 0404_Run-PSScriptAnalyzer-Clean.ps1       ❌ NEVER DO THIS
```

✅ **CORRECT - Single script with parameters for behavior modification:**
```powershell
automation-scripts/
└── 0404_Run-PSScriptAnalyzer.ps1    ✅ One script with parameters

# Usage examples:
./automation-scripts/0404_Run-PSScriptAnalyzer.ps1                    # Full comprehensive scan
./automation-scripts/0404_Run-PSScriptAnalyzer.ps1 -Fast              # Fast mode for CI
./automation-scripts/0404_Run-PSScriptAnalyzer.ps1 -Severity Error   # Errors only
./automation-scripts/0404_Run-PSScriptAnalyzer.ps1 -UseCache         # Use cached results

# Parameters control behavior, NOT separate scripts!
```

✅ **For truly different functionality - use different numbers:**
```
automation-scripts/
├── 0404_Run-PSScriptAnalyzer.ps1          # Analysis (with -Fast parameter)
└── 0415_Manage-PSScriptAnalyzerCache.ps1  # Cache management (different purpose)

orchestration/playbooks/
└── code-quality-full.psd1    ✅ Orchestrates complex workflows
```

**Core Principles:**
1. **One Script = One Job**: Each numbered script does ONE thing well
2. **Parameters NOT Duplicates**: Modify behavior with parameters, NOT separate scripts
3. **Different Numbers = Different Functions**: 0404 (analysis) vs 0415 (cache mgmt) - truly different purposes
4. **Orchestration for Workflows**: Use playbooks when workflow needs multiple steps
5. **Sequential Execution Risk**: Scripts 0000-9999 can be run sequentially - duplicates cause confusion

**When You Need Behavior Variations:**
- ✅ Add parameters to existing script: `-Fast`, `-Comprehensive`, `-Severity`, `-UseCache`
- ❌ Don't create: 0404-Fast.ps1, 0404-Parallel.ps1, 0404-Clean.ps1

**When You Need Different Functionality:**
- ✅ Create new numbered script: 0415 for cache management
- ✅ Create playbook for complex workflows
- ❌ Don't create variants of the same script

**Example - Correct Approach:**
```powershell
# ONE script handles all analysis modes via parameters:
0404_Run-PSScriptAnalyzer.ps1
    Parameters:
        -Fast           # Quick scan for CI
        -Comprehensive  # Full scan
        -UseCache       # Use cache
        -Severity       # Control severity levels
        -Parallel       # Use parallel processing

# Different functionality = different script:
0415_Manage-PSScriptAnalyzerCache.ps1  # Cache operations
0416_Generate-AnalysisReport.ps1       # Report generation

# Complex workflow = playbook:
orchestration/playbooks/code-quality-full.psd1
```

### ⚠️ HARD REQUIREMENT: Use ScriptUtilities Module for Common Code

**NEVER duplicate common helper functions in automation scripts!**

All automation scripts should use the centralized `ScriptUtilities.psm1` module for common patterns.

❌ **WRONG - Defining helper functions in each script:**
```powershell
# In 0404_Run-PSScriptAnalyzer.ps1
function Write-ScriptLog {
    param([string]$Message, [string]$Level = 'Information')
    # 40 lines of duplicate logging code...
}

function Get-GitHubToken {
    # 30 lines of duplicate auth code...
}

# Script logic starts here...
```

✅ **CORRECT - Import ScriptUtilities module:**
```powershell
# In 0404_Run-PSScriptAnalyzer.ps1
#Requires -Version 7.0

param(
    [switch]$Fast,
    [switch]$UseCache
)

# Import ScriptUtilities for common functions
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module (Join-Path $ProjectRoot "domains/automation/ScriptUtilities.psm1") -Force

# Now use the functions directly
Write-ScriptLog "Starting PSScriptAnalyzer..." -Level 'Information'
$token = Get-GitHubToken -ErrorAction SilentlyContinue

# Script logic...
```

**Available Functions in ScriptUtilities:**
- `Write-ScriptLog` - Centralized logging with fallback
- `Get-GitHubToken` - GitHub authentication helper
- `Test-Prerequisites` - Validate dependencies
- `Get-ProjectRoot` - Get repository root path
- `Get-ScriptMetadata` - Parse script metadata comments
- `Test-CommandAvailable` - Check if command exists
- `Test-IsAdministrator` - Check admin privileges
- `Test-GitRepository` - Validate git repository
- `Invoke-WithRetry` - Retry failed operations
- `Format-Duration` - Format timespan for display

**When to Add Functions to ScriptUtilities:**
- Function is used in 3+ automation scripts
- Function provides common infrastructure (logging, auth, validation)
- Function has no script-specific logic
- Function follows PowerShell best practices (approved verbs, proper parameters)

**When NOT to Add to ScriptUtilities:**
- Script-specific business logic
- Functions with heavy dependencies on specific tools
- Experimental/unstable code

**Core Principle:**
> "DRY (Don't Repeat Yourself) - Extract reusable code to ScriptUtilities, not copy-paste to every script"

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
# Environment setup (new installations)
./bootstrap.ps1 -Mode New -AutoInstallDeps

# Environment update (existing installations)
./bootstrap.ps1 -Mode Update

# Main interactive entry
./Start-AitherZero.ps1

# Run numbered scripts
aitherzero 0402              # Unit tests
aitherzero 0404              # PSScriptAnalyzer
aitherzero 0407              # Syntax validation
aitherzero 0510 -ShowAll     # Project report

# Git workflow automation
aitherzero 0701 -Type feature -Name "my-feature"     # Create branch
aitherzero 0702 -Type feat -Message "add feature"    # Commit
aitherzero 0703 -Title "Add feature"                 # PR creation
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

### Automatic Test Generation System

**CRITICAL: DO NOT WRITE TESTS MANUALLY!** AitherZero has a 100% automated test generation system.

**Test Generation Workflow:**
1. When you create a new automation script in `automation-scripts/`
2. The `auto-generate-tests.yml` workflow automatically detects missing tests
3. Tests are auto-generated using `0950_Generate-AllTests.ps1`
4. Generated tests are committed to your PR automatically

**Manual Test Generation:**
```powershell
# Generate tests for scripts without tests (Quick mode)
./automation-scripts/0950_Generate-AllTests.ps1 -Mode Quick

# Regenerate ALL tests (use sparingly)
./automation-scripts/0950_Generate-AllTests.ps1 -Mode Full -Force

# Watch mode for continuous generation during development
./automation-scripts/0950_Generate-AllTests.ps1 -Mode Watch
```

**What Gets Auto-Generated:**
- Script validation tests (file exists, valid syntax)
- Parameter validation tests
- Metadata checks (stage, dependencies, tags)
- WhatIf execution tests
- Basic functionality tests

**Test Structure:**
- Unit tests: `tests/unit/automation-scripts/{range}/` (e.g., `0400-0499/`)
- Integration tests: `tests/integration/automation-scripts/`
- Domain tests: `tests/domains/{domain}/`

**Validation:**
```powershell
# Validate all scripts have tests
./automation-scripts/0426_Validate-TestScriptSync.ps1

# Remove orphaned tests (tests for deleted scripts)
./automation-scripts/0426_Validate-TestScriptSync.ps1 -RemoveOrphaned
```

**CI/CD Integration:**
- `auto-generate-tests.yml`: Automatically generates missing tests on PRs
- `validate-test-sync.yml`: Validates test-script synchronization
- `comprehensive-test-execution.yml`: Runs all generated tests

**Important Rules:**
1. ❌ **Never create test files manually** - use the generator
2. ✅ **Always run 0950_Generate-AllTests.ps1** after creating new scripts
3. ✅ **Commit generated tests** along with your script changes
4. ✅ **Let CI auto-generate** if you forget - it will handle it
5. ✅ **Run validation** before finalizing PRs: `./automation-scripts/0426_Validate-TestScriptSync.ps1`

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

### GitHub Issue Creation Failures

**Problem**: Scripts fail to create GitHub issues with errors like:
```
Error: 1-04 02:45:14] [Error] Failed to create issue for file.ps1
⚠️  Issue creation failed. Check that gh CLI is authenticated and has write access.
```

**Root Cause**: 
- PowerShell scripts trying to use `gh` CLI in CI/CD workflows
- `gh` CLI requires explicit authentication setup
- Workflows already handle issue creation via `actions/github-script@v7`

**Solution**:
1. **In workflows**: Use `actions/github-script@v7` (NOT `gh` CLI)
2. **In PowerShell scripts**: Detect CI and skip issue creation
3. **Local use**: Ensure `gh auth login` is run before using `gh` CLI

**Check**:
```powershell
# Scripts should detect CI and delegate to workflow
if ($env:GITHUB_ACTIONS -eq 'true' -or $env:CI -eq 'true') {
    Write-Host "Issue creation skipped - workflow will handle it"
    return
}
```

**Reference**: See `.github/workflows/auto-create-issues-from-failures.yml` for correct pattern

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

## Project Layout and Architecture

### Repository Root Files

```
/home/runner/work/AitherZero/AitherZero/
├── AitherZero.psd1              # Module manifest - 192 exported functions
├── AitherZero.psm1              # Root module - loads all domains sequentially
├── Start-AitherZero.ps1         # Main entry point - interactive mode
├── bootstrap.ps1                # Setup script (PowerShell) - ALWAYS RUN FIRST
├── bootstrap.sh                 # Setup script (Bash) - Linux/macOS variant
├── aitherzero                   # Global wrapper script for numbered scripts
├── config.psd1                  # Master configuration manifest - 1476 lines
├── config.example.psd1          # Template configuration  
├── PSScriptAnalyzerSettings.psd1 # Linter rules (27 lines)
├── Invoke-AitherTests.ps1       # Test runner script
├── VERSION                      # Version file
├── README.md                    # Main documentation
├── LICENSE                      # MIT license
└── Docker files                 # Dockerfile, docker-compose.yml, etc.
```

### Directory Structure

```
├── .github/                     # GitHub configuration
│   ├── workflows/               # 17 CI/CD workflows (YAML)
│   ├── copilot-instructions.md  # THIS FILE - AI agent guidance
│   ├── copilot.yaml             # Custom agent routing (8 specialized agents)
│   ├── mcp-servers.json         # Model Context Protocol server config
│   └── prompts/                 # Reusable prompt templates
├── .vscode/                     # VS Code settings, tasks, launch configs
├── .devcontainer/               # DevContainer configuration
├── automation-scripts/          # 125 numbered scripts (0000-9999)
│   ├── 0000-0099/              # Environment setup
│   ├── 0100-0199/              # Infrastructure (Hyper-V, certificates)
│   ├── 0200-0299/              # Dev tools (Git, Node, Docker, VS Code)
│   ├── 0400-0499/              # Testing & validation
│   ├── 0500-0599/              # Reporting & metrics  
│   ├── 0700-0799/              # Git automation & AI tools
│   ├── 0800-0899/              # Issue management
│   ├── 0900-0999/              # Validation
│   └── 9000-9999/              # Maintenance & cleanup
├── domains/                     # 11 functional domains (modular architecture)
│   ├── ai-agents/              # 3 modules - AI integration
│   ├── automation/             # 2 modules - Orchestration engine
│   ├── configuration/          # 1 module - Config management (36 functions)
│   ├── development/            # 4 modules - Git automation, CLI
│   ├── documentation/          # 2 modules - Doc generation, indexing
│   ├── experience/             # 8 modules - UI, menus, wizards (22 functions)
│   ├── infrastructure/         # 1 module - VM management (57 functions)
│   ├── reporting/              # 2 modules - Analytics, tech debt
│   ├── security/               # 1 module - Credentials, certs (41 functions)
│   ├── testing/                # 8 modules - Pester, quality, validation
│   └── utilities/              # 9 modules - Logging, maintenance (24 functions)
├── tests/                       # Test suite (~74 test files)
│   ├── unit/                   # Unit tests (by domain and script range)
│   ├── integration/            # Integration tests
│   ├── domains/                # Domain-specific tests
│   ├── TestHelpers.psm1        # Shared test utilities
│   ├── results/                # Test output (XML, JSON)
│   ├── analysis/               # PSScriptAnalyzer results (CSV, JSON)
│   └── coverage/               # Code coverage reports
├── orchestration/              # Playbooks and sequences
│   ├── playbooks/              # Predefined execution sequences
│   └── sequences/              # Script execution groups
├── docs/                        # Documentation
├── reports/                     # Generated reports
├── logs/                        # Transcript and execution logs
├── infrastructure/             # OpenTofu/Terraform configs
├── mcp-server/                 # MCP server (Node.js) - AI integration
└── tools/                      # Utility scripts
```

### Configuration Files (Critical)

**`config.psd1`** - Single source of truth (1476 lines):
- Lines 51-438: Manifest section - platform support, dependencies, profiles
- Lines 442-494: Core configuration - execution modes, profiles
- Lines 498-836: Features section - what components are enabled
- Lines 840-897: Automation - orchestration settings
- Lines 901-935: UI - display settings  
- Lines 939-1047: Testing - Pester, PSScriptAnalyzer, coverage config
- Lines 1051-1115: Development - Git automation, AI, quality
- Lines 1119-1205: AI - providers (Claude, Codex, Gemini), capabilities
- Lines 1209-1246: Infrastructure - HyperV, OpenTofu settings
- Lines 1333-1355: Logging - audit, retention, targets
- Lines 1391-1476: Automated issue management - GitHub integration

**`PSScriptAnalyzerSettings.psd1`** - Linter configuration:
- IncludeRules: All rules (`@('*')`)
- ExcludeRules: `PSAvoidUsingWriteHost`, `PSUseShouldProcessForStateChangingFunctions`
- Target PowerShell 7.0+

### Domain Module Dependencies

**Load order is critical** (see `AitherZero.psm1` lines 100-200):
1. **Logging** (must load FIRST - all modules depend on Write-CustomLog)
2. **Configuration** (second - used by all other modules)
3. **BetterMenu** (must load before UserInterface)
4. **Experience modules** (UI components)
5. **Development modules** (Git, CLI)
6. **Testing modules** (Pester framework)
7. **Reporting modules**
8. **Automation modules** (orchestration)
9. **Infrastructure modules** (last - depends on everything)

**Function export pattern**: Each domain module MUST have `Export-ModuleMember` at the end listing all public functions.

### Key Source Files

**Root Module** (`AitherZero.psm1` - 300+ lines):
- Sets `$env:AITHERZERO_ROOT` and `$env:AITHERZERO_INITIALIZED`
- Starts transcript logging (`logs/transcript-*.log`)
- Loads domains in dependency order
- Exports `Invoke-AitherScript` wrapper function

**Main Entry** (`Start-AitherZero.ps1` - 500+ lines):
- Interactive UI with BetterMenu navigation
- Modern CLI with search, history, profiles
- Orchestration mode for playbook execution
- Supports modes: Interactive, Orchestrate, List, Run, Search

**Bootstrap** (`bootstrap.ps1` - 900+ lines):
- Platform detection (Windows/Linux/macOS)
- PowerShell 7 installation if missing
- Module path configuration
- Dependency resolution
- Global command installation (`aitherzero`)

### GitHub Workflows (17 total)

**Critical workflows**:
- `pr-validation.yml` - PR syntax check and analysis
- `comprehensive-test-execution.yml` - Full test suite (unit + integration)
- `quality-validation.yml` - Code quality checks
- `publish-test-reports.yml` - Test result publishing
- `documentation-automation.yml` - Auto-generate docs
- `index-automation.yml` - Update index.md files
- `copilot-agent-router.yml` - Route to specialized agents

**Workflow timing**:
- PR validation: 1-2 minutes
- Comprehensive tests: 3-5 minutes
- Quality validation: 2-3 minutes
- Documentation: 1-2 minutes

### Critical GitHub Actions Patterns

**IMPORTANT: Creating GitHub Issues in Workflows**

❌ **WRONG - Do NOT use `gh` CLI in workflows for issue creation:**
```yaml
- name: Create Issue
  run: |
    gh issue create --title "..." --body "..." --label "..."
    # This requires explicit GITHUB_TOKEN setup and gh auth
```

✅ **RIGHT - Use `actions/github-script@v7` (recommended):**
```yaml
- name: Create Issue
  uses: actions/github-script@v7
  with:
    script: |
      const issue = await github.rest.issues.create({
        owner: context.repo.owner,
        repo: context.repo.repo,
        title: 'Issue title',
        body: 'Issue body',
        labels: ['label1', 'label2']
      });
      console.log(`Created issue #${issue.data.number}`);
```

**Why `actions/github-script` is better:**
1. **Built-in authentication** - No need to set up GITHUB_TOKEN explicitly
2. **Uses Octokit API** - Full GitHub REST API access
3. **Better error handling** - Structured responses, no stderr bleeding
4. **JavaScript/TypeScript** - Easy to work with JSON data
5. **Used by existing workflows** - See `auto-create-issues-from-failures.yml` and `quality-validation.yml`

**Pattern for PowerShell scripts:**
- PowerShell scripts (like `0420_Validate-ComponentQuality.ps1`) should **skip issue creation in CI**
- Detect CI with: `$env:GITHUB_ACTIONS -eq 'true'` or `$env:CI -eq 'true'`
- Let the workflow handle issue creation via `actions/github-script`
- Only attempt local issue creation using `gh` CLI when NOT in CI

**Example from working code:**
```powershell
if ($shouldCreateIssues -and ($overallStatus -eq 'Failed')) {
    # In GitHub Actions/CI, skip issue creation - the workflow handles it
    if ($env:GITHUB_ACTIONS -eq 'true' -or $env:CI -eq 'true') {
        Write-Host "Issue creation skipped - running in CI environment"
        Write-Host "GitHub Actions workflow will create issues automatically"
    } else {
        # Local execution - try to use gh CLI
        if (Test-GitHubAuthentication) {
            # Create issues with gh CLI...
        }
    }
}
```

**Authentication patterns:**
- Workflows: `actions/github-script` uses automatic token (no setup needed)
- Local scripts: Require `gh auth login` before using `gh` CLI
- CI detection: Check `$env:GITHUB_ACTIONS` or `$env:CI`

### Common Patterns and Locations

**To add a new automation script**:
1. Create `automation-scripts/NNNN_Description.ps1` (use next available number)
2. Add metadata comment block with Stage, Dependencies, Tags
3. Add to `config.psd1` FeatureDependencies section
4. Create unit test in `tests/unit/automation-scripts/NNNN-range/`
5. Export script number in orchestration playbooks if needed

**To add a new domain function**:
1. Add function to appropriate domain module in `domains/*/`
2. Add `Export-ModuleMember -Function 'YourFunction'` at module end
3. Add function name to `AitherZero.psd1` FunctionsToExport array
4. Create unit test in `tests/domains/your-domain/`
5. Add comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, etc.)

**To modify configuration**:
1. Edit `config.psd1` (master file)
2. **ALWAYS validate** with `./automation-scripts/0413_Validate-ConfigManifest.ps1` BEFORE committing
3. Verify sync with `./automation-scripts/0003_Sync-ConfigManifest.ps1`
4. Test configuration loading with `Get-Configuration`
5. **Critical**: ScriptInventory counts must represent unique script NUMBERS (130), not total files (132)
   - Scripts 0009 and 0530 have 2 files each by design
   - Count unique numbers: `ls -1 automation-scripts/*.ps1 | sed 's/.*\///;s/_.*//' | sort -u | wc -l`

**To add tests**:
1. Use Pester 5.0+ syntax
2. Place in `tests/unit/` or `tests/integration/`
3. Name file `*.Tests.ps1`
4. Use `TestHelpers.psm1` for common utilities
5. Run with `Invoke-Pester -Path <path> -Output Detailed`

## Platform Differences

Use platform checks for Windows-specific features:
- Hyper-V: Windows only
- WSL2: Windows only
- Certificate Authority: Windows only
- All other tools: Cross-platform (PowerShell 7+)

Check exit codes: 0=success, 1=error, 3010=restart required

## Build, Test, and Validation Commands

**CRITICAL**: Always run these commands in the exact order specified. Commands have been tested and timing verified.

### Initial Setup (Required Once)

```powershell
# New installation (first time) - Takes ~2-5 minutes
./bootstrap.ps1 -Mode New -InstallProfile Minimal

# Update existing installation - Takes ~30-60 seconds  
./bootstrap.ps1 -Mode Update -InstallProfile Minimal

# CI/CD environment setup - Takes ~3-8 minutes
./bootstrap.ps1 -Mode New -InstallProfile Full
```

**Important**: 
- Bootstrap MUST run first - it sets up `$env:AITHERZERO_ROOT` and loads critical modules
- Use `-InstallProfile Minimal` for development (fastest)
- Use `-InstallProfile Full` for CI/CD (all features)
- Never skip bootstrap - the module system depends on it

### Validation Commands (Run Before Making Changes)

**Always validate before starting work** to understand existing issues:

```powershell
# 1. Syntax validation - Takes ~1-2 seconds for all 457 files
./automation-scripts/0407_Validate-Syntax.ps1 -All
# Or use the global wrapper:
aitherzero 0407 -All

# 2. PSScriptAnalyzer - Takes ~75 seconds for full codebase
./automation-scripts/0404_Run-PSScriptAnalyzer.ps1
# Or:
aitherzero 0404

# 3. Unit tests - Takes ~54 seconds (may have 5-15 known failures)
./automation-scripts/0402_Run-UnitTests.ps1
# Or:
aitherzero 0402
```

**Timing Expectations**:
- Syntax validation: 1-2 seconds
- PSScriptAnalyzer: 60-90 seconds (516 files)
- Unit tests: 45-60 seconds (74 test files, ~3000+ assertions)
- Integration tests: 120-180 seconds (if applicable)

**Known Issues to Ignore**:
- PSScriptAnalyzer: ~4305 informational issues (mostly trailing whitespace, BOM)
- PSScriptAnalyzer: 5 errors in Security.Tests.ps1 (test data with ConvertTo-SecureString)
- Unit tests: 5-10 failures in 0700-0799 range (metadata format issues in newer scripts)

### Testing Commands (Run After Making Changes)

```powershell
# Test syntax only for changed files
./automation-scripts/0407_Validate-Syntax.ps1 -FilePath ./path/to/changed.ps1

# Run PSScriptAnalyzer on specific path
./automation-scripts/0404_Run-PSScriptAnalyzer.ps1 -Path ./domains/utilities

# Run tests for specific domain
Invoke-Pester -Path "./tests/domains/configuration" -Output Detailed

# Run single test file
Invoke-Pester -Path "./tests/unit/Configuration.Tests.ps1" -Output Detailed

# Run all tests (comprehensive)
./automation-scripts/0409_Run-AllTests.ps1
```

### Quality Validation (Before Committing)

```powershell
# Comprehensive quality check - Takes ~2-3 minutes
./automation-scripts/0420_Validate-ComponentQuality.ps1 -Path ./domains/utilities

# Checks performed:
# - Error handling (try/catch patterns)
# - Logging implementation (Write-CustomLog usage)
# - Test coverage (Pester tests exist)
# - UI integration (proper Write-UIText usage)
# - PSScriptAnalyzer compliance
# - GitHub Actions integration
```

### Common Command Sequences

**For feature development:**
```powershell
# 1. Bootstrap (if needed)
./bootstrap.ps1 -Mode Update -InstallProfile Minimal

# 2. Validate baseline
aitherzero 0407 -All && aitherzero 0404

# 3. Make your changes
# ...

# 4. Test your changes
aitherzero 0407 -All
aitherzero 0404 -Path ./path/to/changed
Invoke-Pester -Path "./tests/unit/YourTest.Tests.ps1"

# 5. Final validation
aitherzero 0420 -Path ./path/to/changed
```

**For bug fixes:**
```powershell
# 1. Reproduce the issue
# 2. Run existing tests to confirm failure
aitherzero 0402

# 3. Fix the issue
# 4. Verify tests pass
aitherzero 0402

# 5. Run quality validation
aitherzero 0420 -Path ./path/to/fixed
```

### CI/CD Integration

The GitHub Actions workflows use these exact commands:

```yaml
# PR Validation (.github/workflows/pr-validation.yml)
- Bootstrap minimal environment
- Run syntax validation: aitherzero 0407 -All
- Comment results on PR

# Comprehensive Tests (.github/workflows/comprehensive-test-execution.yml)  
- Bootstrap minimal environment
- Install testing tools: ./automation-scripts/0400_Install-TestingTools.ps1
- Run unit tests: ./automation-scripts/0402_Run-UnitTests.ps1
- Run integration tests: ./automation-scripts/0403_Run-IntegrationTests.ps1
- Aggregate and report results
```

### Troubleshooting Build Failures

**Issue**: Module loading errors
```powershell
# Solution: Clean and re-bootstrap
./bootstrap.ps1 -Mode Clean
./bootstrap.ps1 -Mode New -InstallProfile Minimal
```

**Issue**: "Command not found: az"
```powershell
# Solution: az.ps1 must be called with ./ prefix in repository root
cd /path/to/AitherZero
aitherzero 0407
```

**Issue**: Pester tests fail with "Module not found"
```powershell
# Solution: Ensure bootstrap ran successfully
Import-Module ./AitherZero.psd1 -Force
```

**Issue**: PSScriptAnalyzer timeout
```powershell
# Solution: Run on specific path instead of entire codebase
aitherzero 0404 -Path ./domains/utilities
```

### Before Making Changes

1. **Always bootstrap first**: `./bootstrap.ps1 -Mode Update`
2. **Validate baseline**: `aitherzero 0407 -All && aitherzero 0404` 
3. **Review known issues**: Ignore the 5 errors in Security.Tests.ps1
4. **Check transcript logs**: `logs/transcript-*.log` for detailed errors
5. **Understand timing**: Budget 2-3 minutes for full validation cycle

## Acceptance Criteria

All code changes must meet these requirements:
- **Tests**: All existing tests must pass. Add new tests for new functionality.
- **Linting**: Code must pass PSScriptAnalyzer validation (`az 0404`)
- **Syntax**: PowerShell syntax must be valid (`az 0407`)
- **Documentation**: Update relevant documentation for public API changes
- **Module Exports**: New functions must be added to `Export-ModuleMember` lists
- **Logging**: Use `Write-CustomLog` for all log messages (with error handling)
- **Cross-Platform**: Verify compatibility on Windows, Linux, and macOS where applicable
- **No Breaking Changes**: Maintain backward compatibility unless explicitly required

## Security and Privacy Guidelines

### Sensitive Data Handling
- **Never commit secrets**: No API keys, passwords, tokens, or credentials in code
- **Use credential management**: Leverage the `security/` domain for secure credential storage
- **Certificate handling**: All certificate operations must use the certificate management domain
- **Environment variables**: Use `.env` files (excluded from git) for sensitive configuration

### Code Security
- **Input validation**: Validate all external inputs and user-provided parameters
- **Error messages**: Don't expose sensitive information in error messages or logs
- **File permissions**: Set appropriate permissions on generated files (especially credentials)
- **Audit logging**: Security-related operations should be logged to transcript files

### Infrastructure Security
- **Network isolation**: Lab VMs should be on isolated networks by default
- **Admin rights**: Minimize operations requiring elevated privileges
- **Resource cleanup**: Always clean up resources (VMs, certificates) when no longer needed

## Communication Guidelines

### Working with Issues
- Read issue descriptions carefully and understand requirements before starting
- Ask clarifying questions if requirements are ambiguous
- Break down large tasks into smaller, manageable steps
- Report progress frequently with clear status updates

### Pull Request Standards
- Keep PRs focused on a single issue or feature
- Write clear, descriptive commit messages following conventional commits format
- Include test results and validation steps in PR description
- Reference the issue number in commit messages and PR description

### Code Review Expectations
- Address all review comments or explain why changes weren't made
- Run full test suite before marking PR as ready for review
- Update documentation to reflect code changes
- Ensure CI/CD pipelines pass before requesting review

## Task Workflow Guidelines

### Planning Phase
1. **Understand**: Read and comprehend the full issue/task
2. **Research**: Review related code, tests, and documentation
3. **Plan**: Outline approach and identify affected components
4. **Validate**: Confirm plan addresses all requirements

### Implementation Phase
1. **Small Changes**: Make minimal, focused changes to accomplish the goal
2. **Test Often**: Run tests after each significant change
3. **Validate Early**: Use linting and syntax checking frequently
4. **Document**: Update comments and docs as you code

### Verification Phase
1. **Self-Review**: Review your own changes for quality and completeness
2. **Test Coverage**: Verify all code paths have test coverage
3. **Integration**: Test with related components and workflows
4. **Documentation**: Ensure all docs are updated and accurate

### Completion Phase
1. **Final Tests**: Run complete test suite including PSScriptAnalyzer
2. **Clean Code**: Remove debug code, commented code, and temporary files
3. **PR Description**: Write comprehensive description of changes and testing
4. **Handoff**: Ensure reviewer has all context needed

This consolidated architecture ensures reliable module loading and provides powerful orchestration capabilities through the number-based system.

## GitHub Copilot Integration

AitherZero includes comprehensive GitHub Copilot enhancement features to make AI-assisted development more effective.

### Copilot Prompt Library

**IMPORTANT**: The `.github/prompts/` directory contains reusable one-shot prompts for common tasks. **Use these prompts first** before attempting manual troubleshooting.

#### Available Prompts

**Troubleshooting:**
- `github-actions-troubleshoot.md` - Fix workflow failures, missing PR checks
- `test-failure-triage.md` - Analyze and fix test failures
- `pr-validation-failures.md` - Resolve PR validation issues
- `troubleshoot-ci-cd.md` - Debug CI/CD pipeline problems

**Development:**
- `use-aitherzero-workflows.md` - **START HERE** - Learn number-based scripts and playbooks
- `add-new-feature.md` - Add features following AitherZero patterns
- `fix-powershell-quality.md` - Address PSScriptAnalyzer warnings
- `refactor-function.md` - Refactor PowerShell code

**Testing & Quality:**
- `manage-test-reports.md` - Test results, dashboard, GitHub Pages
- `write-pester-tests.md` - Create Pester tests
- `fix-test-infrastructure.md` - Fix test system issues

**Documentation:**
- `generate-docs.md` - Generate function documentation
- `update-readme.md` - Update README files

#### How to Use Prompts

1. **Reference by name in chat:**
   ```
   @copilot Use the github-actions-troubleshoot prompt to fix workflows
   ```

2. **Follow prompt instructions:**
   Each prompt contains step-by-step commands and checks

3. **Start with use-aitherzero-workflows:**
   If you're new to AitherZero, use this prompt first to learn the system

4. **Combine prompts:**
   ```
   @copilot Use use-aitherzero-workflows to run tests,
   then use test-failure-triage if any fail
   ```

#### When Workflows Break

**ALWAYS** use `github-actions-troubleshoot.md` prompt first when:
- PR checks disappear or don't run
- Workflows fail with YAML errors
- All workflows suddenly stop working

This prompt systematically diagnoses and fixes common issues like:
- YAML syntax errors (emoji in names, unescaped colons)
- Branch trigger mismatches
- Circular workflow dependencies
- Trailing whitespace

### Custom Agent Routing

The repository uses `.github/copilot.yaml` to route work to specialized agents based on expertise:

- **Maya Infrastructure** (Infrastructure): Hyper-V, OpenTofu/Terraform, networking, VM management
- **Sarah Security** (Security): Certificates, credentials, compliance, vulnerability scanning
- **Jessica Testing** (Testing): Pester, test automation, quality assurance
- **Emma Frontend** (Frontend/UX): Console UI, menus, wizards, user experience
- **Marcus Backend** (Backend): PowerShell modules, APIs, performance optimization
- **Olivia Documentation** (Documentation): Technical writing, guides, documentation
- **Rachel PowerShell** (PowerShell): Scripting, automation, orchestration
- **David ProjectManager** (Project Manager): Planning, coordination, releases

**Usage**: Agents are auto-suggested based on file patterns. Invoke manually with `/agent-name` or `@agent-name` in Copilot Chat.

### Model Context Protocol (MCP) Servers

MCP servers provide enhanced context and capabilities for AI-assisted development. Configuration in `.github/mcp-servers.json`:

#### Available MCP Servers

1. **filesystem** - Repository navigation and file operations
   - Read/write access to AitherZero codebase
   - Navigate domain structure, automation scripts, tests
   - Search across PowerShell modules and configurations

2. **github** - Issues, PRs, repository metadata via GitHub API
   - Create and manage issues, pull requests
   - Access repository metadata, labels, milestones
   - Search code and commit history
   - Requires `GITHUB_TOKEN` environment variable

3. **git** - Version control operations and history
   - View commit history and diffs
   - Check branch status and changes
   - Analyze repository structure
   - Track code evolution

4. **powershell-docs** - PowerShell best practices and documentation
   - Fetch cmdlet documentation from Microsoft Learn
   - Access PowerShell GitHub repository info
   - Get best practices for PowerShell development
   - Restricted to Microsoft and GitHub domains

5. **sequential-thinking** - Complex problem-solving and planning
   - Break down complex infrastructure tasks
   - Structured multi-step planning
   - Architecture design thinking
   - Problem decomposition for automation

#### Using MCP Servers with AitherZero

MCP servers integrate seamlessly with AitherZero's workflows:

**Example workflows using MCP servers:**

```
# Use filesystem server to analyze domain structure
@workspace How is the infrastructure domain organized?

# Use git server to track changes
@workspace Show recent changes to OrchestrationEngine.psm1

# Use github server for issue management
@workspace Create issue for improving VM deployment error handling

# Use powershell-docs for best practices
@workspace What's the best practice for parameter validation in PowerShell 7?

# Use sequential-thinking for complex tasks
@workspace Help me design a multi-VM deployment workflow with network isolation

# Combine multiple servers
@workspace Review recent commits to testing domain, check for best practices, and suggest improvements
```

**Integration with number-based scripts:**

```
# MCP servers can help understand and execute automation scripts
@workspace Explain what script 0402 does and show me how to run it

# Get context for orchestration
@workspace Show me the playbook structure and explain test-quick playbook

# Troubleshoot failures
@workspace Script 0404 failed - show me the recent changes and PSScriptAnalyzer errors
```

**Setup**: Requires Node.js 18+ and `GITHUB_TOKEN` environment variable. See [docs/COPILOT-MCP-SETUP.md](../docs/COPILOT-MCP-SETUP.md) for complete setup instructions.

### Development Environment

Optimized VS Code and DevContainer configurations available:

- **`.devcontainer/`**: Pre-configured development container with all tools
- **`.vscode/settings.json`**: PowerShell, Copilot, and editor settings
- **`.vscode/tasks.json`**: Common operations (test, lint, validate, report)
- **`.vscode/launch.json`**: Debug configurations for scripts and tests
- **`.vscode/extensions.json`**: Recommended extensions list

**Quick Start**: Open in VS Code and use "Reopen in Container" or install recommended extensions for local setup.

See [docs/COPILOT-DEV-ENVIRONMENT.md](../docs/COPILOT-DEV-ENVIRONMENT.md) for complete setup guide.

### Git Hooks for Quality Assurance

AitherZero includes pre-commit hooks to prevent common issues:

**To enable hooks:**
```bash
git config core.hooksPath .githooks
```

**Available hooks:**
- **pre-commit**: Validates `config.psd1` before committing changes
  - Runs `0413_Validate-ConfigManifest.ps1` automatically
  - Blocks commits with invalid config
  - Prevents CI failures from config issues

**Why use hooks:**
1. **Early detection** - Catches issues before pushing to CI
2. **Fast feedback** - Immediate validation (no CI wait time)
3. **Prevents mistakes** - Automated checks for all contributors
4. **Saves time** - Fix issues locally, not after PR submission

**For AI agents:**
When modifying `config.psd1`, the hook will automatically validate before commit. If validation fails:
1. Review the error output
2. Fix the issues in config.psd1
3. Run validation manually: `./automation-scripts/0413_Validate-ConfigManifest.ps1`
4. Retry the commit

See [.githooks/README.md](../.githooks/README.md) for complete hook documentation.

### Effective Copilot Usage

**Leverage agents for specialized work**:
```
/infrastructure Help design a VM network topology
@sarah Review certificate storage security
@jessica Create Pester tests for new module
```

**Use MCP servers for context**:
```
@workspace Show recent commits to testing domain
@workspace What's PowerShell best practice for error handling?
@workspace Create issue for documentation update
```

**Combine MCP servers with AitherZero workflows**:
```
# Leverage filesystem + git + sequential-thinking together
@workspace Analyze the OrchestrationEngine module structure, recent changes, 
and help me design a new workflow for parallel test execution

# Use github + powershell-docs for quality improvements
@workspace Review open issues related to error handling and suggest 
PowerShell best practices for improving them

# Integrate with number-based scripts
@workspace Explain how scripts 0400-0499 work together and create a test report
```

**Provide architectural context**:
```
@workspace Following AitherZero patterns, create a new utility
function with proper logging, error handling, and cross-platform support
```

### MCP Server Best Practices for AitherZero

When working with MCP servers in AitherZero:

1. **Filesystem server**: Use to understand domain organization and find related functions
2. **Git server**: Track changes before making modifications, understand code evolution
3. **GitHub server**: Manage issues/PRs without leaving VS Code, link code to tasks
4. **PowerShell-docs server**: Validate PowerShell patterns against best practices
5. **Sequential-thinking server**: Break down complex infrastructure tasks into steps

**Common patterns**:
- Start with filesystem to explore, then git to understand history
- Use sequential-thinking for architectural decisions
- Verify PowerShell code against documentation server
- Create issues via GitHub server for tracking work

### AI Development Guidelines

When using AI assistance:

1. **Always reference architecture**: Mention number-based system, domain structure
2. **Specify quality requirements**: Logging, error handling, tests, cross-platform
3. **Use appropriate agents**: Route to specialist for better results
4. **Validate AI suggestions**: Run linters, tests, and manual verification
5. **Iterate incrementally**: Make small changes, test frequently
6. **Document decisions**: Update comments and docs for AI context

## Quick Reference Summary

### Essential Commands (Copy & Use)

```powershell
# Setup (run once)
./bootstrap.ps1 -Mode New -InstallProfile Minimal

# Validate before changes (baseline check)
aitherzero 0407 -All && aitherzero 0404

# Test after changes
aitherzero 0407 -All
Invoke-Pester -Path "./tests/unit/YourTest.Tests.ps1"

# Quality check before commit
aitherzero 0420 -Path ./path/to/changed
```

### Critical Success Factors

1. **ALWAYS run bootstrap first** - Sets up environment, loads modules
2. **Trust these instructions** - All commands have been tested and validated
3. **Use exact timing estimates** - Budget 2-3 minutes for validation cycle
4. **Ignore known issues** - 5 errors in Security.Tests.ps1 are expected (test data)
5. **Check logs on failure** - `logs/transcript-*.log` has detailed errors
6. **Module load order matters** - Logging first, then Configuration, then others
7. **Export functions explicitly** - Must be in Export-ModuleMember lists
8. **Config is king** - Everything driven by `config.psd1` manifest

### Common Mistakes to Avoid

1. ❌ Skipping bootstrap → ✅ Always run `./bootstrap.ps1 -Mode Update` first
2. ❌ Not having `aitherzero` in PATH → ✅ Run bootstrap to install it globally
3. ❌ Forgetting Export-ModuleMember → ✅ Add function to export list
4. ❌ Adding function without tests → ✅ Create matching `*.Tests.ps1` file
5. ❌ Hardcoding values → ✅ Use `config.psd1` or `Get-Configuration`
6. ❌ Using Write-Host → ✅ Use `Write-CustomLog` or `Write-UIText`
7. ❌ Breaking cross-platform → ✅ Check `$IsWindows`, `$IsLinux`, `$IsMacOS`
8. ❌ Stopping on known failures → ✅ Verify failures match expected list
9. ❌ **Using `gh` CLI in workflows** → ✅ **Use `actions/github-script@v7` instead**
10. ❌ **Creating issues from PowerShell in CI** → ✅ **Let workflow handle it via github-script**

### When Things Go Wrong

**"Module not found" errors**:
```powershell
Import-Module ./AitherZero.psd1 -Force
```

**"Command not found: aitherzero"**:
```powershell
# Run bootstrap to install the global command
./bootstrap.ps1 -Mode Update

# Or use direct script invocation
./automation-scripts/0407_Validate-Syntax.ps1 -All
```

**Tests failing unexpectedly**:
```powershell
# Check if bootstrap ran successfully
$env:AITHERZERO_INITIALIZED -eq 'true'
# If false, re-run bootstrap
./bootstrap.ps1 -Mode Update
```

**PSScriptAnalyzer timeout**:
```powershell
# Run on specific path instead
aitherzero 0404 -Path ./domains/utilities
```

**Issue creation failures in CI**:
```powershell
# Check if script is trying to create issues in CI
# Should skip and let workflow handle it
if ($env:GITHUB_ACTIONS -eq 'true') {
    # Correct - workflow will create issues via actions/github-script
}
```

### File Locations at a Glance

| File/Directory | Purpose | Size/Count |
|----------------|---------|------------|
| `AitherZero.psd1` | Module manifest | 192 functions |
| `AitherZero.psm1` | Root module loader | ~300 lines |
| `config.psd1` | Master configuration | 1476 lines |
| `bootstrap.ps1` | Setup script | ~900 lines |
| `automation-scripts/` | Numbered scripts | 125 scripts |
| `domains/` | Functional modules | 11 domains |
| `tests/` | Test suite | ~74 test files |
| `.github/workflows/` | CI/CD pipelines | 17 workflows |

### Validation Checklist

Before submitting code changes:

- [ ] Bootstrap completed successfully
- [ ] Syntax validation passes (`aitherzero 0407 -All`)
- [ ] PSScriptAnalyzer passes or issues documented (`aitherzero 0404`)
- [ ] Unit tests pass (`aitherzero 0402`)
- [ ] Quality validation passes (`aitherzero 0420 -Path <changed>`)
- [ ] Functions exported in Export-ModuleMember
- [ ] Comment-based help added (`.SYNOPSIS`, etc.)
- [ ] Tests created for new functionality
- [ ] Cross-platform compatibility verified
- [ ] Transcript logs checked (`logs/transcript-*.log`)
- [ ] Config changes validated (`aitherzero 0413`)

### Performance Expectations

| Command | Expected Time | Notes |
|---------|---------------|-------|
| `bootstrap.ps1 -Mode New -InstallProfile Minimal` | 2-5 minutes | First time only |
| `bootstrap.ps1 -Mode Update` | 30-60 seconds | Updates |
| `aitherzero 0407 -All` | 1-2 seconds | 457 files |
| `aitherzero 0404` | 60-90 seconds | 516 files |
| `aitherzero 0402` | 45-60 seconds | ~74 test files |
| `aitherzero 0420 -Path <path>` | 30-120 seconds | Per component |
| Full validation cycle | 2-3 minutes | All checks |

---

**Remember**: These instructions are the result of comprehensive testing and exploration. Trust the commands, timing, and sequences documented here. Only search for additional information if something fails unexpectedly or if requirements have changed.

**Version**: 2.0 - Comprehensive validated instructions for AitherZero
**Last Updated**: 2025-11-02
**Validated Against**: AitherZero 2.0.0 (525 PowerShell files, 125 scripts, 11 domains, 192 functions)
