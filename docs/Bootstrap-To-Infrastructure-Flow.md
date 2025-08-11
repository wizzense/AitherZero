# Bootstrap to Infrastructure Deployment Flow

This document demonstrates the complete execution flow from initial bootstrap to full infrastructure deployment in AitherZero.

## Overview

The flow consists of 7 main phases:

1. **Initial Bootstrap** - System validation and core module initialization
2. **Environment Preparation** (0000-0099) - Clean environment and install prerequisites  
3. **Infrastructure Prerequisites** (0007-0009) - Install Go, OpenTofu, and initialize
4. **Orchestration Engine Execution** - Process playbooks and manage execution
5. **Infrastructure Components** (0100-0199) - Install Hyper-V and other infrastructure
6. **Infrastructure Deployment** (0300) - Deploy actual infrastructure with OpenTofu
7. **Validation & Completion** - Verify deployment and save state

## Detailed Flow

### Phase 1: Initial Bootstrap

```powershell
# 1. User executes bootstrap
./bootstrap.ps1

# Bootstrap performs:
- PowerShell version check (requires v7+)
- OS platform detection (Windows/Linux/macOS)
- Admin rights check (warns if not admin)
- Creates initial directory structure
- Imports aitherzero.psm1
- Loads initial configuration
```

### Phase 2: Environment Preparation

```powershell
# Using orchestration engine
seq 0000-0002,0006

# Executes:
- 0000_Cleanup-Environment.ps1    # Clean temp files, old logs
- 0001_Ensure-PowerShell7.ps1     # Install/verify PS7
- 0002_Setup-Directories.ps1      # Create project structure
- 0006_Install-ValidationTools.ps1 # PSScriptAnalyzer, Pester
```

### Phase 3: Infrastructure Prerequisites

```powershell
# Install OpenTofu toolchain
seq 0007-0009

# Executes:
- 0007_Install-Go.ps1              # Go language for provider
- 0008_Install-OpenTofu.ps1        # Infrastructure as Code tool
- 0009_Initialize-OpenTofu.ps1     # Configure providers
```

### Phase 4: Use Orchestration Playbook

```powershell
# Option 1: Interactive UI
./orchestration/Start-OrchestrationUI.ps1

# Option 2: Non-interactive with playbook
./orchestration/Start-OrchestrationUI.ps1 -Playbook infrastructure-lab -NonInteractive

# Option 3: Direct orchestration engine
Import-Module ./domains/automation/OrchestrationEngine.psm1
Invoke-OrchestrationSequence -LoadPlaybook infrastructure-lab
```

The `infrastructure-lab` playbook contains:
```json
{
  "Name": "infrastructure-lab",
  "Description": "Infrastructure lab setup with OpenTofu and Hyper-V",
  "Sequence": [
    "0000",   # Cleanup
    "0001",   # PowerShell 7
    "0002",   # Directories
    "0007",   # Go
    "0008",   # OpenTofu
    "0009",   # Initialize OpenTofu
    "0105",   # Hyper-V
    "0300"    # Deploy Infrastructure
  ],
  "Variables": {
    "Profile": "Infrastructure",
    "Environment": "Lab",
    "Features": ["Go", "OpenTofu", "HyperV"]
  }
}
```

### Phase 5: Infrastructure Components

```powershell
# The orchestration engine executes:
- 0105_Install-HyperV.ps1

# This script:
- Enables Windows Feature: Microsoft-Hyper-V
- Installs Hyper-V PowerShell module
- Installs management tools
- Returns exit code 3010 (restart required)
```

### Phase 6: Infrastructure Deployment

```powershell
# After restart (if needed), continue:
- 0300_Deploy-Infrastructure.ps1

# This script:
1. Loads infrastructure configuration
2. Validates OpenTofu is initialized
3. Runs: tofu plan
4. If approved, runs: tofu apply
5. Creates:
   - Virtual networks (Internal, External)
   - Virtual machines per configuration
   - Network configurations
```

### Phase 7: Complete Flow Example

Here's the complete execution from start to finish:

```powershell
# 1. Clone repository and bootstrap
git clone https://github.com/yourorg/AitherZero.git
cd AitherZero
./bootstrap.ps1

# 2. Run infrastructure deployment playbook
./orchestration/Start-OrchestrationUI.ps1 -Playbook infrastructure-lab -NonInteractive

# 3. Monitor progress
# The UI will show:
# - Progress bars for each script
# - Success/failure status
# - Restart requirements
# - Final summary

# 4. Handle restart if needed
if ($LASTEXITCODE -eq 3010) {
    Write-Host "Restart required. After restart, run:"
    Write-Host "seq 0300"  # Continue with deployment
}

# 5. Verify deployment
seq 0500-0501  # Validation scripts
```

## Execution Patterns

### Sequential Execution
```powershell
# Traditional sequential flow
Invoke-OrchestrationSequence -Sequence "0000-0300" -Parallel $false
```

### Parallel Execution with Dependencies
```powershell
# Default - respects dependencies
Invoke-OrchestrationSequence -Sequence "0000-0300"

# Executes in batches:
# Batch 1: 0000, 0001, 0002 (no dependencies)
# Batch 2: 0006, 0007 (depends on directories)
# Batch 3: 0008 (depends on Go)
# Batch 4: 0009, 0105 (depends on OpenTofu)
# Batch 5: 0300 (depends on all above)
```

### Custom Sequences
```powershell
# Just infrastructure components
seq 0105,0106,0112

# All development tools
seq 02*

# Specific stage
seq stage:Infrastructure
```

## State Management

The orchestration engine maintains state throughout execution:

```powershell
# State is tracked in:
- ExecutionContext.Results      # Script results
- ExecutionContext.Variables    # Runtime variables
- Logs in ./logs/orchestration  # Detailed execution logs

# Checkpoint/Resume capability:
Get-OrchestrationStatus  # Check current state
```

## Error Handling

```powershell
# Default: Stop on first error
Invoke-OrchestrationSequence -Sequence "0000-0300"

# Continue on error
Invoke-OrchestrationSequence -Sequence "0000-0300" -ContinueOnError

# Dry run to test
Invoke-OrchestrationSequence -Sequence "0000-0300" -DryRun
```

## Integration Points

1. **Configuration System**
   - Loads from `config.json`
   - Merges playbook variables
   - Passes to each script

2. **Logging System**
   - All scripts log to unified system
   - Available in `./logs/`
   - Structured JSON format

3. **UI System**
   - Interactive menus
   - Progress tracking
   - Notifications

4. **Infrastructure Module**
   - OpenTofu integration
   - State management
   - Provider abstraction

## Testing the Flow

The Pester tests in `/tests/integration/Bootstrap-To-Infrastructure.Tests.ps1` validate:

1. Each phase executes correctly
2. Dependencies are resolved
3. Parallel execution works
4. Error handling functions
5. State is maintained
6. UI integration works

Run tests with:
```powershell
Invoke-Pester ./tests/integration/Bootstrap-To-Infrastructure.Tests.ps1 -Output Detailed
```

## Summary

The complete flow from bootstrap to infrastructure:

1. **Bootstrap** validates and initializes the system
2. **Orchestration engine** manages script execution with advanced patterns
3. **Playbooks** define reusable deployment scenarios
4. **Scripts** perform atomic operations (idempotent where possible)
5. **Infrastructure module** handles OpenTofu/Terraform operations
6. **UI module** provides user-friendly interaction
7. **State** is tracked throughout for reliability

This architecture ensures reliable, repeatable infrastructure deployment with proper error handling, progress tracking, and state management.