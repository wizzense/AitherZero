# Core Playbooks

**Version**: 2.0  
**Last Updated**: 2025-11-02  
**Status**: Active Development

## Overview

This directory contains the consolidated core playbooks for AitherZero's orchestration system. These playbooks represent a streamlined, well-organized collection that replaces the previous 42 playbooks with ~23 focused, purpose-driven orchestrations.

## Directory Structure

```
core/
├── testing/          # Test and validation playbooks
├── git/              # Git workflow automation
├── devtools/         # Development tool installation
├── setup/            # Environment setup
├── infrastructure/   # Infrastructure automation
├── operations/       # CI/CD and deployment
├── analysis/         # Code analysis and reporting
└── ai/               # AI-powered workflows
```

## Core Playbooks by Category

### 🧪 Testing (`testing/`)

Fast, focused testing playbooks for different scenarios:

| Playbook | Duration | Purpose | When to Use |
|----------|----------|---------|-------------|
| **test-quick** | 2-5 min | Fast iteration validation | During active development |
| **test-standard** | 15-20 min | Pre-commit validation | Before creating PRs |
| **test-full** | 30-45 min | Complete validation + coverage | Before major releases |
| **test-ci** | 15-20 min | CI/CD optimized | Automated pipelines |
| **workflow-validation** | 10-15 min | GitHub Actions testing | Workflow development |

**Example Usage:**
```powershell
# Quick validation during development
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick

# Pre-commit validation  
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-standard

# Complete validation
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-full
```

### 🔀 Git Workflows (`git/`)

Automated Git workflows with AI assistance:

| Playbook | Purpose | Stages |
|----------|---------|--------|
| **git-feature** | Complete feature workflow | Branch → Validate → Commit → Push → PR |
| **git-commit** | Simple commit workflow | Stage → Validate → Commit |
| **git-standard** | Flexible Git operations | Configurable workflow |

**Example Usage:**
```powershell
# Complete feature workflow with AI
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook git-feature `
    -Variables @{branchName="add-logging"; commitType="feat"}

# Quick commit
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook git-commit
```

### 🛠️ Development Tools (`devtools/`)

Install development tools quickly:

| Playbook | Tools Included | Duration |
|----------|----------------|----------|
| **devtools-minimal** | Git, Node, Docker, Python | 10-15 min |
| **devtools-full** | All dev tools + VS Code, CLIs | 30-45 min |

**Example Usage:**
```powershell
# Essential tools only
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook devtools-minimal

# Complete toolchain
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook devtools-full
```

### 🏗️ Infrastructure (`infrastructure/`)

System and infrastructure setup:

| Playbook | Purpose | Platform |
|----------|---------|----------|
| **infrastructure-minimal** | Basic system configuration | Cross-platform |
| **infrastructure-wsl** | WSL2 + Docker development | Windows only |
| **hyperv-lab-setup** | Complete Hyper-V lab | Windows only |

**Example Usage:**
```powershell
# Minimal cross-platform setup
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook infrastructure-minimal

# WSL2 development environment
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook infrastructure-wsl

# Full Hyper-V lab
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook hyperv-lab-setup
```

### ⚙️ Setup (`setup/`)

Environment setup for different scenarios:

| Playbook | Purpose | Tools |
|----------|---------|-------|
| **minimal-setup** | Quick start / CI | Core dependencies |
| **dev-environment** | Standard developer workstation | Standard dev stack |
| **full-development** | Power user setup | All tools |
| **ai-development** | AI-enhanced development | + AI assistants |

### 🚀 Operations (`operations/`)

CI/CD and deployment automation:

| Playbook | Purpose |
|----------|---------|
| **ci-pipeline** | Standard CI/CD pipeline |
| **deployment** | Infrastructure deployment |
| **session-management** | Work session management |

### 📊 Analysis (`analysis/`)

Code analysis and reporting:

| Playbook | Purpose |
|----------|---------|
| **automated-security-review** | Security scanning |
| **claude-code-review** | AI code review |
| **tech-debt-analysis** | Technical debt analysis |
| **reporting-automation** | Comprehensive reporting |

### 🤖 AI Workflows (`ai/`)

AI-powered automation:

| Playbook | Purpose |
|----------|---------|
| **ai-agent-personas** | Custom agent personas |
| **ai-orchestration** | Multi-agent orchestration |
| **ai-commands** | Custom CLI commands |

## Playbook Schema v2.0

All core playbooks use the standardized v2.0 schema:

```json
{
  "metadata": {
    "name": "playbook-name",
    "description": "Clear description",
    "version": "2.0.0",
    "category": "testing|git|devtools|infrastructure|...",
    "author": "AitherZero Team",
    "tags": ["tag1", "tag2"],
    "estimatedDuration": "X-Y minutes",
    "lastUpdated": "2025-11-02T00:00:00Z"
  },
  "requirements": {
    "minimumPowerShellVersion": "7.0",
    "requiredModules": [],
    "requiredTools": [],
    "platforms": [],
    "permissions": []
  },
  "orchestration": {
    "defaultVariables": {},
    "profiles": {},
    "stages": []
  },
  "validation": {
    "preConditions": [],
    "postConditions": []
  },
  "notifications": {},
  "reporting": {},
  "postActions": []
}
```

## Profiles

Many playbooks support multiple profiles for different use cases:

```powershell
# Use specific profile
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick -PlaybookProfile lightning

# Available profiles vary by playbook:
# test-quick: lightning, standard, thorough
# test-standard: quick, strict, standard
# git-feature: standard, quick, interactive
# infrastructure-wsl: minimal, development, docker-focused
```

## Variables

Pass custom variables to playbooks:

```powershell
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook git-feature `
    -Variables @{
        branchName = "my-feature"
        branchType = "feature"
        commitType = "feat"
        autoValidate = $true
    }
```

## Migration from Legacy Playbooks

See [CONSOLIDATION-PLAN.md](../CONSOLIDATION-PLAN.md) for complete migration details.

### Quick Migration Guide

| Old Playbook | New Equivalent |
|--------------|----------------|
| test-lightning | test-quick -Profile lightning |
| test-simple | test-quick -Profile lightning |
| test-comprehensive | test-standard |
| comprehensive-validation | test-full |
| claude-feature-workflow | git-feature |
| ai-complete-workflow | git-feature |
| claude-commit-workflow | git-commit |

## Best Practices

### 1. Choose the Right Playbook

- **Development**: test-quick for fast feedback
- **Pre-commit**: test-standard for thorough validation
- **Pre-release**: test-full with coverage
- **CI/CD**: test-ci optimized for automation

### 2. Use Profiles

Profiles customize playbook behavior without modifying the playbook:

```powershell
# Fast iteration
-PlaybookProfile lightning

# Strict validation
-PlaybookProfile strict

# Interactive mode
-PlaybookProfile interactive
```

### 3. Leverage Variables

Override defaults for specific needs:

```powershell
-Variables @{
    continueOnError = $false  # Fail fast
    skipCoverage = $true      # Speed up tests
    nonInteractive = $true    # Automation mode
}
```

### 4. Chain Playbooks

Run multiple playbooks in sequence:

```powershell
# Setup then test
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook devtools-minimal
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick

# Development workflow
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-standard
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook git-feature
```

## Troubleshooting

### Playbook Not Found

Ensure you're using the playbook name (not filename):

```powershell
# Correct
-Playbook test-quick

# Incorrect
-Playbook test-quick.json
```

### Missing Requirements

Check playbook requirements in metadata:

```powershell
# View playbook details
Get-Content ./orchestration/playbooks/core/testing/test-quick.json | ConvertFrom-Json | Select-Object -ExpandProperty metadata
```

### Stage Failures

Enable detailed logging:

```powershell
$env:AITHERZERO_MINIMAL_LOGGING = "false"
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick -Verbose
```

### Profile Issues

List available profiles:

```powershell
$playbook = Get-Content ./orchestration/playbooks/core/testing/test-quick.json | ConvertFrom-Json
$playbook.orchestration.profiles | Get-Member -MemberType NoteProperty
```

## Contributing

When creating new playbooks:

1. Use v2.0 schema (see template above)
2. Add to appropriate category directory
3. Include comprehensive metadata
4. Define clear profiles for different use cases
5. Add validation conditions
6. Document in this README

## Support

- 📖 **Documentation**: [AitherZero Docs](../../../docs/)
- 🐛 **Issues**: [GitHub Issues](https://github.com/wizzense/AitherZero/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/wizzense/AitherZero/discussions)

## Version History

- **2.0.0** (2025-11-02): Initial core playbooks release
  - Consolidated 42 playbooks → 23 core playbooks
  - Standardized on v2.0 schema
  - Added profile support
  - Improved documentation
