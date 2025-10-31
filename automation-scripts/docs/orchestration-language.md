# AitherZero Number-Based Orchestration Language

## Overview

AitherZero introduces a revolutionary number-based orchestration language that allows you to control complex infrastructure deployments and configurations using simple number sequences. This approach provides an extremely high-level programming interface where numbers become commands.

## Core Concept

Every automation script is assigned a 4-digit number (0000-9999) that represents:
- **Execution priority** (lower numbers run first)
- **Functional category** (number ranges group related operations)
- **Unique identifier** (for dependency management)

## Language Syntax

### Basic Operations

```powershell
# Single script
seq 0001

# Multiple scripts
seq 0001,0002,0005

# Range
seq 0000-0099

# Wildcard (all 02xx scripts)
seq 02*

# Exclusion
seq 0000-0099,!0050

# Stage-based
seq stage:Core

# Tag-based
seq tag:database
```

### Advanced Syntax

```powershell
# Complex combinations
seq 0000-0099,stage:Core,02*,!0208

# Conditional execution
seq 0000-0299 -Variables @{Environment="Production"}

# Parallel with concurrency
seq 0200-0299 -MaxConcurrency 8

# Dry run
seq 0000-0499 -DryRun
```

## Number Ranges and Categories

### 0000-0099: Environment Preparation
- System prerequisites
- Directory creation
- Environment cleanup
- PowerShell 7 installation

### 0100-0199: Core Infrastructure
- Network configuration
- Virtualization setup
- Certificate authorities
- System configuration

### 0200-0299: Development Tools
- Programming languages
- Development environments
- Package managers
- Version control

### 0300-0399: Services & Applications
- Application deployment
- Service configuration
- Container orchestration

### 0400-0499: Configuration
- System customization
- User preferences
- Advanced settings

### 0500-0599: Validation & Testing
- Environment validation
- Health checks
- Integration tests

### 9000-9999: Maintenance & Cleanup
- System cleanup
- Log rotation
- Temporary file removal

## Script Metadata

Each script can include metadata that enhances orchestration:

```powershell
#Requires -Version 7.0
# Stage: Infrastructure
# Dependencies: Git, PowerShell7
# Description: Deploy cloud infrastructure
# Tags: cloud, deployment, terraform
# Condition: Features -contains 'CloudProvider'
```

## Execution Modes

### Interactive Mode
```powershell
# Start interactive menu
.\Start-AitherZero.ps1
```

### Direct Orchestration
```powershell
# Run specific sequence
.\Start-AitherZero.ps1 -Mode Orchestrate -Sequence "0000-0099"

# Run with profile
.\Start-AitherZero.ps1 -Profile Developer -NonInteractive
```

### Playbook Mode
```powershell
# Run saved playbook
.\Start-AitherZero.ps1 -Mode Orchestrate -Playbook "production-deploy"
```

## Creating Custom Scripts

### Script Template
```powershell
#Requires -Version 7.0
# Stage: YourStage
# Dependencies: Dep1, Dep2
# Description: What this script does
# Tags: tag1, tag2
# Condition: Variable -eq 'Value'

[CmdletBinding()]
param(
    [Parameter()]
    [hashtable]$Configuration
)

# Initialize logging
$script:LoggingAvailable = $false
try {
    $loggingPath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/utilities/Logging.psm1"
    if (Test-Path $loggingPath) {
        Import-Module $loggingPath -Force -Global
        $script:LoggingAvailable = $true
    }
} catch {}

function Write-ScriptLog {
    param([string]$Message, [string]$Level = 'Information')
    if ($script:LoggingAvailable) {
        Write-CustomLog -Message $Message -Level $Level
    } else {
        Write-Host "[$Level] $Message"
    }
}

try {
    Write-ScriptLog "Starting script execution"

    # Your logic here
    
    Write-ScriptLog "Script completed successfully"
    exit 0
} catch {
    Write-ScriptLog "Script failed: $_" -Level 'Error'
    exit 1
}
```

## Playbook Format

```json
{
  "Name": "production-deploy",
  "Description": "Production environment deployment",
  "Sequence": [
    "0000-0099",
    "stage:Infrastructure",
    "0300",
    "0500"
  ],
  "Variables": {
    "Environment": "Production",
    "Features": ["LoadBalancer", "AutoScaling"]
  },
  "Profile": "Full",
  "Version": "1.0"
}
```

## CI/CD Integration

### GitHub Actions
```yaml
- name: Deploy with AitherZero
  shell: pwsh
  run: |
    ./Start-AitherZero.ps1 -Mode Orchestrate `
      -Sequence "${{ env.DEPLOY_SEQUENCE }}" `
      -NonInteractive
```

### Azure DevOps
```yaml
- task: PowerShell@2
  inputs:
    filePath: './Start-AitherZero.ps1'
    arguments: '-Mode Orchestrate -Sequence "0000-0299,0300" -NonInteractive'
```

### Jenkins
```groovy
stage('Deploy') {
    steps {
        pwsh '''
            ./Start-AitherZero.ps1 -Mode Orchestrate \
              -Playbook "jenkins-deploy" \
              -NonInteractive
        '''
    }
}
```

## Best Practices

1. **Number Assignment**
   - Group related scripts in same range
   - Leave gaps for future scripts
   - Use meaningful script names after numbers

2. **Dependency Management**
   - Explicitly declare dependencies
   - Use stages for logical grouping
   - Test dependency chains with dry-run

3. **Error Handling**
   - Make scripts idempotent
   - Use proper exit codes
   - Log all operations

4. **Performance**
   - Use parallel execution for independent scripts
   - Set appropriate concurrency limits
   - Monitor resource usage

## Examples

### Minimal Setup
```powershell
# Just the essentials
seq 0000-0002,0001,0207
```

### Full Development Environment
```powershell
# Everything for development
seq stage:Prepare,stage:Core,stage:Development,0500
```

### Production Deployment
```powershell
# Production with validation
$prodVars = @{
    Environment = "Production"
    SkipTests = $false
    Features = @("HA", "Monitoring")
}
seq 0000-0399,0500 -Variables $prodVars -ContinueOnError
```

### Disaster Recovery
```powershell
# Quick recovery sequence
seq 9000,0000-0099,0105,0300 -MaxConcurrency 10
```

## Troubleshooting

### View Execution Plan
```powershell
seq 0000-0099 -DryRun
```

### Debug Single Script
```powershell
& ./automation-scripts/0201_Install-Node.ps1 -Configuration $config -Verbose
```

### Check Script Dependencies
```powershell
Get-Content ./automation-scripts/0201_Install-Node.ps1 | Select-String "^# Dependencies:"
```

### Validate Environment
```powershell
seq 0500
```

## Advanced Features

### Dynamic Sequences
```powershell
# Build sequence based on conditions
$seq = @("0000-0099")
if ($IsWindows) { $seq += "0105" }
if (Test-Path "./k8s") { $seq += "tag:kubernetes" }
seq $seq
```

### Custom Conditions
```powershell
# Scripts run only when conditions are met
# In script: # Condition: OSVersion -ge '10.0'
seq 0000-0299 -Conditions @{OSVersion = [Environment]::OSVersion.Version}
```

### Event Hooks
```powershell
# Run actions before/after sequences
$hooks = @{
    PreExecute = { Write-Log "Starting deployment" }
    PostExecute = { Send-Notification "Deployment complete" }
}
seq 0000-0299 -Hooks $hooks
```

## Security

- Scripts run with current user privileges
- Sensitive data should use secure configuration
- Validate all inputs in custom scripts
- Use `-WhatIf` for production changes
- Implement proper access controls

## Future Enhancements

- Web-based orchestration UI
- Real-time execution monitoring
- Distributed execution across nodes
- AI-powered sequence optimization
- Natural language to number sequence translation