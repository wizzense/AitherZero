# AitherZero Orchestration Engine

A powerful number-based orchestration language for automating complex deployments and configurations.

## Quick Start

```powershell
# Import the orchestration engine
Import-Module ./domains/automation/OrchestrationEngine.psm1

# Run setup using number sequences
seq 0000-0099  # Environment preparation
seq 0201,0207  # Install Node.js and Git
seq stage:Core # Run all core stage scripts
```

## Number Sequence Language

### Basic Syntax

- **Single Script**: `0001` - Run script 0001
- **Range**: `0001-0099` - Run scripts 0001 through 0099
- **List**: `0001,0005,0201` - Run specific scripts
- **Wildcard**: `02*` - Run all 0200-0299 scripts
- **Exclusion**: `0000-0099,!0050` - Run range except 0050
- **Stage**: `stage:Infrastructure` - Run all scripts in stage
- **Tags**: `tag:database` - Run all scripts with tag

### Examples

```powershell
# Minimal setup
seq 0000-0002,0001,0207

# Development environment
seq stage:Prepare,stage:Core,02*

# Infrastructure deployment
seq 0000-0099,0105,0008,0300

# Everything except Docker
seq 0000-0299,!0208

# Complex orchestration
Invoke-OrchestrationSequence -Sequence "0000-0299,stage:Infrastructure" -Variables @{
    Environment = "Production"
    Features = @("HyperV", "Kubernetes")
} -MaxConcurrency 8
```

## Playbooks

Save and reuse common sequences:

```powershell
# Save current sequence as playbook
seq 0001,0207,0201,0105 -SavePlaybook "my-setup"

# Load and run playbook
seq -LoadPlaybook "my-setup"

# Run predefined playbooks
seq -LoadPlaybook "minimal-setup"
seq -LoadPlaybook "dev-environment"
seq -LoadPlaybook "hyperv-lab"
```

## Script Metadata

Scripts can include metadata for advanced orchestration:

```powershell
#Requires -Version 7.0
# Stage: Infrastructure
# Dependencies: Git, PowerShell7
# Description: Deploy infrastructure
# Tags: deployment, infrastructure
# Condition: Environment -eq 'Production'
```

### Metadata Fields

- **Stage**: Logical grouping (Prepare, Core, Infrastructure, Development, Services, Configuration, Validation)
- **Dependencies**: Required tools or other scripts
- **Description**: Brief description shown in plans
- **Tags**: Labels for tag-based selection
- **Condition**: PowerShell expression for conditional execution

## Conditional Execution

```powershell
# Run with conditions
seq 0000-0299 -Variables @{
    Environment = "Development"
    SkipTests = $false
} -Conditions @{
    Features = @("HyperV", "Docker")
}

# Scripts with conditions only run when true
# Condition: Environment -eq 'Production'
# Condition: Features -contains 'Docker'
# Condition: SkipTests -ne $true
```

## Execution Modes

### Parallel Execution (Default)
```powershell
seq 0000-0099 -Parallel $true -MaxConcurrency 4
```

### Sequential Execution
```powershell
seq 0000-0099 -Parallel $false
```

### Dry Run
```powershell
seq 0000-0099 -DryRun
```

### Continue on Error
```powershell
seq 0000-0099 -ContinueOnError
```

## Non-Interactive Automation

Perfect for CI/CD and automated deployments:

```powershell
# Full automated setup
./bootstrap.ps1 -Mode New -NonInteractive

# Run specific profile
Invoke-OrchestrationSequence -Profile "Developer" -Configuration ./config.json

# Load from environment
$env:AITHERZERO_SEQUENCE = "0000-0299"
$env:AITHERZERO_PROFILE = "Production"
seq $env:AITHERZERO_SEQUENCE
```

## Creating Custom Scripts

1. **Name Format**: `NNNN_ScriptName.ps1`
   - NNNN: 4-digit number (execution order)
   - ScriptName: Descriptive name

2. **Required Structure**:
```powershell
#Requires -Version 7.0
# Stage: YourStage
# Dependencies: Dep1, Dep2
# Description: What this script does

[CmdletBinding()]
param(
    [Parameter()]
    [hashtable]$Configuration
)

# Your script logic here
exit 0  # Success
exit 1  # Failure
```

3. **Exit Codes**:
   - 0: Success
   - 1: General failure
   - 2: Warning/partial success
   - 3010: Success but restart required
   - 200: Special handling needed

## Integration Examples

### PowerShell Profile
```powershell
# Add to $PROFILE
Import-Module C:\AitherZero\domains\automation\OrchestrationEngine.psm1
```

### CI/CD Pipeline
```yaml
# Azure DevOps
- task: PowerShell@2
  inputs:
    targetType: 'inline'
    script: |
      Import-Module ./domains/automation/OrchestrationEngine.psm1
      seq 0000-0299 -Profile "Production" -NonInteractive

# GitHub Actions
- name: Deploy Infrastructure
  shell: pwsh
  run: |
    Import-Module ./domains/automation/OrchestrationEngine.psm1
    seq -LoadPlaybook "production-deploy"
```

### Docker
```dockerfile
FROM mcr.microsoft.com/powershell:latest
COPY . /aitherzero
WORKDIR /aitherzero
RUN pwsh -c "Import-Module ./domains/automation/OrchestrationEngine.psm1; seq 0000-0099"
```

## Advanced Usage

### Custom Profiles
```powershell
# Define in config.json
"Profiles": {
  "CustomProfile": {
    "Description": "My custom setup",
    "Scripts": ["0001", "0207", "stage:Development", "!0208"]
  }
}

# Use profile
seq -Profile "CustomProfile"
```

### Programmatic Access
```powershell
# Get orchestration results
$result = Invoke-OrchestrationSequence -Sequence "0000-0099" -PassThru

# Check results
$result.Completed  # Number of successful scripts
$result.Failed     # Number of failed scripts
$result.Duration   # Total execution time

# Access individual results
foreach ($scriptNum in $result.Results.Completed.Keys) {
    $scriptResult = $result.Results.Completed[$scriptNum]
    Write-Host "$scriptNum completed in $($scriptResult.Duration.TotalSeconds)s"
}
```

### Dynamic Sequence Generation
```powershell
# Build sequence based on system
$sequence = @("0000-0099")  # Always run prep

if ($IsWindows) {
    $sequence += "0105"  # Hyper-V
}

if (Test-Path "./infrastructure") {
    $sequence += "0300"  # Deploy infrastructure
}

seq $sequence
```

## Troubleshooting

### View Execution Plan
```powershell
seq 0000-0099 -DryRun
```

### Enable Verbose Logging
```powershell
$VerbosePreference = 'Continue'
seq 0000-0099
```

### Debug Specific Script
```powershell
# Run single script with full output
& ./automation-scripts/0201_Install-Node.ps1 -Configuration $config -Verbose
```

### Check Dependencies
```powershell
seq 0500  # Run validation script
```

## Best Practices

1. **Use Stages**: Group related scripts into logical stages
2. **Define Dependencies**: Ensure proper execution order
3. **Make Idempotent**: Scripts should be safe to run multiple times
4. **Handle Errors**: Use proper exit codes and error messages
5. **Test First**: Always dry-run before actual execution
6. **Use Playbooks**: Save common sequences for reuse
7. **Document Scripts**: Use metadata for clarity

## Security Considerations

- Scripts run with current user privileges
- Use `-WhatIf` for safety in production
- Review scripts before execution
- Store sensitive data in secure configuration
- Use conditions to prevent accidental execution

## Performance Tips

- Use parallel execution for independent scripts
- Set appropriate MaxConcurrency based on system
- Group related operations in single scripts
- Use exclusions to skip unnecessary scripts
- Monitor system resources during execution