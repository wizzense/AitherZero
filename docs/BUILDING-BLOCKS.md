# AitherZero Building-Block Automation Guide

**Version**: 2.0  
**Last Updated**: 2025-11-04  
**Status**: Production Ready

## Overview

AitherZero provides a **modular building-block system** for creating custom, extensible automation playbooks. This guide shows you how to combine automation scripts like LEGO blocks to build custom workflows for any endpoint configuration, deployment, or management task.

## Quick Start

```powershell
# 1. Pick your building blocks by number
$myBlocks = @("0001", "0207", "0201", "0402")

# 2. Create a custom playbook
$customPlaybook = @{
    name = "my-custom-setup"
    sequences = $myBlocks
    variables = @{
        Environment = "Production"
        Features = @("Git", "Node")
    }
}

# 3. Execute your playbook
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook "my-custom-setup"
```

## Building-Block Categories

AitherZero's 134 automation scripts are organized into **functional blocks** using a number-based system (0000-9999). Each block is self-contained, parameterized, and can be combined with others.

### 📦 Environment Preparation (0000-0099)

**Purpose**: Set up the base environment before any other automation  
**Platform**: Cross-platform (Windows, Linux, macOS)

| Block | Description | Dependencies | Duration |
|-------|-------------|--------------|----------|
| `0000` | Cleanup-Environment | None | <1 min |
| `0001` | Ensure-PowerShell7 | None | 2-5 min |
| `0002` | Setup-Directories | None | <1 min |
| `0003` | Sync-ConfigManifest | None | <1 min |
| `0006` | Install-ValidationTools | PowerShell7 | 2-3 min |
| `0007` | Install-Go | PackageManager | 3-5 min |
| `0008` | Install-OpenTofu | None | 2-4 min |
| `0009` | Initialize-OpenTofu | OpenTofu | 1-2 min |
| `0010` | Setup-MCPServers | Node | 3-5 min |

**Common Use Cases**:
- **Minimal Bootstrap**: `0001,0002,0006`
- **IaC Environment**: `0001,0002,0007,0008,0009`
- **AI Development**: `0001,0002,0006,0010`

### 🏗️ Infrastructure (0100-0199)

**Purpose**: Configure system-level infrastructure and services  
**Platform**: Mostly Windows, some cross-platform

| Block | Description | Platform | Duration |
|-------|-------------|----------|----------|
| `0100` | Configure-System | Cross-platform | 2-5 min |
| `0104` | Install-CertificateAuthority | Windows | 5-10 min |
| `0105` | Install-HyperV | Windows | 5-15 min |
| `0106` | Install-WSL2 | Windows | 10-20 min |
| `0107` | Install-WindowsAdminCenter | Windows | 5-10 min |
| `0112` | Enable-PXE | Windows | 5-10 min |

**Common Use Cases**:
- **Windows Server Setup**: `0100,0104,0107`
- **Hyper-V Lab**: `0105,0104`
- **WSL Development**: `0106,0100`

### 🛠️ Development Tools (0200-0299)

**Purpose**: Install development tools and programming languages  
**Platform**: Cross-platform

| Block | Description | Dependencies | Duration |
|-------|-------------|--------------|----------|
| `0201` | Install-Node | None | 3-5 min |
| `0204` | Install-Poetry | Python | 2-3 min |
| `0205` | Install-Sysinternals | None (Win) | 2-3 min |
| `0206` | Install-Python | None | 5-10 min |
| `0207` | Install-Git | None | 2-5 min |
| `0208` | Install-Docker | None | 10-20 min |
| `0209` | Install-7Zip | None | 2-3 min |
| `0210` | Install-VSCode | None | 5-10 min |
| `0211` | Install-VSBuildTools | None (Win) | 10-20 min |
| `0212` | Install-AzureCLI | None | 5-10 min |
| `0213` | Install-AWSCLI | None | 3-5 min |
| `0214` | Install-Packer | None | 3-5 min |

**Common Use Cases**:
- **Web Development**: `0207,0201,0210,0208`
- **Python Development**: `0207,0206,0204,0210`
- **Cloud Development**: `0207,0201,0212,0213,0208`
- **DevOps Toolkit**: `0207,0208,0214,0212`

### 🧪 Testing & Validation (0400-0499)

**Purpose**: Run tests, quality checks, and validation  
**Platform**: Cross-platform

| Block | Description | Dependencies | Duration |
|-------|-------------|--------------|----------|
| `0400` | Install-TestingTools | PowerShell7 | 2-3 min |
| `0402` | Run-UnitTests | Pester | 5-15 min |
| `0403` | Run-IntegrationTests | Pester | 10-30 min |
| `0404` | Run-PSScriptAnalyzer | PSScriptAnalyzer | 5-10 min |
| `0405` | Validate-AST | None | 2-5 min |
| `0407` | Validate-Syntax | None | 1-2 min |
| `0409` | Run-AllTests | All testing tools | 20-60 min |
| `0420` | Validate-ComponentQuality | Multiple | 5-15 min |

**Common Use Cases**:
- **Quick Validation**: `0407,0402`
- **Pre-Commit Check**: `0407,0402,0404`
- **Full Validation**: `0400,0409,0420`
- **CI Pipeline**: `0400,0402,0403,0404`

### 📊 Reporting & Metrics (0500-0599)

**Purpose**: Generate reports, analyze code, and track metrics  
**Platform**: Cross-platform

| Block | Description | Dependencies | Duration |
|-------|-------------|--------------|----------|
| `0510` | Generate-ProjectReport | None | 2-5 min |
| `0520` | Analyze-CodeQuality | PSScriptAnalyzer | 5-10 min |
| `0530` | Generate-Metrics | Multiple | 3-5 min |

**Common Use Cases**:
- **Status Report**: `0510`
- **Quality Analysis**: `0520,0530`
- **Dashboard Update**: `0510,0520,0530`

### 🔀 Development Workflows (0700-0799)

**Purpose**: Advanced development automation including Git workflows, CI/CD, and AI-powered tools  
**Platform**: Cross-platform

This range is **logically part of Development Tools** but numbered separately for organizational purposes. See [Building-Block Reorganization](./BUILDING-BLOCKS-REORGANIZATION.md) for details.

#### Git Workflows (0700-0709)
| Block | Description | Dependencies | Duration |
|-------|-------------|--------------|----------|
| `0700` | Setup-GitEnvironment | Git | 1-2 min |
| `0701` | Create-FeatureBranch | Git | <1 min |
| `0702` | Create-Commit | Git | <1 min |
| `0703` | Create-PullRequest | Git, GitHub | 1-2 min |
| `0704` | Stage-Files | Git | <1 min |
| `0705` | Push-Branch | Git | <1 min |
| `0709` | Post-PRComment | Git, GitHub | <1 min |

#### GitHub Runners & CI (0720-0729)
| Block | Description | Platform | Duration |
|-------|-------------|----------|----------|
| `0720` | Setup-GitHubRunners | Cross-platform | 5-10 min |
| `0721` | Configure-RunnerEnvironment | Cross-platform | 2-5 min |
| `0722` | Install-RunnerServices | Cross-platform | 3-5 min |
| `0723` | Setup-MatrixRunners | Cross-platform | 5-10 min |

#### AI-Powered Development (0730-0749)
| Block | Description | Dependencies | Duration |
|-------|-------------|--------------|----------|
| `0730` | Setup-AIAgents | MCP | 3-5 min |
| `0731` | Invoke-AICodeReview | AI Provider | 5-15 min |
| `0732` | Generate-AITests | AI Provider | 3-10 min |
| `0733` | Create-AIDocs | AI Provider | 2-5 min |
| `0734` | Optimize-AIPerformance | AI Provider | 5-10 min |
| `0735` | Analyze-AISecurity | AI Provider | 5-10 min |
| `0736` | Generate-AIWorkflow | AI Provider | 2-5 min |
| `0737` | Monitor-AIUsage | AI Provider | 1-2 min |
| `0738` | Train-AIContext | AI Provider | 3-5 min |
| `0739` | Validate-AIOutput | AI Provider | 2-3 min |
| `0740` | Integrate-AITools | AI Provider | 3-5 min |
| `0741` | Generate-AICommitMessage | AI Provider | <1 min |
| `0742` | Create-AIPoweredPR | AI Provider | 2-5 min |
| `0743` | Enable-AutomatedCopilot | GitHub Copilot | 2-3 min |
| `0744` | Generate-AutoDocumentation | AI Provider | 5-15 min |
| `0745` | Generate-ProjectIndexes | AI Provider | 2-5 min |
| `0746` | Generate-AllDocumentation | AI Provider | 10-30 min |

#### MCP Servers (0750-0759)
| Block | Description | Dependencies | Duration |
|-------|-------------|--------------|----------|
| `0750` | Build-MCPServer | Node.js | 2-5 min |
| `0751` | Start-MCPServer | Node.js | <1 min |
| `0752` | Demo-MCPServer | Node.js | 1-2 min |
| `0753` | Use-MCPServer | Node.js | <1 min |
| `0754` | Create-MCPServer | Node.js | 3-5 min |

#### Git Utilities (0798-0799)
| Block | Description | Dependencies | Duration |
|-------|-------------|--------------|----------|
| `0798` | Generate-Changelog | Git | 2-5 min |
| `0799` | Cleanup-OldTags | Git | 1-2 min |

**Common Use Cases**:
- **Feature Workflow**: `0700,0701,0702,0703`
- **AI-Assisted Development**: `0741,0702,0731,0742`
- **CI/CD Setup**: `0720,0721,0722`
- **Documentation Generation**: `0744,0745,0746`

### 🎫 Issue Management & Workflow Automation (0800-0899)

**Purpose**: Automated issue management, testing feedback, and workflow automation  
**Platform**: Cross-platform

#### Issue Management (0800-0829)
| Block | Description | Dependencies | Duration |
|-------|-------------|--------------|----------|
| `0800` | Create-TestIssues | GitHub | 2-5 min |
| `0801` | Parse-PesterResults | Pester | 1-2 min |
| `0805` | Analyze-OpenIssues | GitHub | 2-5 min |
| `0810` | Create-IssueFromTestFailure | GitHub, Pester | 1-2 min |
| `0815` | Setup-IssueManagement | GitHub | 2-3 min |
| `0816` | Monitor-AutomationHealth | None | 2-5 min |
| `0820` | Save-WorkContext | Git | <1 min |
| `0821` | Generate-ContinuationPrompt | AI | 1-2 min |
| `0822` | Test-IssueCreation | GitHub | 1-2 min |
| `0825` | Create-Issues-Manual | GitHub | Variable |

#### Prompt Engineering (0830-0839)
| Block | Description | Dependencies | Duration |
|-------|-------------|--------------|----------|
| `0831` | Prompt-Templates | None | <1 min |
| `0832` | Generate-PromptFromData | AI | 1-2 min |

#### Workflow Validation (0840-0849)
| Block | Description | Dependencies | Duration |
|-------|-------------|--------------|----------|
| `0840` | Validate-WorkflowAutomation | GitHub | 2-5 min |

#### Deployment Automation (0850-0869)
| Block | Description | Dependencies | Duration |
|-------|-------------|--------------|----------|
| `0850` | Deploy-PREnvironment | Docker | 5-15 min |
| `0851` | Cleanup-PREnvironment | Docker | 2-5 min |
| `0852` | Validate-PRDockerDeployment | Docker | 3-5 min |
| `0853` | Quick-Docker-Validation | Docker | 1-2 min |
| `0854` | Manage-PRContainer | Docker | 2-5 min |
| `0860` | Validate-Deployments | Multiple | 5-10 min |

**Common Use Cases**:
- **Test Failure Tracking**: `0801,0810`
- **Issue Management Setup**: `0815,0816`
- **Work Session Management**: `0820,0821`
- **PR Environment**: `0850,0852`
- **Quick Deployment Check**: `0853,0860`

### 🧪 Test Generation & Validation (0900-0999)

**Purpose**: Automated test generation and self-validation  
**Platform**: Cross-platform

| Block | Description | Dependencies | Duration |
|-------|-------------|--------------|----------|
| `0900` | Test-SelfDeployment | Multiple | 10-20 min |
| `0901` | Test-LocalDeployment | Multiple | 5-15 min |
| `0950` | Generate-AllTests | Pester | 10-30 min |

**Common Use Cases**:
- **Self-Validation**: `0900,0901`
- **Test Generation**: `0950`
- **Complete Validation**: `0900,0950`

### 🧹 Maintenance (9000-9999)

**Purpose**: Cleanup, optimization, and system maintenance  
**Platform**: Cross-platform

**Note**: This range is currently reserved but not yet populated with scripts. Future maintenance scripts will be added here.

**Planned Blocks**:
- `9000`: Cleanup-TempFiles
- `9010`: Optimize-System  
- `9100`: Update-Dependencies
- `9200`: Backup-Configuration
- `9500`: Archive-Logs
- `9900`: System-Health-Check

**Common Use Cases** (when implemented):
- **Daily Cleanup**: `9000,9500`
- **System Optimization**: `9010`
- **Maintenance Cycle**: `9000,9100,9200,9500`

## Creating Custom Playbooks

### Method 1: Simple JSON Playbook

Create a minimal playbook for quick custom workflows:

```json
{
  "Name": "my-custom-workflow",
  "Description": "Custom endpoint configuration",
  "Sequence": [
    "0001",
    "0207",
    "0201",
    "0208",
    "0402"
  ],
  "Variables": {
    "Environment": "Production",
    "Features": ["Git", "Node", "Docker"]
  },
  "Profile": "Custom"
}
```

Save as `orchestration/playbooks/custom/my-custom-workflow.json` and run:

```powershell
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook my-custom-workflow
```

### Method 2: Advanced v2.0 Playbook with Profiles

Create a sophisticated playbook with profiles and conditional execution:

```json
{
  "metadata": {
    "name": "custom-endpoint-setup",
    "description": "Configurable endpoint setup with multiple profiles",
    "version": "1.0.0",
    "category": "operations",
    "tags": ["custom", "endpoint", "configuration"],
    "estimatedDuration": "15-30 minutes"
  },
  "requirements": {
    "minimumPowerShellVersion": "7.0",
    "platforms": ["Windows", "Linux", "macOS"]
  },
  "orchestration": {
    "defaultVariables": {
      "installTools": true,
      "runTests": true,
      "environment": "Development"
    },
    "profiles": {
      "minimal": {
        "description": "Minimal installation - core only",
        "variables": {
          "installTools": false,
          "runTests": false
        }
      },
      "standard": {
        "description": "Standard installation with tools",
        "variables": {
          "installTools": true,
          "runTests": true
        }
      },
      "full": {
        "description": "Complete installation with validation",
        "variables": {
          "installTools": true,
          "runTests": true,
          "runAnalysis": true
        }
      }
    },
    "stages": [
      {
        "name": "Environment Setup",
        "description": "Prepare environment",
        "sequences": ["0001", "0002"],
        "continueOnError": false
      },
      {
        "name": "Install Tools",
        "description": "Install development tools",
        "sequences": ["0207", "0201", "0206"],
        "condition": "{{installTools}}",
        "continueOnError": true
      },
      {
        "name": "Validation",
        "description": "Run tests and validation",
        "sequences": ["0402", "0407"],
        "condition": "{{runTests}}",
        "continueOnError": false
      }
    ]
  }
}
```

Run with different profiles:

```powershell
# Minimal profile
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook custom-endpoint-setup -Profile minimal

# Standard profile
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook custom-endpoint-setup -Profile standard

# Full profile
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook custom-endpoint-setup -Profile full
```

### Method 3: Dynamic Playbook from Code

Build playbooks programmatically for complex scenarios:

```powershell
# Build a custom sequence based on conditions
$sequence = @("0001", "0002")  # Always start with basics

# Add tools based on project type
if ($ProjectType -eq "Web") {
    $sequence += @("0207", "0201", "0208")  # Git, Node, Docker
} elseif ($ProjectType -eq "Python") {
    $sequence += @("0207", "0206", "0204")  # Git, Python, Poetry
}

# Add testing for production
if ($Environment -eq "Production") {
    $sequence += @("0402", "0404", "0420")  # Full validation
}

# Execute the dynamic sequence
Import-Module ./domains/automation/OrchestrationEngine.psm1
Invoke-OrchestrationSequence -Sequence ($sequence -join ",") -Variables @{
    Environment = $Environment
    ProjectType = $ProjectType
}
```

## Building-Block Patterns

### Pattern: Multi-Environment Deployment

Deploy to different environments with conditional logic:

```json
{
  "metadata": {
    "name": "multi-env-deploy",
    "description": "Deploy to multiple environments with environment-specific configuration"
  },
  "orchestration": {
    "defaultVariables": {
      "targetEnvironment": "Development"
    },
    "stages": [
      {
        "name": "Base Setup",
        "sequences": ["0001", "0002", "0100"],
        "continueOnError": false
      },
      {
        "name": "Development Setup",
        "sequences": ["0207", "0201", "0210"],
        "condition": "{{targetEnvironment}} -eq 'Development'"
      },
      {
        "name": "Staging Setup",
        "sequences": ["0207", "0208", "0212"],
        "condition": "{{targetEnvironment}} -eq 'Staging'"
      },
      {
        "name": "Production Setup",
        "sequences": ["0207", "0208", "0104"],
        "condition": "{{targetEnvironment}} -eq 'Production'",
        "variables": {
          "SecureMode": true
        }
      },
      {
        "name": "Validation",
        "sequences": ["0402", "0404", "0420"],
        "condition": "{{targetEnvironment}} -eq 'Production'"
      }
    ]
  }
}
```

### Pattern: Parallel Tool Installation

Install multiple tools in parallel for faster setup:

```json
{
  "metadata": {
    "name": "parallel-tools-install",
    "description": "Install development tools in parallel"
  },
  "orchestration": {
    "stages": [
      {
        "name": "Install Core Tools",
        "sequences": ["0207", "0201", "0206", "0208"],
        "parallel": true,
        "maxConcurrency": 4
      }
    ]
  }
}
```

### Pattern: Conditional Feature Installation

Install features based on user selection:

```json
{
  "metadata": {
    "name": "feature-based-install",
    "description": "Install features based on configuration"
  },
  "orchestration": {
    "defaultVariables": {
      "features": ["Git", "Docker"]
    },
    "stages": [
      {
        "name": "Install Git",
        "sequences": ["0207"],
        "condition": "{{features}} -contains 'Git'"
      },
      {
        "name": "Install Node",
        "sequences": ["0201"],
        "condition": "{{features}} -contains 'Node'"
      },
      {
        "name": "Install Docker",
        "sequences": ["0208"],
        "condition": "{{features}} -contains 'Docker'"
      },
      {
        "name": "Install Python",
        "sequences": ["0206"],
        "condition": "{{features}} -contains 'Python'"
      }
    ]
  }
}
```

### Pattern: Error Recovery Workflow

Implement retry logic and error recovery:

```json
{
  "metadata": {
    "name": "resilient-deployment",
    "description": "Deployment with retry and rollback"
  },
  "orchestration": {
    "stages": [
      {
        "name": "Deploy Application",
        "sequences": ["0300"],
        "retries": 3,
        "retryDelay": 10,
        "continueOnError": false,
        "onFailure": {
          "action": "rollback",
          "sequences": ["0310"]
        }
      }
    ]
  }
}
```

## Parameter-Driven Configuration

### Using Variables

All building blocks accept variables through the `$Configuration` parameter:

```powershell
# Pass variables to individual scripts
$config = @{
    Environment = "Production"
    Features = @("Git", "Docker")
    SkipOptional = $true
}

& ./automation-scripts/0207_Install-Git.ps1 -Configuration $config
```

### Common Configuration Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `Environment` | String | Target environment | "Development" |
| `Profile` | String | Installation profile | "Standard" |
| `Features` | Array | Features to enable | [] |
| `SkipOptional` | Boolean | Skip optional components | false |
| `DryRun` | Boolean | Show what would happen | false |
| `Parallel` | Boolean | Enable parallel execution | true |
| `MaxConcurrency` | Integer | Max parallel tasks | 4 |
| `ContinueOnError` | Boolean | Continue after errors | false |
| `Timeout` | Integer | Timeout per script (seconds) | 300 |

### Environment-Specific Variables

```json
{
  "orchestration": {
    "defaultVariables": {
      "logLevel": "Information"
    },
    "profiles": {
      "development": {
        "variables": {
          "logLevel": "Debug",
          "enableTelemetry": false
        }
      },
      "production": {
        "variables": {
          "logLevel": "Warning",
          "enableTelemetry": true,
          "secureMode": true
        }
      }
    }
  }
}
```

## Recipe Library

### Recipe: Developer Workstation Setup

**Purpose**: Set up a complete developer workstation from scratch  
**Duration**: 30-45 minutes

```json
{
  "name": "dev-workstation-complete",
  "sequences": [
    "0001",
    "0002",
    "0207",
    "0201",
    "0206",
    "0208",
    "0210",
    "0400",
    "0402"
  ],
  "variables": {
    "Profile": "Developer",
    "Features": ["Git", "Node", "Python", "Docker", "VSCode"]
  }
}
```

### Recipe: CI/CD Runner Setup

**Purpose**: Configure a CI/CD runner with all tools  
**Duration**: 20-30 minutes

```json
{
  "name": "cicd-runner-setup",
  "sequences": [
    "0001",
    "0002",
    "0207",
    "0208",
    "0400",
    "0006"
  ],
  "variables": {
    "Profile": "CI",
    "Environment": "CI"
  }
}
```

### Recipe: Python Data Science Environment

**Purpose**: Set up Python with data science tools  
**Duration**: 20-30 minutes

```json
{
  "name": "python-datascience",
  "sequences": [
    "0001",
    "0002",
    "0207",
    "0206",
    "0204",
    "0210"
  ],
  "variables": {
    "PythonPackages": ["numpy", "pandas", "matplotlib", "jupyter"]
  }
}
```

### Recipe: Cloud DevOps Toolkit

**Purpose**: Install cloud CLI tools and infrastructure tools  
**Duration**: 15-25 minutes

```json
{
  "name": "cloud-devops-toolkit",
  "sequences": [
    "0001",
    "0002",
    "0207",
    "0212",
    "0213",
    "0208",
    "0008",
    "0214"
  ],
  "variables": {
    "CloudProviders": ["Azure", "AWS"]
  }
}
```

### Recipe: Windows Hyper-V Lab

**Purpose**: Set up a complete Hyper-V virtualization lab  
**Duration**: 30-60 minutes

```json
{
  "name": "hyperv-lab-complete",
  "sequences": [
    "0001",
    "0002",
    "0105",
    "0104",
    "0107",
    "0112"
  ],
  "variables": {
    "Profile": "Lab",
    "Features": ["HyperV", "CertificateAuthority", "AdminCenter", "PXE"]
  }
}
```

## Best Practices

### 1. Start Small, Build Up

Begin with minimal blocks and add complexity:

```powershell
# Start minimal
$blocks = @("0001", "0002")

# Add as needed
$blocks += "0207"  # Git
$blocks += "0201"  # Node

# Execute
Invoke-OrchestrationSequence -Sequence ($blocks -join ",")
```

### 2. Use Profiles for Flexibility

Create profiles for different scenarios:

```json
{
  "profiles": {
    "quick": {
      "description": "Minimal installation",
      "variables": { "installOptional": false }
    },
    "complete": {
      "description": "Full installation",
      "variables": { "installOptional": true }
    }
  }
}
```

### 3. Leverage Conditional Execution

Only run blocks when needed:

```json
{
  "stages": [
    {
      "name": "Windows Only",
      "sequences": ["0105"],
      "condition": "$IsWindows"
    }
  ]
}
```

### 4. Use Parallel Execution

Speed up independent tasks:

```json
{
  "stages": [
    {
      "name": "Install Tools",
      "sequences": ["0207", "0201", "0206"],
      "parallel": true
    }
  ]
}
```

### 5. Implement Error Handling

Plan for failures:

```json
{
  "stages": [
    {
      "name": "Critical Setup",
      "sequences": ["0001", "0002"],
      "continueOnError": false
    },
    {
      "name": "Optional Tools",
      "sequences": ["0210"],
      "continueOnError": true
    }
  ]
}
```

### 6. Document Your Playbooks

Always include metadata:

```json
{
  "metadata": {
    "name": "my-playbook",
    "description": "Clear description of purpose",
    "author": "Your Name",
    "tags": ["relevant", "searchable", "tags"],
    "estimatedDuration": "15-20 minutes"
  }
}
```

### 7. Test Before Deployment

Always dry-run first:

```powershell
# Test what will happen
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook my-playbook -DryRun

# Then execute
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook my-playbook
```

## Advanced Topics

### Custom Building Blocks

Create your own building blocks following the standard pattern:

```powershell
#Requires -Version 7.0
# Stage: Custom
# Dependencies: Git, Node
# Description: My custom automation block
# Tags: custom, automation

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [hashtable]$Configuration
)

# Your automation logic here

# Return exit code
exit 0  # Success
```

Save as `automation-scripts/NNNN_MyCustomBlock.ps1` (use next available number).

### Extending the Orchestration Engine

Add custom orchestration logic:

```powershell
# Custom sequence resolver
function Resolve-CustomSequence {
    param([string]$Pattern)
    
    # Your custom logic
    # Return array of script numbers
}

# Use in playbook
Invoke-OrchestrationSequence -Sequence "custom:MyPattern"
```

### Integration with External Systems

Trigger playbooks from external systems:

```powershell
# REST API endpoint
Invoke-RestMethod -Uri "http://localhost:8080/api/playbooks/my-playbook/execute" `
    -Method Post `
    -Body (@{
        variables = @{
            Environment = "Production"
        }
    } | ConvertTo-Json)
```

## Troubleshooting

### View Execution Plan

See what will execute before running:

```powershell
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook my-playbook -DryRun
```

### Enable Verbose Logging

Get detailed execution information:

```powershell
$VerbosePreference = 'Continue'
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook my-playbook -Verbose
```

### Check Playbook Syntax

Validate playbook JSON:

```powershell
$playbook = Get-Content orchestration/playbooks/my-playbook.json | ConvertFrom-Json
# If this succeeds, JSON is valid
```

### View Script Metadata

Check what a block does:

```powershell
Get-Content automation-scripts/0207_Install-Git.ps1 | Select-String "^# Stage:|^# Dependencies:|^# Description:"
```

## Next Steps

1. **Explore Examples**: Check `orchestration/playbooks/core/` for real-world examples
2. **Create Your First Playbook**: Start with a simple JSON playbook
3. **Test and Iterate**: Use dry-run mode to test before executing
4. **Share Your Playbooks**: Contribute useful patterns back to the community
5. **Read the Advanced Guide**: See `docs/ORCHESTRATION-ADVANCED.md` for more details

## Support

- **Documentation**: `docs/` directory
- **Examples**: `orchestration/playbooks/core/` and `orchestration/playbooks/examples/`
- **Schema**: `orchestration/schema/playbook-schema-v3.json`
- **Issues**: GitHub Issues for questions and bug reports

---

**Remember**: Building blocks are designed to be **composable**, **reusable**, and **config-driven**. Mix and match them to create exactly the automation you need!
