# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Quick Commands

```powershell
# Bootstrap - Intelligently installs or initializes based on context
./bootstrap.ps1                     # PowerShell 7+ (auto-detects if install or init needed)
./bootstrap.sh                      # Unix/Linux/macOS (auto-detects if install or init needed)
iwr -useb https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap-ps5.ps1 | iex  # PowerShell 5.1 (installs PS7 first)

# Main entry point - Interactive UI
./Start-AitherZero.ps1

# Testing - Use orchestration or direct Pester commands
./Start-AitherZero.ps1 -Mode Orchestrate -Sequence 0402     # Run unit tests
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick -NonInteractive  # Quick test suite
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-full -NonInteractive   # Full test suite
./Start-AitherZero.ps1 -Mode Test                   # Run all tests (Test mode)

# Run single test file
Invoke-Pester -Path "./tests/unit/Configuration.Tests.ps1" -Output Detailed
Invoke-Pester -Path "./tests" -TestName "*ModuleName*"

# Run tests with coverage for specific module
Invoke-Pester -Path "./tests/domains/configuration" -CodeCoverage "./domains/configuration/*.psm1"

# Common development commands using 'az' wrapper
az 0402                 # Run unit tests with coverage
az 0404                 # Run PSScriptAnalyzer validation
az 0407                 # Validate PowerShell syntax
az 0440                 # Validate GitHub Actions workflows
az 0441 -InstallDependencies  # Set up local workflow testing with act
az 0510 -ShowAll        # Generate comprehensive project report
az 0511                 # Show project dashboard

# Git workflow automation
az 0701 -Type feature -Name "my-feature" -Force           # Create feature branch
az 0702 -Type feat -Message "add feature" -NonInteractive # Create conventional commit
az 0703 -Title "Add feature" -NonInteractive              # Create pull request

# Test playbooks
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick   # Fast validation (4 stages)
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-full    # Complete test suite (6 stages)
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-ci      # CI/CD pipeline tests
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook tdd-development-cycle  # TDD workflow
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook workflow-validation  # Validate GitHub workflows

# Workflow testing and validation
az 0440 -Path .github/workflows -All        # Validate all workflows
az 0440 -Path .github/workflows/ci.yml -Strict  # Strict validation of specific workflow
az 0441 -WorkflowFile pr-validation.yml -Event pull_request  # Test workflow locally with act
seq 0440,0407,0404                          # Full workflow validation sequence

# Direct orchestration sequences (bypasses UI)
Invoke-OrchestrationSequence -Sequence "0000-0099" -Configuration $Config
Invoke-OrchestrationSequence -Sequence "0402,0404,0407" -DryRun

# Tech debt analysis
seq 0520-0524           # Run complete tech debt analysis with report

# Cross-platform
./az                    # Unix/Linux command wrapper
az.cmd                  # Windows batch wrapper
```

## High-Level Architecture

AitherZero is an infrastructure automation platform using a **number-based orchestration system** (0000-9999) for systematic script execution.

### Core Module Loading Architecture

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

Scripts in `/automation-scripts/` are numbered 0000-9999:
- **0000-0099**: Environment preparation (cleanup, PowerShell 7, directories)
- **0100-0199**: Infrastructure (Hyper-V, certificates, networking)
- **0200-0299**: Development tools (Git, Node, Python, Docker, VS Code, AI tools)
- **0300-0399**: Infrastructure deployment (OpenTofu/Terraform)
- **0400-0499**: Testing & validation (Pester, PSScriptAnalyzer, coverage)
- **0500-0599**: Reporting & metrics (system info, project reports, dashboards)
- **0700-0799**: Development automation (Git branches, commits, PRs, AI tools)
- **0800-0899**: Issue tracking & session management
- **9000-9999**: Maintenance & cleanup

### Key Architectural Patterns

1. **Module Scoping Issues**: Functions called in scriptblocks (like Show-UISpinner) may not have access to imported functions. Call directly instead:
   ```powershell
   # Wrong - may fail in scriptblocks
   Show-UISpinner { Write-CustomLog "Processing..." }
   
   # Right - call functions directly
   Write-CustomLog "Processing..."
   Show-UISpinner { Start-Process $command }
   ```

2. **Cross-Platform Paths**: Always check `$IsWindows/$IsLinux/$IsMacOS` and use appropriate paths:
   ```powershell
   if ($IsWindows) { 'C:/temp' } else { "$HOME/.aitherzero/temp" }
   $tempPath = if ($IsWindows) { $env:TEMP } else { '/tmp' }
   ```

3. **Logging Pattern**: Each module should use dynamic command detection:
   ```powershell
   if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
       Write-CustomLog -Message "..." -Level 'Information'
   }
   ```

4. **Orchestration Range Expansion**: Ranges like "0000-0199" only include scripts that actually exist (handled in ConvertTo-ScriptNumbers function)

5. **UI Components**: 
   - UserInterface.psm1 uses Write-UIText which requires `[AllowEmptyString()]` for empty messages
   - Show-UIMenu doesn't have a -UseInteractive parameter (remove if found in examples)

### Common Issues and Fixes

1. **DateTime Conversion Errors**: Ensure timing variables are initialized before try blocks:
   ```powershell
   $startTime = Get-Date  # Initialize before try block
   ```

2. **Missing Functions**: Check module exports. Functions must be in Export-ModuleMember list.

3. **Unapproved Verbs**: Use approved PowerShell verbs (Get-Verb). "Flush" → "Clear", "Process" → "Invoke", etc.

4. **Script Parameter Errors**: Variables in playbooks shouldn't be passed as script parameters unless the script accepts them.

5. **Cleanup Safety**: The 0000_Cleanup-Environment.ps1 script has safety guards to prevent deleting the current project.

6. **PowerShell 5.1 Compatibility**: Use separate commands instead of `&&` operator which isn't supported in PS 5.1.

7. **Array Wrapping for Count**: Wrap pipeline results in @() to ensure .Count property works:
   ```powershell
   $files = @(Get-ChildItem | Where-Object { ... })
   ```

### Configuration System

AitherZero uses PowerShell Data Files (.psd1) for configuration with hierarchical precedence:

1. Command-line parameters (highest priority)
2. Environment variables (`AITHERZERO_*`)
3. `config.local.psd1` (local overrides, gitignored)
4. `config.psd1` (main configuration)
5. CI defaults (auto-applied when CI detected)
6. Script defaults (lowest priority)

**Key Features:**
- **Zero-parameter CI/CD**: Automatically detects CI environments (GitHub Actions, Azure DevOps, GitLab, etc.)
- **Get-ConfiguredValue Helper**: Unified API for accessing configuration with fallbacks
- **PSScriptAnalyzer Settings**: Integrated into config.psd1 under `Testing.PSScriptAnalyzer`

```powershell
# Use in scripts
Import-Module ./domains/configuration/Configuration.psm1
$ProfileName = Get-ConfiguredValue -Name 'Profile' -Section 'Core' -Default 'Standard'
```

Key configuration sections:
- `Core.Profile`: Minimal, Standard, Developer, Full
- `Core.Environment`: Development, Testing, Production, CI (auto-detected)
- `Automation.MaxConcurrency`: Parallel execution limit
- `Automation.NonInteractive`: No prompts (auto-true in CI)
- `Testing.Profile`: Quick, Standard, Full, CI
- `Testing.PSScriptAnalyzer`: Linting rules and settings

### Testing Framework

```powershell
# Common test patterns
Describe "ModuleName" {
    BeforeAll {
        Import-Module ./domains/module/Module.psm1 -Force
    }
    
    Context "FunctionName" {
        It "Should do something" {
            $result = Invoke-Function
            $result | Should -Be $expected
        }
    }
}
```

Test structure:
- `/tests/unit/` - Unit tests for individual functions and scripts
- `/tests/integration/` - Integration tests for module interactions
- `/tests/domains/` - Domain-specific tests

PSScriptAnalyzer configuration now in `config.psd1`:
- Excludes: PSAvoidUsingWriteHost, PSUseShouldProcessForStateChangingFunctions
- Rules: PSProvideCommentHelp, PSUseCompatibleSyntax, PSUseCorrectCasing

### Playbook System

Playbooks are JSON files in `/orchestration/playbooks/`:
```json
{
  "Name": "playbook-name",
  "Description": "What this playbook does",
  "Sequence": ["0402", "0404", "0407"],
  "Variables": {},
  "Profile": "Standard"
}
```

Create playbooks via UI or:
```powershell
Save-OrchestrationPlaybook -Name "test" -Sequence @("0402","0404") -Description "Run tests"
```

Notable playbooks:
- `tdd-development-cycle`: Enforces Test-Driven Development with automatic reporting
- `test-quick`: Fast validation (4 stages)
- `test-full`: Complete test suite (6 stages)
- `test-ci`: CI/CD pipeline tests
- `workflow-validation`: GitHub Actions validation

### Important Module Interdependencies

1. **Logging.psm1** must load first - many modules depend on Write-CustomLog
2. **Configuration.psm1** loads early - provides config to other modules  
3. **BetterMenu.psm1** must load before UserInterface.psm1
4. **OrchestrationEngine.psm1** exports critical Invoke-OrchestrationSequence function

### Development Workflow Best Practices

1. Run `./bootstrap.ps1` or `./bootstrap.sh` to initialize environment (safe to run multiple times)
2. Use `az` wrapper for automation scripts - it ensures environment is loaded
3. Test changes with `seq 0404` (PSScriptAnalyzer) before committing
4. Create playbooks for repetitive task sequences
5. Check logs/transcript-*.log for complete session history
6. Use approved PowerShell verbs (Get-Verb to check)

### Cross-Platform Considerations

- Path separators: Use `Join-Path` or `[System.IO.Path]::Combine()`
- User detection: `if ($IsWindows) { [System.Security.Principal.WindowsIdentity]::GetCurrent().Name } else { $env:USER }`
- Computer name: `$env:COMPUTERNAME ?? $env:HOSTNAME`
- Temp paths: `if ($IsWindows) { $env:TEMP } else { '/tmp' }`
- Platform-specific features: Hyper-V, WSL2, Certificate Authority are Windows-only

### Exit Codes Convention

- `0`: Success
- `1`: General error
- `2`: Execution error
- `3010`: Restart required (Windows)

### CI/CD Integration

AitherZero automatically detects CI environments and applies appropriate defaults:

**Auto-detected environments:**
- GitHub Actions (`GITHUB_ACTIONS=true`)
- Azure DevOps (`TF_BUILD=true`)
- GitLab CI (`GITLAB_CI=true`)
- Jenkins (`JENKINS_URL` exists)
- Generic CI (`CI=true`)

**CI Default Behaviors:**
- Profile: Full
- NonInteractive: true
- Environment: CI
- WhatIf: false
- RunCoverage: true

```yaml
# GitHub Actions - zero configuration needed
- name: Run AitherZero
  run: |
    ./bootstrap.ps1
    ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-ci
```