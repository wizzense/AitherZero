# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Quick Commands

```powershell
# Bootstrap - Auto-detects if install or init needed
./bootstrap.ps1                     # PowerShell 7+ 
./bootstrap.sh                      # Unix/Linux/macOS
iwr -useb https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap-ps5.ps1 | iex  # PowerShell 5.1

# Main entry point
./Start-AitherZero.ps1              # Interactive UI
./Start-AitherZero.ps1 -Help        # Show help
./Start-AitherZero.ps1 -Version     # Check version

# Testing
./Start-AitherZero.ps1 -Mode Test   # Run all tests
Invoke-Pester -Path "./tests/unit/Configuration.Tests.ps1" -Output Detailed  # Single test file
Invoke-Pester -Path "./tests/domains/configuration" -CodeCoverage "./domains/configuration/*.psm1"  # With coverage
az 0402                              # Run unit tests via orchestration
seq 0402,0404,0407                  # Test sequence: unit tests, PSScriptAnalyzer, syntax validation

# Automated Test Fixing
./automation-scripts/claude-test-fix.sh           # Fix all failing tests autonomously
./automation-scripts/claude-test-fix.sh --status  # Check test fix status
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-fix-workflow -NonInteractive  # Via orchestration

# Validation & Linting
az 0404                              # PSScriptAnalyzer
az 0407                              # Validate PowerShell syntax
az 0440                              # Validate GitHub Actions workflows
seq 0440,0407,0404                  # Full validation sequence

# Development Workflow
az 0701 -Type feature -Name "my-feature" -Force           # Create feature branch
az 0702 -Type feat -Message "add feature" -NonInteractive # Conventional commit
az 0703 -Title "Add feature" -NonInteractive              # Create PR
az 0510 -ShowAll                                          # Generate project report
az 0511                                                   # Show dashboard

# Playbooks (Orchestrated Workflows)
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick   # Fast validation
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-full    # Complete test suite
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-fix-workflow  # Fix failing tests

# Direct orchestration
Invoke-OrchestrationSequence -Sequence "0402,0404,0407"
seq 0000-0099                       # Run environment prep scripts

# Common Issue Fix Commands  
fix-tests                           # Fix all failing tests automatically
fix-tests --reset                   # Reset tracker and start fresh
fix-tests --loops 5                 # Fix specific number of issues
fix-tests --status                  # Show current fix status
```

## High-Level Architecture

AitherZero is an infrastructure automation platform using a **number-based orchestration system** (0000-9999) for systematic script execution.

### Core Module Loading

```
AitherZero.psd1 (Module Manifest)
    └── AitherZero.psm1 (Root Module)
        ├── Sets $env:AITHERZERO_ROOT and $env:AITHERZERO_INITIALIZED
        ├── Starts PowerShell transcript logging (logs/transcript-*.log)
        ├── Imports all domain modules in specific order:
        │   1. utilities/Logging.psm1 (CRITICAL - other modules depend on it)
        │   2. configuration/Configuration.psm1
        │   3. experience/BetterMenu.psm1 (MUST load before UserInterface)
        │   4. experience/UserInterface.psm1
        │   5. development/* (Git, Issues, PRs)
        │   6. testing/TestingFramework.psm1
        │   7. reporting/* (ReportingEngine, TechDebt)
        │   8. automation/* (OrchestrationEngine exports Invoke-OrchestrationSequence)
        │   9. infrastructure/Infrastructure.psm1
        └── Creates 'az' and 'seq' aliases
```

### Number-Based Orchestration System

Scripts in `/automation-scripts/` are numbered:
- **0000-0099**: Environment preparation
- **0100-0199**: Infrastructure (Hyper-V, certificates, networking)
- **0200-0299**: Development tools (Git, Node, Python, Docker, VS Code, AI)
- **0300-0399**: Infrastructure deployment (OpenTofu/Terraform)
- **0400-0499**: Testing & validation (Pester, PSScriptAnalyzer)
- **0500-0599**: Reporting & metrics
- **0700-0799**: Development automation (Git, PRs, AI tools)
  - **0751-0758**: Test-fix workflow scripts for autonomous test fixing
- **0800-0899**: Issue tracking & session management
- **9000-9999**: Maintenance & cleanup

### Test-Fix Workflow Architecture

The test-fix workflow (`test-fix-workflow.psd1`) automates test failure resolution:

1. **0751**: Load test tracker (test-fix-tracker.json)
2. **0752**: Process test results, identify failures
3. **0753**: Create GitHub issues for tracking
4. **0754**: **Call Claude CLI to fix the test** (90 second timeout)
5. **0755**: Validate the fix by running the test
6. **0756**: Commit successful fixes

Key script: `0754_Fix-SingleTestFailure.ps1`:
- Builds clear prompt with test failure details
- Calls Claude CLI as a command-line tool
- Waits up to 90 seconds for Claude to complete
- Checks git diff for changes
- Marks issue as validating if changes detected

### Configuration System

Hierarchical configuration with precedence:
1. Command-line parameters (highest)
2. Environment variables (`AITHERZERO_*`)
3. `config.local.psd1` (gitignored)
4. `config.psd1` (main config)
5. CI defaults (auto-detected)
6. Script defaults (lowest)

```powershell
# Access configuration
Import-Module ./domains/configuration/Configuration.psm1
$value = Get-ConfiguredValue -Name 'Profile' -Section 'Core' -Default 'Standard'
```

### Playbook System

Playbooks in `/orchestration/playbooks/` (JSON) or `/orchestration/playbooks-psd1/` (PowerShell Data):
- Define multi-stage workflows
- Support variables and conditions
- Can be run via UI or command line
- Key playbooks: `test-quick`, `test-full`, `test-fix-workflow`

### Critical Patterns

1. **Module Scoping**: Functions in scriptblocks may lose scope - call directly
2. **Cross-Platform Paths**: Check `$IsWindows/$IsLinux/$IsMacOS`
3. **Logging**: Use `Write-CustomLog` when available via Get-Command check
4. **Array Count**: Wrap pipeline results in `@()` to ensure .Count works
5. **Claude CLI Integration**: Call as simple command with prompt, check git diff for changes

### Common Issues

1. **Test Fix Timeout**: Claude CLI needs 30-90 seconds to analyze and fix tests
2. **Module Load Order**: Logging.psm1 must load first, BetterMenu before UserInterface
3. **Playbook Variables**: Use literal values in playbooks, not variable references
4. **PowerShell 5.1**: No `&&` operator support - use separate commands
5. **Git Operations**: Always check current branch before commits/PRs

### CI/CD Integration

Auto-detects CI environments and applies defaults:
- GitHub Actions: `GITHUB_ACTIONS=true`
- Azure DevOps: `TF_BUILD=true`  
- GitLab CI: `GITLAB_CI=true`
- Sets NonInteractive, full profile, coverage enabled

```yaml
# GitHub Actions example
- run: |
    ./bootstrap.ps1
    ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-ci
```

### Development Tips

1. Run `./bootstrap.ps1` to initialize (safe to run multiple times)
2. Use `az` wrapper for automation scripts
3. Check `logs/transcript-*.log` for session history
4. Create playbooks for repetitive tasks
5. Test with `seq 0404` (PSScriptAnalyzer) before committing
6. For test failures, use test-fix workflow for autonomous fixing