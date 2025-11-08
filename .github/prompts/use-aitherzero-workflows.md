# Use AitherZero Workflows Prompt

Learn and use AitherZero's number-based script system and orchestration playbooks to manage this project.

## One-Shot Learning Prompt

```
@copilot Teach me AitherZero workflows and help me use them:

1. Initialize environment:
   ./Initialize-AitherEnvironment.ps1
   Explains: Sets up modules, logging, environment variables

2. Number-based script system:
   az [number]  # Execute automation scripts
   
   Ranges:
   0000-0099: Environment prep (PowerShell 7, directories)
   0100-0199: Infrastructure (Hyper-V, certificates, networking)
   0200-0299: Dev tools (Git, Node, Python, Docker, VS Code)
   0400-0499: Testing & validation
   0500-0599: Reporting & metrics
   0700-0799: Git automation & AI tools
   9000-9999: Maintenance & cleanup

3. Common commands I should use:
   az 0402              # Run unit tests
   az 0404              # Run PSScriptAnalyzer
   az 0407              # Syntax validation
   az 0510 -ShowAll     # Project report

4. Orchestration playbooks:
   ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook [name]
   
   Available playbooks:
   - test-quick: Fast validation
   - test-full: Complete test suite
   - test-phase1-validation: Phase 1 test reporting validation
   - test-phase1-production: Production test execution

5. Show me what I need to do RIGHT NOW for this PR
```

## AitherZero Architecture

### Core Components

```
AitherZero.psd1 (Module Manifest)
    └── AitherZero.psm1 (Root Module)
        ├── Sets $env:AITHERZERO_ROOT
        ├── Starts transcript logging
        ├── Loads Logging, Configuration first
        └── Loads domain modules sequentially
```

### Domain Structure

Located in `/aithercore/`:

| Domain | Functions | Purpose |
|--------|-----------|---------|
| **infrastructure/** | 57 | Lab automation, VMs, networking |
| **configuration/** | 36 | Config management, environments |
| **utilities/** | 24 | Logging, maintenance, helpers |
| **security/** | 41 | Credentials, certificates |
| **experience/** | 22 | UI components, menus, wizards |
| **automation/** | 16 | Orchestration engine, workflows |

### Number-Based Scripts

Scripts in `/automation-scripts/` follow numeric ranges:

```powershell
# Environment & Setup (0000-0099)
# Note: PowerShell 7 is installed by bootstrap.ps1
az 0010  # Create directory structure

# Infrastructure (0100-0199)
az 0101  # Setup Hyper-V
az 0150  # Create certificates
az 0160  # Configure networking

# Development Tools (0200-0299)
az 0201  # Install Git
az 0210  # Setup VS Code
az 0220  # Install Docker

# Testing & Validation (0400-0499)
az 0402  # Run unit tests
az 0403  # Run integration tests
az 0404  # Run PSScriptAnalyzer
az 0407  # Syntax validation
az 0409  # Run all tests

# Reporting & Metrics (0500-0599)
az 0510  # Generate project report
az 0512  # Generate dashboard
az 0520  # Test coverage report

# Git & AI Tools (0700-0799)
az 0701  # Create Git branch
az 0702  # Commit changes
az 0703  # Create PR

# Maintenance (9000-9999)
az 9001  # Cleanup logs
az 9010  # Reset environment
```

## Common Workflows

### Workflow 1: Run Tests

```powershell
# Initialize (always first in new session)
./Initialize-AitherEnvironment.ps1

# Run unit tests
az 0402

# Run PSScriptAnalyzer
az 0404

# Run syntax validation
az 0407

# Generate test report
az 0510 -ShowAll
```

### Workflow 2: Use Orchestration Playbooks

```powershell
# Quick validation (fast)
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick

# Full test suite (comprehensive)
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-full

# Phase 1 validation (test reporting)
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-phase1-validation

# Phase 1 production (complete tests + dashboard)
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-phase1-production
```

### Workflow 3: Git Operations

```powershell
# Create feature branch
az 0701 -Type feature -Name "my-feature"

# Commit changes
az 0702 -Type feat -Message "add new feature"

# Create PR
az 0703 -Title "Add new feature" -Body "Description"
```

### Workflow 4: Generate Reports

```powershell
# Project overview
az 0510

# Detailed report with all metrics
az 0510 -ShowAll

# Generate dashboard
az 0512

# Test coverage
az 0520
```

## Orchestration Playbooks

Located in `/aithercore/orchestration/playbooks/`:

### Testing Playbooks

**test-quick.json**
```json
{
  "name": "Quick Validation",
  "description": "Fast validation for rapid feedback",
  "steps": [
    { "script": "0407", "name": "Syntax Check" },
    { "script": "0402", "name": "Unit Tests", "config": { "Fast": true } }
  ]
}
```

**test-full.json**
```json
{
  "name": "Full Test Suite",
  "description": "Comprehensive testing",
  "steps": [
    { "script": "0407" },
    { "script": "0402" },
    { "script": "0403" },
    { "script": "0404" },
    { "script": "0510" }
  ]
}
```

**test-phase1-validation.json**
- Test discovery validation
- Format checks
- Quick execution (can skip tests)

**test-phase1-production.json**
- Pre-flight checks
- Complete test execution
- Result aggregation
- Dashboard generation
- Coverage analysis

## Configuration System

Config files in `/`:

```powershell
# Main config
config.psd1

# Example/template
config.example.psd1
```

Hierarchical loading:
1. Default values in code
2. config.psd1 file
3. Playbook variables
4. Command-line parameters

Key sections:
```powershell
@{
    Core = @{
        Profile = 'Standard'  # Minimal, Standard, Developer, Full
    }
    Automation = @{
        MaxConcurrency = 4    # Parallel execution limit
    }
    Testing = @{
        Profile = 'Standard'  # Quick, Standard, Full, CI
    }
}
```

## Critical Development Patterns

### 1. Module Scope in ScriptBlocks

```powershell
# WRONG - may fail in scriptblocks
Show-UISpinner { Write-CustomLog "Processing..." }

# RIGHT - call functions directly
Write-CustomLog "Processing..."
Show-UISpinner { Start-Process $command }
```

### 2. Cross-Platform Paths

```powershell
$path = if ($IsWindows) { 
    'C:/temp' 
} else { 
    "$HOME/.aitherzero/temp" 
}
```

### 3. Logging Pattern

```powershell
if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
    Write-CustomLog -Message "Processing..." -Level 'Information'
} else {
    Write-Verbose "Processing..."
}
```

### 4. Error Handling

```powershell
try {
    # Operation
    $result = Invoke-Command -ScriptBlock $operation
    
    Write-CustomLog -Message "Success" -Level 'Success'
    return $result
}
catch {
    Write-CustomLog -Message "Failed: $_" -Level 'Error'
    throw
}
```

## File Locations

| Path | Purpose |
|------|---------|
| `/automation-scripts/` | Numbered scripts (0000-9999) |
| `/aithercore/` | PowerShell modules by domain |
| `/aithercore/orchestration/playbooks/` | Workflow definitions |
| `/tests/` | Pester tests (unit + integration) |
| `/reports/` | Generated reports and metrics |
| `/logs/` | Transcript logs |
| `/config.psd1` | Configuration |
| `Start-AitherZero.ps1` | Main entry point |
| `Initialize-AitherEnvironment.ps1` | Environment setup |

## Quick Reference

### Essential Commands

```powershell
# Setup
./Initialize-AitherEnvironment.ps1

# Testing
az 0402              # Unit tests
az 0404              # PSScriptAnalyzer
az 0407              # Syntax check
az 0409              # All tests

# Reporting
az 0510              # Project report
az 0512              # Dashboard

# Playbooks
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-full
```

### Check Status

```powershell
# Environment initialized?
$env:AITHERZERO_INITIALIZED

# Root directory
$env:AITHERZERO_ROOT

# View logs
Get-Content ./logs/transcript-*.log -Tail 50

# Test results
Get-ChildItem ./reports -Filter "TestReport-*.json"
```

## Platform Differences

Use platform checks for Windows-specific features:

```powershell
if ($IsWindows) {
    # Hyper-V (Windows only)
    az 0101
    
    # WSL2 (Windows only)
    az 0105
    
    # Certificate Authority (Windows only)
    az 0150
}
else {
    # Cross-platform alternatives
    # Docker, Podman, etc.
}
```

Exit codes:
- `0`: Success
- `1`: Error
- `3010`: Restart required

## Example: Complete Testing Workflow

```powershell
# 1. Initialize environment (new session)
./Initialize-AitherEnvironment.ps1

# 2. Validate syntax
az 0407
if ($LASTEXITCODE -ne 0) {
    Write-Host "Syntax errors found!"
    exit 1
}

# 3. Run unit tests
az 0402
if ($LASTEXITCODE -ne 0) {
    Write-Host "Unit tests failed!"
}

# 4. Run PSScriptAnalyzer
az 0404

# 5. Generate comprehensive report
az 0510 -ShowAll

# 6. View results
Get-Content ./reports/TestReport-Aggregated-*.json | ConvertFrom-Json | Format-List
```

## Example: Add New Feature

```powershell
# 1. Create feature branch
az 0701 -Type feature -Name "new-vm-management"

# 2. Add code to appropriate domain
# aithercore/infrastructure/VMManagement.psm1

# 3. Add tests
# tests/unit/VMManagement.Tests.ps1

# 4. Run validation
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick

# 5. Commit
az 0702 -Type feat -Message "add VM snapshot management"

# 6. Create PR
az 0703 -Title "Add VM Snapshot Management"
```

## Troubleshooting

### Module Not Loading

```powershell
# Check if initialized
$env:AITHERZERO_INITIALIZED

# Re-initialize
./Initialize-AitherEnvironment.ps1

# Check logs
Get-Content ./logs/transcript-*.log -Tail 100
```

### Script Not Found

```powershell
# List available scripts
Get-ChildItem ./automation-scripts/*.ps1 | Select-Object Name

# Check script number
ls ./automation-scripts/*0402*
```

### Playbook Not Found

```powershell
# List available playbooks
Get-ChildItem ./aithercore/orchestration/playbooks/ -Recurse -Filter "*.json"

# Validate playbook JSON
Get-Content ./aithercore/orchestration/playbooks/testing/test-quick.json | ConvertFrom-Json
```

## When to Use This Prompt

Use this prompt when:

- ✅ New to AitherZero project
- ✅ Don't know which command to run
- ✅ Need to run tests properly
- ✅ Want to use playbooks
- ✅ Creating new features
- ✅ Generating reports
- ✅ Git operations
- ✅ Understanding project structure

## Related Prompts

- **add-new-feature.md** - Add features following AitherZero patterns
- **test-failure-triage.md** - Fix test failures
- **manage-test-reports.md** - Work with test results
- **github-actions-troubleshoot.md** - Fix CI/CD issues

## Example Usage

```
@copilot I need to run all tests for this PR using AitherZero. 
Use use-aitherzero-workflows prompt to guide me step-by-step.
```

Copilot will:
1. Tell you to run Initialize-AitherEnvironment.ps1
2. Guide you through az 0402, az 0404, az 0407
3. Show you how to generate reports
4. Explain test results
5. Suggest fixes for failures
